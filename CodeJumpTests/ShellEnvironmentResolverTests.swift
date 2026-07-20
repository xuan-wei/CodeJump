import XCTest
@testable import CodeJump

final class ShellEnvironmentResolverTests: XCTestCase {
    func testShellArgumentsMatchShellFamily() {
        XCTAssertEqual(ShellEnvironmentCore.arguments(for: "/bin/zsh"), ["-l", "-i", "-c", "/usr/bin/env -0"])
        XCTAssertEqual(ShellEnvironmentCore.arguments(for: "/bin/bash"), ["-l", "-i", "-c", "/usr/bin/env -0"])
        XCTAssertEqual(ShellEnvironmentCore.arguments(for: "/bin/ksh"), ["-l", "-i", "-c", "/usr/bin/env -0"])
        XCTAssertEqual(ShellEnvironmentCore.arguments(for: "/opt/homebrew/bin/fish"), ["-l", "-i", "-c", "/usr/bin/env -0"])
        XCTAssertEqual(ShellEnvironmentCore.arguments(for: "/bin/sh"), ["-l", "-c", "/usr/bin/env -0"])
        XCTAssertEqual(ShellEnvironmentCore.arguments(for: "/custom/bin/nu"), ["-l", "-c", "/usr/bin/env -0"])
    }

    func testSuccessfulResolutionParsesFiltersAndAugmentsEnvironment() {
        let output = Data("PATH=/custom/bin:/usr/bin\0SSH_AUTH_SOCK=/tmp/agent.sock\0VALUE=a=b=c\0PWD=/tmp\0SHLVL=2\0DYLD_INSERT_LIBRARIES=bad\0AWS_ACCESS_KEY_ID=keep\0GITHUB_TOKEN=keep-too\0".utf8)
        let runner = StubShellProcessRunner(result: .init(termination: .exited(0), standardOutput: output))
        let base = ["HOME": "/Users/tester", "PATH": "/usr/bin:/bin", "SHELL": "/bin/zsh"]

        let result = ShellEnvironmentCore.resolve(base: base, accountShell: nil, runner: runner, isExecutable: { _ in true })

        XCTAssertEqual(result.source, .loginShell)
        XCTAssertNil(result.issue)
        XCTAssertEqual(result.environment["SSH_AUTH_SOCK"], "/tmp/agent.sock")
        XCTAssertEqual(result.environment["VALUE"], "a=b=c")
        XCTAssertEqual(result.environment["AWS_ACCESS_KEY_ID"], "keep")
        XCTAssertEqual(result.environment["GITHUB_TOKEN"], "keep-too")
        XCTAssertNil(result.environment["PWD"])
        XCTAssertNil(result.environment["SHLVL"])
        XCTAssertNil(result.environment["DYLD_INSERT_LIBRARIES"])
        XCTAssertEqual(result.pathEntries, [
            "/custom/bin", "/usr/bin", "/bin", "/Users/tester/.local/bin", "/Users/tester/bin",
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin",
            "/Library/TeX/texbin", "/usr/sbin", "/sbin"
        ])
    }

    func testTimeoutUsesInheritedEnvironmentWithFallbackPath() {
        let runner = StubShellProcessRunner(result: .init(termination: .timedOut, standardOutput: Data()))
        let result = ShellEnvironmentCore.resolve(
            base: ["HOME": "/Users/tester", "PATH": "/usr/bin", "SHELL": "/bin/fish", "KEEP": "yes"],
            accountShell: nil,
            runner: runner,
            isExecutable: { _ in true }
        )

        XCTAssertEqual(result.source, .inheritedEnvironment)
        XCTAssertEqual(result.issue, .timedOut)
        XCTAssertEqual(result.environment["KEEP"], "yes")
        XCTAssertTrue(result.pathEntries.contains("/Library/TeX/texbin"))
        XCTAssertTrue(result.pathEntries.contains("/opt/homebrew/bin"))
    }

    func testShellSelectionUsesAccountAndSystemFallbacks() {
        let executable: (String) -> Bool = { ["/bin/bash", "/bin/zsh", "/bin/sh"].contains($0) }
        XCTAssertEqual(ShellEnvironmentCore.selectShell(base: ["SHELL": "/bad/shell"], accountShell: "/bin/bash", isExecutable: executable), "/bin/bash")
        XCTAssertEqual(ShellEnvironmentCore.selectShell(base: [:], accountShell: nil, isExecutable: executable), "/bin/zsh")
        XCTAssertNil(ShellEnvironmentCore.selectShell(base: [:], accountShell: nil, isExecutable: { _ in false }))
    }

    func testFoundationRunnerTimesOutPromptly() {
        let start = Date()
        let result = FoundationShellProcessRunner().run(
            executablePath: "/bin/sh",
            arguments: ["-c", "/bin/sleep 1"],
            environment: ProcessInfo.processInfo.environment,
            timeout: 0.05
        )

        XCTAssertEqual(result.termination, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.8)
    }
}

private final class StubShellProcessRunner: ShellProcessRunning, @unchecked Sendable {
    let result: ShellProcessResult
    init(result: ShellProcessResult) { self.result = result }

    func run(executablePath: String, arguments: [String], environment: [String: String], timeout: TimeInterval) -> ShellProcessResult {
        result
    }
}
