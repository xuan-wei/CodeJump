import Foundation

enum SSHConfigParser {
    static func parse(configPath: String) -> [SSHHost] {
        let expandedPath = NSString(string: configPath).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            return []
        }
        let baseDir = (expandedPath as NSString).deletingLastPathComponent
        return parseContent(content, baseDir: baseDir)
    }

    private static func parseContent(_ content: String, baseDir: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentHost: String?
        var currentHostName: String?
        var currentUser: String?
        var currentPort: Int?

        func flushHost() {
            guard let host = currentHost, !host.contains("*") else { return }
            hosts.append(SSHHost(name: host, hostName: currentHostName, user: currentUser, port: currentPort))
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { continue }

            let keyword = parts[0].lowercased()
            let value = parts[1]

            switch keyword {
            case "host":
                flushHost()
                currentHost = value
                currentHostName = nil
                currentUser = nil
                currentPort = nil
            case "hostname":
                currentHostName = value
            case "user":
                currentUser = value
            case "port":
                currentPort = Int(value)
            case "include":
                let resolved: String
                if value.hasPrefix("/") || value.hasPrefix("~") {
                    resolved = NSString(string: value).expandingTildeInPath
                } else {
                    resolved = baseDir + "/" + value
                }
                let includedHosts = parse(configPath: resolved)
                hosts.append(contentsOf: includedHosts)
            default:
                break
            }
        }
        flushHost()
        return hosts
    }
}
