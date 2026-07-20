import Foundation
import Darwin

protocol ShellProcessRunning: Sendable {
    func run(executablePath: String, arguments: [String], environment: [String: String], timeout: TimeInterval) -> ShellProcessResult
}

struct ShellProcessResult: Sendable, Equatable {
    enum Termination: Sendable, Equatable {
        case exited(Int32)
        case timedOut
        case launchFailed
    }

    let termination: Termination
    let standardOutput: Data
}

struct FoundationShellProcessRunner: ShellProcessRunning {
    func run(executablePath: String, arguments: [String], environment: [String: String], timeout: TimeInterval) -> ShellProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let output = Pipe()
        process.standardOutput = output

        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in termination.signal() }

        let lock = NSLock()
        var outputData = Data()
        let reader = DispatchGroup()
        reader.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            outputData = data
            lock.unlock()
            reader.leave()
        }

        do {
            try process.run()
        } catch {
            try? output.fileHandleForWriting.close()
            reader.wait()
            return ShellProcessResult(termination: .launchFailed, standardOutput: Data())
        }

        if termination.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if termination.wait(timeout: .now() + 0.25) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = termination.wait(timeout: .now() + 0.25)
            }
            reader.wait()
            return ShellProcessResult(termination: .timedOut, standardOutput: Data())
        }

        reader.wait()
        lock.lock()
        let data = outputData
        lock.unlock()
        return ShellProcessResult(termination: .exited(process.terminationStatus), standardOutput: data)
    }
}

struct ShellEnvironmentResolution: Sendable, Equatable {
    enum Source: Sendable, Equatable {
        case loginShell
        case inheritedEnvironment

        var label: String {
            switch self {
            case .loginShell: return "Login shell"
            case .inheritedEnvironment: return "Inherited environment"
            }
        }
    }

    enum Issue: Sendable, Equatable {
        case noUsableShell
        case launchFailed
        case timedOut
        case nonZeroExit(Int32)
        case invalidOutput

        var displayMessage: String {
            switch self {
            case .noUsableShell:
                return "No usable login shell was found. Using the inherited environment."
            case .launchFailed:
                return "The login shell could not be started. Using the inherited environment."
            case .timedOut:
                return "Shell environment detection exceeded 3 seconds. Using the inherited environment."
            case .nonZeroExit(let status):
                return "The login shell exited with status \(status). Using the inherited environment."
            case .invalidOutput:
                return "The login shell returned an unreadable environment. Using the inherited environment."
            }
        }
    }

    let environment: [String: String]
    let shellPath: String?
    let source: Source
    let pathEntries: [String]
    let issue: Issue?
}

enum ShellEnvironmentCore {
    static let timeout: TimeInterval = 3

    private static let deniedNames: Set<String> = [
        "_", "SHLVL", "PWD", "OLDPWD", "TERM", "TERM_PROGRAM", "TERM_PROGRAM_VERSION",
        "TERM_SESSION_ID", "ITERM_SESSION_ID", "LC_TERMINAL", "LC_TERMINAL_VERSION",
        "COMMAND_MODE", "SECURITYSESSIONID", "XPC_FLAGS", "XPC_SERVICE_NAME"
    ]

    static func selectShell(base: [String: String], accountShell: String?, isExecutable: (String) -> Bool) -> String? {
        let candidates = [base["SHELL"], accountShell, "/bin/zsh", "/bin/sh"]
        return candidates.compactMap { $0 }.first { $0.hasPrefix("/") && isExecutable($0) }
    }

    static func arguments(for shellPath: String) -> [String] {
        switch URL(fileURLWithPath: shellPath).lastPathComponent.lowercased() {
        case "zsh", "bash", "ksh", "ksh93", "mksh", "fish":
            return ["-l", "-i", "-c", "/usr/bin/env -0"]
        default:
            return ["-l", "-c", "/usr/bin/env -0"]
        }
    }

