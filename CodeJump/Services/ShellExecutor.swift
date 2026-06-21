import Foundation

enum ShellExecutor {
    @discardableResult
    static func openRemoteProject(_ project: RemoteProject) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: project.editor.cliPath)
        let expandedPath = NSString(string: project.remotePath).expandingTildeInPath
        if project.isLocal {
            process.arguments = [expandedPath]
        } else {
            process.arguments = ["--remote", "ssh-remote+\(project.host)", project.remotePath]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    static func commandString(for project: RemoteProject) -> String {
        let expandedPath = NSString(string: project.remotePath).expandingTildeInPath
        if project.isLocal {
            return "\(project.editor.cliPath) \(expandedPath)"
        } else {
            return "\(project.editor.cliPath) --remote ssh-remote+\(project.host) \(project.remotePath)"
        }
    }
}
