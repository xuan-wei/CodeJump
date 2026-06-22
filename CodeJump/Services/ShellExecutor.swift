import Foundation
import AppKit

enum ShellExecutor {
    struct OpenResult {
        let success: Bool
        let errorMessage: String?
    }

    static func openRemoteProject(_ project: RemoteProject) -> OpenResult {
        let cliPath = project.editor.cliPath
        guard FileManager.default.fileExists(atPath: cliPath) else {
            return OpenResult(success: false, errorMessage: "Editor not found at \(cliPath)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        let expandedPath = NSString(string: project.remotePath).expandingTildeInPath
        if project.isLocal {
            process.arguments = [expandedPath]
        } else {
            let folderURI = "vscode-remote://ssh-remote+\(project.host)\(project.remotePath)"
            process.arguments = ["--folder-uri", folderURI]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            return OpenResult(success: true, errorMessage: nil)
        } catch {
            return OpenResult(success: false, errorMessage: error.localizedDescription)
        }
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
