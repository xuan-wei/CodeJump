import Foundation

struct Editor: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var cliPath: String
    var iconName: String

    init(id: UUID = UUID(), name: String, cliPath: String, iconName: String = "terminal") {
        self.id = id
        self.name = name
        self.cliPath = cliPath
        self.iconName = iconName
    }

    static let builtinCursor = Editor(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Cursor", cliPath: "/usr/local/bin/cursor", iconName: "cursorarrow.rays")
    static let builtinVSCode = Editor(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "VSCode", cliPath: "/usr/local/bin/code", iconName: "chevron.left.forwardslash.chevron.right")
    static let builtins: [Editor] = [builtinCursor, builtinVSCode]
}

final class EditorStore: ObservableObject {
    static let shared = EditorStore()

    @Published var editors: [Editor] {
        didSet { save() }
    }

    private let key = "custom_editors_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Editor].self, from: data) {
            editors = Editor.builtins + decoded
        } else {
            editors = Editor.builtins
        }
    }

    private var customEditors: [Editor] {
        editors.filter { !Editor.builtins.contains($0) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customEditors) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ editor: Editor) {
        editors.append(editor)
    }

    func remove(_ editor: Editor) {
        guard !Editor.builtins.contains(editor) else { return }
        editors.removeAll { $0.id == editor.id }
    }

    func update(_ editor: Editor) {
        if let idx = editors.firstIndex(where: { $0.id == editor.id }) {
            editors[idx] = editor
        }
    }

    func editor(for id: UUID) -> Editor? {
        editors.first { $0.id == id }
    }
}
