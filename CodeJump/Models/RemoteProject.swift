import Foundation
import SwiftUI

struct RemoteProject: Codable, Identifiable, Equatable {
    static let localHostTag = "__local__"

    var id: UUID
    var name: String
    var host: String
    var remotePath: String
    var editorId: UUID
    var group: String
    var isFavorite: Bool
    var isHidden: Bool
    var isLocal: Bool

    var editor: Editor {
        EditorStore.shared.editor(for: editorId) ?? Editor.builtinCursor
    }

    init(id: UUID = UUID(), name: String = "", host: String, remotePath: String, editorId: UUID, group: String = "Default", isFavorite: Bool = false, isHidden: Bool = false, isLocal: Bool = false) {
        self.id = id
        self.name = name.isEmpty ? Self.defaultName(host: host, path: remotePath) : name
        self.host = host
        self.remotePath = remotePath
        self.editorId = editorId
        self.group = group
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.isLocal = isLocal
    }

    static func defaultName(host: String, path: String) -> String {
        let lastComponent = (path as NSString).lastPathComponent
        return lastComponent.isEmpty ? host : lastComponent
    }

    enum CodingKeys: String, CodingKey {
        case id, name, host, remotePath, editorId, group, isFavorite, isHidden, isLocal
        case editor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        host = try c.decode(String.self, forKey: .host)
        remotePath = try c.decode(String.self, forKey: .remotePath)

        if let eid = try c.decodeIfPresent(UUID.self, forKey: .editorId) {
            editorId = eid
        } else if let legacyRaw = try c.decodeIfPresent(String.self, forKey: .editor) {
            switch legacyRaw {
            case "cursor": editorId = Editor.builtinCursor.id
            case "vscode": editorId = Editor.builtinVSCode.id
            default: editorId = Editor.builtinCursor.id
            }
        } else {
            editorId = Editor.builtinCursor.id
        }

        group = try c.decodeIfPresent(String.self, forKey: .group) ?? "Default"
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        isLocal = try c.decodeIfPresent(Bool.self, forKey: .isLocal) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(host, forKey: .host)
        try c.encode(remotePath, forKey: .remotePath)
        try c.encode(editorId, forKey: .editorId)
        try c.encode(group, forKey: .group)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(isHidden, forKey: .isHidden)
        try c.encode(isLocal, forKey: .isLocal)
    }
}

struct GroupedProjects: Identifiable {
    let id: String
    let name: String
    let projects: [RemoteProject]
    var isFavoriteGroup: Bool { name == "Favorites" }
}

final class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published var projects: [RemoteProject] {
        didSet { save() }
    }

    @Published var groups: [String] {
        didSet { saveGroups() }
    }

    @Published var collapsedGroups: Set<String> {
        didSet {
            if let data = try? JSONEncoder().encode(collapsedGroups) {
                UserDefaults.standard.set(data, forKey: "collapsedGroups")
            }
        }
    }

    @Published var showHidden: Bool = false

    private let key = "saved_projects_v1"
    private let groupsKey = "project_groups_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RemoteProject].self, from: data) {
            projects = decoded
        } else {
            projects = []
        }

        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            groups = decoded
        } else {
            groups = ["Default"]
        }

        if let data = UserDefaults.standard.data(forKey: "collapsedGroups"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            collapsedGroups = decoded
        } else {
            collapsedGroups = []
        }

        let projectGroups = Set(projects.map(\.group))
        for g in projectGroups where !groups.contains(g) {
            groups.append(g)
        }
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ project: RemoteProject) {
        projects.append(project)
    }

    func remove(_ project: RemoteProject) {
        projects.removeAll { $0.id == project.id }
    }

    func update(_ project: RemoteProject) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
    }

    func toggleFavorite(_ project: RemoteProject) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].isFavorite.toggle()
        }
    }

    func toggleHidden(_ project: RemoteProject) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].isHidden.toggle()
        }
    }

    func toggleGroup(_ group: String) {
        if collapsedGroups.contains(group) {
            collapsedGroups.remove(group)
        } else {
            collapsedGroups.insert(group)
        }
    }

    func setGroup(_ project: RemoteProject, group: String) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].group = group
        }
        if !groups.contains(group) {
            groups.append(group)
        }
    }

    func addGroup(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != "Favorites" && !groups.contains(trimmed) {
            groups.append(trimmed)
        }
    }

    func removeGroup(_ name: String) {
        guard name != "Default" else { return }
        var updated = projects
        for i in updated.indices where updated[i].group == name {
            updated[i].group = "Default"
        }
        projects = updated
        groups.removeAll { $0 == name }
        collapsedGroups.remove(name)
    }

    func renameGroup(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, oldName != trimmed, trimmed != "Favorites" else { return }
        guard !groups.contains(trimmed) else { return }
        var updated = projects
        for i in updated.indices where updated[i].group == oldName {
            updated[i].group = trimmed
        }
        projects = updated
        if let idx = groups.firstIndex(of: oldName) {
            groups[idx] = trimmed
        }
        if collapsedGroups.remove(oldName) != nil {
            collapsedGroups.insert(trimmed)
        }
    }

    var allGroups: [String] {
        var result = groups
        let projectGroups = Set(projects.map(\.group))
        for g in projectGroups where !result.contains(g) {
            result.append(g)
        }
        return result
    }

    var hiddenCount: Int {
        projects.filter(\.isHidden).count
    }

    func groupedProjects(searchText: String) -> [GroupedProjects] {
        var filtered = projects

        if !showHidden {
            filtered = filtered.filter { !$0.isHidden }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(query) ||
                $0.host.lowercased().contains(query) ||
                $0.remotePath.lowercased().contains(query)
            }
        }

        let favorites = filtered.filter(\.isFavorite)
        let nonFavorites = filtered.filter { !$0.isFavorite }

        var result: [GroupedProjects] = []

        if !favorites.isEmpty {
            result.append(GroupedProjects(id: "Favorites", name: "Favorites", projects: favorites))
        }

        let grouped = Dictionary(grouping: nonFavorites, by: \.group)
        for groupName in allGroups {
            if let items = grouped[groupName], !items.isEmpty {
                result.append(GroupedProjects(id: groupName, name: groupName, projects: items))
            }
        }

        return result
    }
}
