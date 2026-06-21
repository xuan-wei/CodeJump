import SwiftUI

struct AddProjectView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var editorStore = EditorStore.shared
    @ObservedObject var hostStore = HostStore.shared
    @ObservedObject var configStore = SSHConfigStore.shared
    var editingProject: RemoteProject?

    @AppStorage("defaultEditorId") private var defaultEditorId = ""
    @AppStorage("lastSelectedHost") private var lastSelectedHost = "__local__"

    static let localTag = RemoteProject.localHostTag

    @State private var name = ""
    @State private var selectedHost = "__local__"
    @State private var remotePath = ""
    @State private var selectedEditorId: UUID = Editor.builtinCursor.id
    @State private var hostGroups: [HostGroup] = []
    @State private var selectedGroup = "Default"
    @State private var newGroupName = ""
    @State private var isCreatingNewGroup = false

    private var isEditing: Bool { editingProject != nil }
    private var isLocal: Bool { selectedHost == Self.localTag }

    private var groupOptions: [String] {
        var groups = projectStore.allGroups
        if !groups.contains("Default") {
            groups.insert("Default", at: 0)
        }
        return groups
    }

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section {
                    Picker("Editor", selection: $selectedEditorId) {
                        ForEach(editorStore.editors) { e in
                            Text(e.name).tag(e.id)
                        }
                    }
                }

                Section {
                    HostPickerView(selectedHost: $selectedHost, hostGroups: hostGroups)
                }

                Section {
                    TextField(isLocal ? "Local Path" : "Remote Path", text: $remotePath,
                              prompt: Text(isLocal ? "/Users/you/project" : "/home/user/project"))
                    TextField("Name (optional)", text: $name, prompt: Text("Auto-generated from path"))
                }

                Section {
                    HStack {
                        Picker("Group", selection: $selectedGroup) {
                            ForEach(groupOptions, id: \.self) { group in
                                Text(group).tag(group)
                            }
                            Divider()
                            Text("New Group...").tag("__new__")
                        }
                        .onChange(of: selectedGroup) { _, newValue in
                            if newValue == "__new__" {
                                isCreatingNewGroup = true
                                selectedGroup = "Default"
                            }
                        }
                    }

                    if isCreatingNewGroup {
                        HStack {
                            TextField("New group name", text: $newGroupName)
                            Button("Create") {
                                if !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                                    projectStore.addGroup(trimmed)
                                    selectedGroup = trimmed
                                    isCreatingNewGroup = false
                                    newGroupName = ""
                                }
                            }
                            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                            Button("Cancel") {
                                isCreatingNewGroup = false
                                newGroupName = ""
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    saveProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedHost.isEmpty || remotePath.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .onAppear {
            hostGroups = hostStore.groupedHosts(configStore: configStore)
            if let project = editingProject {
                name = project.name
                selectedHost = project.isLocal ? Self.localTag : project.host
                remotePath = project.remotePath
                selectedEditorId = project.editorId
                selectedGroup = project.group
            } else {
                if let uuid = UUID(uuidString: defaultEditorId) {
                    selectedEditorId = uuid
                }
                selectedHost = lastSelectedHost
            }
        }
    }

    private func saveProject() {
        let finalGroup = selectedGroup
        let local = isLocal
        let hostName = local ? "" : selectedHost
        let displayHost = local ? "Local" : hostName
        let resolvedName = name.isEmpty ? RemoteProject.defaultName(host: displayHost, path: remotePath) : name
        lastSelectedHost = selectedHost
        if var project = editingProject {
            project.name = resolvedName
            project.host = hostName
            project.remotePath = remotePath
            project.editorId = selectedEditorId
            project.group = finalGroup
            project.isLocal = local
            projectStore.update(project)
        } else {
            let project = RemoteProject(name: resolvedName,
                                        host: hostName,
                                        remotePath: remotePath,
                                        editorId: selectedEditorId,
                                        group: finalGroup,
                                        isLocal: local)
            projectStore.add(project)
        }
        closeWindow()
    }

    private func closeWindow() {
        if let project = editingProject {
            WindowManager.shared.close(id: "edit-\(project.id)")
        } else {
            WindowManager.shared.close(id: "add-project")
        }
    }
}