    static func resolve(
        base: [String: String],
        accountShell: String?,
        runner: any ShellProcessRunning,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> ShellEnvironmentResolution {
        guard let shell = selectShell(base: base, accountShell: accountShell, isExecutable: isExecutable) else {
            return fallback(base: base, shellPath: nil, issue: .noUsableShell)
        }

        let result = runner.run(executablePath: shell, arguments: arguments(for: shell), environment: base, timeout: timeout)
        switch result.termination {
        case .timedOut:
            return fallback(base: base, shellPath: shell, issue: .timedOut)
        case .launchFailed:
            return fallback(base: base, shellPath: shell, issue: .launchFailed)
        case .exited(let status) where status != 0:
            return fallback(base: base, shellPath: shell, issue: .nonZeroExit(status))
        case .exited:
            let captured = parse(result.standardOutput)
            guard !captured.isEmpty else {
                return fallback(base: base, shellPath: shell, issue: .invalidOutput)
            }
            return merged(base: base, captured: captured, shellPath: shell)
        }
    }

    private static func parse(_ data: Data) -> [String: String] {
        var environment: [String: String] = [:]
        for entry in data.split(separator: 0) {
            guard let separator = entry.firstIndex(of: 61) else { continue }
            var key = String(decoding: entry[..<separator], as: UTF8.self)
            if let newline = key.lastIndex(of: "\n") {
                key = String(key[key.index(after: newline)...])
            }
            guard isValidKey(key), !isDenied(key) else { continue }
            environment[key] = String(decoding: entry[entry.index(after: separator)...], as: UTF8.self)
        }
        return environment
    }

    private static func isValidKey(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first,
              CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first) else { return false }
        return key.unicodeScalars.dropFirst().allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0)
        }
    }

    private static func isDenied(_ key: String) -> Bool {
        deniedNames.contains(key) || key.hasPrefix("DYLD_") || key.hasPrefix("LD_") || key.hasPrefix("BASH_FUNC_")
    }

    private static func merged(base: [String: String], captured: [String: String], shellPath: String) -> ShellEnvironmentResolution {
        var environment = base.filter { !isDenied($0.key) }
        for (key, value) in captured where !isDenied(key) {
            environment[key] = value
        }
        let pathEntries = normalizedPath(captured: captured["PATH"], base: base["PATH"], home: environment["HOME"])
        environment["PATH"] = pathEntries.joined(separator: ":")
        return ShellEnvironmentResolution(environment: environment, shellPath: shellPath, source: .loginShell, pathEntries: pathEntries, issue: nil)
    }

    private static func fallback(base: [String: String], shellPath: String?, issue: ShellEnvironmentResolution.Issue) -> ShellEnvironmentResolution {
        var environment = base.filter { !isDenied($0.key) }
        let pathEntries = normalizedPath(captured: nil, base: base["PATH"], home: base["HOME"])
        environment["PATH"] = pathEntries.joined(separator: ":")
        return ShellEnvironmentResolution(environment: environment, shellPath: shellPath, source: .inheritedEnvironment, pathEntries: pathEntries, issue: issue)
    }

    private static func normalizedPath(captured: String?, base: String?, home: String?) -> [String] {
        var candidates: [String] = []
        candidates += captured?.split(separator: ":").map(String.init) ?? []
        candidates += base?.split(separator: ":").map(String.init) ?? []
        if let home, !home.isEmpty {
            candidates += ["\(home)/.local/bin", "\(home)/bin"]
        }
        candidates += [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin",
            "/Library/TeX/texbin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ]

        var seen = Set<String>()
        return candidates.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

@MainActor
final class ShellEnvironmentResolver: ObservableObject {
    static let shared = ShellEnvironmentResolver()

    @Published private(set) var resolution: ShellEnvironmentResolution?
    @Published private(set) var isResolving = false

    private let runner: any ShellProcessRunning
    private let baseEnvironment: @Sendable () -> [String: String]
    private var inFlight: Task<ShellEnvironmentResolution, Never>?

    init(
        runner: any ShellProcessRunning = FoundationShellProcessRunner(),
        baseEnvironment: @escaping @Sendable () -> [String: String] = { ProcessInfo.processInfo.environment }
    ) {
        self.runner = runner
        self.baseEnvironment = baseEnvironment
    }

    func environment() async -> [String: String] {
        await resolve().environment
    }

    func resolve(forceRefresh: Bool = false) async -> ShellEnvironmentResolution {
        if !forceRefresh, let resolution { return resolution }
        if let inFlight { return await inFlight.value }

        isResolving = true
        let base = baseEnvironment()
        let runner = self.runner
        let task = Task.detached(priority: .utility) {
            ShellEnvironmentCore.resolve(base: base, accountShell: Self.accountShell(), runner: runner)
        }
        inFlight = task
        let result = await task.value
        resolution = result
        inFlight = nil
        isResolving = false
        return result
    }

    func warmUp() {
        Task { _ = await resolve() }
    }

    func refresh() {
        Task { _ = await resolve(forceRefresh: true) }
    }

    nonisolated private static func accountShell() -> String? {
        guard let record = getpwuid(getuid()), let shell = record.pointee.pw_shell else { return nil }
        return String(cString: shell)
    }
}
