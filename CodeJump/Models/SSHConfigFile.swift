import Foundation

struct SSHConfigFile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

struct HostGroup: Identifiable {
    let id: String
    let name: String
    let hosts: [SSHHost]
}

final class SSHConfigStore: ObservableObject {
    static let shared = SSHConfigStore()

    @Published var configs: [SSHConfigFile] {
        didSet { save() }
    }

    private let key = "ssh_config_files_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SSHConfigFile].self, from: data),
           !decoded.isEmpty {
            configs = decoded
        } else {
            let legacy = UserDefaults.standard.string(forKey: "sshConfigPath") ?? "~/.ssh/ssh_config_for_vscode"
            configs = [SSHConfigFile(name: "VSCode/Cursor", path: legacy)]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ config: SSHConfigFile) {
        configs.append(config)
    }

    func remove(_ config: SSHConfigFile) {
        configs.removeAll { $0.id == config.id }
    }

    func update(_ config: SSHConfigFile) {
        if let idx = configs.firstIndex(where: { $0.id == config.id }) {
            configs[idx] = config
        }
    }

    func parseAll() -> [(SSHConfigFile, [SSHHost])] {
        configs.map { config in
            (config, SSHConfigParser.parse(configPath: config.path))
        }
    }
}
