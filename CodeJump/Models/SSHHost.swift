import Foundation

enum HostSource: String, Codable {
    case sshConfig
    case custom
}

struct SSHHost: Identifiable, Hashable {
    let id: String
    let name: String
    let hostName: String?
    let user: String?
    let port: Int?
    let source: HostSource

    init(name: String, hostName: String? = nil, user: String? = nil, port: Int? = nil, source: HostSource = .sshConfig) {
        self.id = name
        self.name = name
        self.hostName = hostName
        self.user = user
        self.port = port
        self.source = source
    }

    var isCustom: Bool { source == .custom }
}

struct CustomHost: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var hostName: String
    var port: Int?
    var user: String
    var identityFile: String

    init(id: UUID = UUID(), name: String, hostName: String = "", port: Int? = nil, user: String = "", identityFile: String = "") {
        self.id = id
        self.name = name
        self.hostName = hostName
        self.port = port
        self.user = user
        self.identityFile = identityFile
    }

    func toSSHHost() -> SSHHost {
        SSHHost(name: name, hostName: hostName.isEmpty ? nil : hostName, user: user.isEmpty ? nil : user, port: port, source: .custom)
    }

    func toConfigBlock() -> String {
        var lines = ["Host \(name)"]
        if !hostName.isEmpty { lines.append("  HostName \(hostName)") }
        if let port { lines.append("  Port \(port)") }
        if !user.isEmpty { lines.append("  User \(user)") }
        if !identityFile.isEmpty { lines.append("  IdentityFile \(identityFile)") }
        return lines.joined(separator: "\n")
    }
}

final class HostStore: ObservableObject {
    static let shared = HostStore()

    static let managedConfigPath = "~/.codejump/ssh_config"
    static var managedConfigExpandedPath: String {
        NSString(string: managedConfigPath).expandingTildeInPath
    }
    static var includeDirective: String {
        "Include \(managedConfigPath)"
    }

    @Published var customHosts: [CustomHost] {
        didSet {
            save()
            scheduleWriteConfig()
        }
    }

    private let key = "custom_hosts_v1"
    private var writeConfigTimer: Timer?

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CustomHost].self, from: data) {
            customHosts = decoded
        } else {
            customHosts = []
        }
        writeManagedConfig()
    }

    private func scheduleWriteConfig() {
        writeConfigTimer?.invalidate()
        writeConfigTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.writeManagedConfig()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customHosts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func writeManagedConfig() {
        let path = Self.managedConfigExpandedPath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let header = "# Managed by CodeJump — do not edit manually.\n# Add `Include \(Self.managedConfigPath)` to your SSH config to use these hosts.\n\n"
        let body = customHosts.map { $0.toConfigBlock() }.joined(separator: "\n\n")
        let content = header + body + (body.isEmpty ? "" : "\n")
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func add(_ host: CustomHost) {
        customHosts.append(host)
    }

    func remove(_ host: CustomHost) {
        customHosts.removeAll { $0.id == host.id }
    }

    func update(_ host: CustomHost) {
        if let idx = customHosts.firstIndex(where: { $0.id == host.id }) {
            customHosts[idx] = host
        }
    }

    func allHosts(sshConfigPath: String) -> [SSHHost] {
        let configHosts = SSHConfigParser.parse(configPath: sshConfigPath)
        let configNames = Set(configHosts.map(\.name))
        let custom = customHosts.map { $0.toSSHHost() }
        let uniqueCustom = custom.filter { !configNames.contains($0.name) }
        return configHosts + uniqueCustom
    }

    func groupedHosts(configStore: SSHConfigStore) -> [HostGroup] {
        var groups: [HostGroup] = []
        var seen = Set<String>()

        let custom = customHosts.map { $0.toSSHHost() }.filter { seen.insert($0.name).inserted }
        if !custom.isEmpty {
            groups.append(HostGroup(id: "__custom__", name: "CodeJump Custom", hosts: custom))
        }

        for (config, hosts) in configStore.parseAll() {
            let unique = hosts.filter { seen.insert($0.name).inserted }
            if !unique.isEmpty {
                groups.append(HostGroup(id: config.id.uuidString, name: config.name, hosts: unique))
            }
        }
        return groups
    }

    func isIncluded(in sshConfigPath: String) -> Bool {
        let expanded = NSString(string: sshConfigPath).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expanded, encoding: .utf8) else { return false }
        let needle = Self.managedConfigPath
        return content.contains(needle) || content.contains(Self.managedConfigExpandedPath)
    }

    func isIncludedAnywhere(configStore: SSHConfigStore) -> Bool {
        configStore.configs.contains { isIncluded(in: $0.path) }
    }

    @discardableResult
    func addIncludeDirective(to sshConfigPath: String) -> Bool {
        let expanded = NSString(string: sshConfigPath).expandingTildeInPath
        let directive = Self.includeDirective + "\n"
        let existing = (try? String(contentsOfFile: expanded, encoding: .utf8)) ?? ""
        if existing.contains(Self.managedConfigPath) { return true }

        let fm = FileManager.default
        let originalPerms = try? fm.attributesOfItem(atPath: expanded)[.posixPermissions] as? Int

        let newContent = directive + "\n" + existing
        do {
            try newContent.write(toFile: expanded, atomically: true, encoding: .utf8)
            if let perms = originalPerms {
                try? fm.setAttributes([.posixPermissions: perms], ofItemAtPath: expanded)
            }
            return true
        } catch {
            return false
        }
    }
}
