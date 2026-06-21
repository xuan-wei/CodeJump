import Foundation

enum SSHConfigParser {
    static func parse(configPath: String, visited: inout Set<String>) -> [SSHHost] {
        let expandedPath = NSString(string: configPath).expandingTildeInPath
        let resolvedPath = (try? FileManager.default.attributesOfItem(atPath: expandedPath)) != nil
            ? expandedPath : expandedPath

        guard visited.insert(resolvedPath).inserted else { return [] }
        guard let content = try? String(contentsOfFile: resolvedPath, encoding: .utf8) else {
            return []
        }
        let baseDir = (resolvedPath as NSString).deletingLastPathComponent
        return parseContent(content, baseDir: baseDir, visited: &visited)
    }

    static func parse(configPath: String) -> [SSHHost] {
        var visited = Set<String>()
        return parse(configPath: configPath, visited: &visited)
    }

    private static func stripInlineComment(_ value: String) -> String {
        var inQuote = false
        for (i, ch) in value.enumerated() {
            if ch == "\"" { inQuote.toggle() }
            if ch == "#" && !inQuote {
                return String(value.prefix(i)).trimmingCharacters(in: .whitespaces)
            }
        }
        return value
    }

    private static func splitKeyValue(_ line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if let eqIdx = trimmed.firstIndex(of: "=") {
            let key = String(trimmed[trimmed.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let val = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty && !val.isEmpty { return (key, val) }
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private static func resolveGlob(_ pattern: String) -> [String] {
        let expanded = NSString(string: pattern).expandingTildeInPath
        let cPattern = strdup(expanded)
        defer { free(cPattern) }

        var gt = glob_t()
        let flags = Int32(GLOB_TILDE | GLOB_BRACE)
        guard glob(cPattern, flags, nil, &gt) == 0 else {
            globfree(&gt)
            return [expanded]
        }

        var results: [String] = []
        for i in 0..<Int(gt.gl_matchc) {
            if let path = gt.gl_pathv[i] {
                results.append(String(cString: path))
            }
        }
        globfree(&gt)
        return results.isEmpty ? [expanded] : results.sorted()
    }

    private static func parseContent(_ content: String, baseDir: String, visited: inout Set<String>) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentHosts: [String] = []
        var currentHostName: String?
        var currentUser: String?
        var currentPort: Int?

        func flushHosts() {
            for host in currentHosts {
                if !host.contains("*") && !host.contains("?") {
                    hosts.append(SSHHost(name: host, hostName: currentHostName, user: currentUser, port: currentPort))
                }
            }
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            guard let (rawKey, rawValue) = splitKeyValue(trimmed) else { continue }
            let keyword = rawKey.lowercased()
            let value = stripInlineComment(rawValue)
            guard !value.isEmpty else { continue }

            switch keyword {
            case "host":
                flushHosts()
                currentHosts = value.split(separator: " ").map { String($0).trimmingCharacters(in: .whitespaces) }
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
                let pattern: String
                if value.hasPrefix("/") || value.hasPrefix("~") {
                    pattern = value
                } else {
                    pattern = baseDir + "/" + value
                }
                for resolvedPath in resolveGlob(pattern) {
                    let includedHosts = parse(configPath: resolvedPath, visited: &visited)
                    hosts.append(contentsOf: includedHosts)
                }
            default:
                break
            }
        }
        flushHosts()
        return hosts
    }
}
