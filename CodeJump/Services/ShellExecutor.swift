import Foundation

enum ShellExecutor {
    struct OpenResult: Sendable {
        let success: Bool
        let errorMessage: String?
    }

    static func arguments(for project: RemoteProject) -> [String] {
        let expandedPath = NSString(string: project.remotePath).expandingTildeInPath
        if project.isLocal {
            return [expandedPath]
        }
        let folderURI = "vscode-remote://ssh-remote+\(project.host)\(project.remotePath)"
        return ["--folder-uri", folderURI]
    }

    @MainActor
    static func openRemoteProject(_ project: RemoteProject) async -> OpenResult {
        let cliPath = project.editor.cliPath
        guard FileManager.default.isExecutableFile(atPath: cliPath) else {
            return OpenResult(success: false, errorMessage: "Editor not found or not executable at \(cliPath)")
        }

        let processArguments = arguments(for: project)
        let environment = await ShellEnvironmentResolver.shared.environment()

        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = processArguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.environment = environment

            do {
                try process.run()
                return OpenResult(success: true, errorMessage: nil)
            } catch {
                return OpenResult(success: false, errorMessage: error.localizedDescription)
            }
        }.value
    }

    private static func shellQuote(_ s: String) -> String {
        if s.rangeOfCharacter(from: .init(charactersIn: " \t'\"\\$`!#&|;(){}[]<>?*~")) != nil {
            let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        return s
    }

    static func commandString(for project: RemoteProject) -> String {
        let cli = shellQuote(project.editor.cliPath)
        if project.isLocal {
            let expandedPath = NSString(string: project.remotePath).expandingTildeInPath
            return "\(cli) \(shellQuote(expandedPath))"
        } else {
            let folderURI = "vscode-remote://ssh-remote+\(project.host)\(project.remotePath)"
            return "\(cli) --folder-uri \(shellQuote(folderURI))"
        }
    }
}
