import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("defaultEditorId") private var defaultEditorId = ""
    @State private var launchAtLogin = false
    @ObservedObject private var editorStore = EditorStore.shared
    @ObservedObject private var hostStore = HostStore.shared
    @ObservedObject private var configStore = SSHConfigStore.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @ObservedObject private var projectStore = ProjectStore.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            editorsTab.tabItem { Label("Editors", systemImage: "terminal") }.tag(1)
            hostsTab.tabItem { Label("Hosts", systemImage: "network") }.tag(2)
            groupsTab.tabItem { Label("Groups", systemImage: "folder") }.tag(3)
        }
        .frame(width: 540, height: 460)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var generalTab: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                    Button {
                        updateChecker.checkNow()
                    } label: {
                        if updateChecker.isChecking {
                            ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                        } else {
                            Text("Check for Updates").font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(updateChecker.isChecking)
                }

                if updateChecker.hasUpdate, let ver = updateChecker.latestVersion {
                    HStack {
                        Image(systemName: "gift.fill").foregroundStyle(.orange)
                        Text("New version \(ver) available").foregroundStyle(.orange)
                        Spacer()
                        if let url = updateChecker.releaseURL {
                            Link("Download", destination: url)
                        }
                    }
                } else if let result = updateChecker.lastCheckResult {
                    HStack {
                        Image(systemName: result.hasPrefix("Check failed") ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundStyle(result.hasPrefix("Check failed") ? .orange : .green)
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Repository")
                    Spacer()
                    Link("github.com/xuan-wei/CodeJump", destination: URL(string: "https://github.com/xuan-wei/CodeJump")!)
                        .font(.caption)
                }

                HStack {
                    Text("Author")
                    Spacer()
                    Text("Xuan Wei").foregroundStyle(.secondary)
                }

                HStack {
                    Text("License")
                    Spacer()
                    Text("MIT").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var editorsTab: some View {
        VStack(spacing: 0) {
            Form {
                Section("Default Editor") {
                    Picker("Editor", selection: $defaultEditorId) {
                        Text("Auto").tag("")
                        ForEach(editorStore.editors) { e in
                            Text(e.name).tag(e.id.uuidString)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 100)

            Divider()

            List {
                ForEach(editorStore.editors) { editor in
                    HStack {
                        Image(systemName: editor.iconName)
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text(editor.name).font(.body)
                            Text(editor.cliPath).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if Editor.builtins.contains(editor) {
                            Text("Built-in").font(.caption2).foregroundStyle(.tertiary)
                        } else {
                            Button(action: { editorStore.remove(editor) }) {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Divider()
            AddEditorRow(editorStore: editorStore).padding(10)
        }
    }

    private var hostsTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sshConfigSection
                    customHostsSection
                }
                .padding(12)
            }
        }
    }

    private var sshConfigSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SSH Config Files")
                .font(.headline)
            Text("Hosts from these files appear in the project's Host picker.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach($configStore.configs) { $config in
                SSHConfigFileRow(config: $config, configStore: configStore)
            }

            AddSSHConfigRow(configStore: configStore)
                .padding(.top, 4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    private var customHostsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CodeJump Managed Hosts")
                .font(.headline)
            includeBanner

            ForEach($hostStore.customHosts) { $host in
                CustomHostRow(host: $host, hostStore: hostStore)
            }

            AddHostRow(hostStore: hostStore)
                .padding(.top, 4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    private var groupsTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Groups")
                        .font(.headline)
                    Text("Organize projects into groups. Groups persist even when empty.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(projectStore.allGroups, id: \.self) { group in
                        GroupManagementRow(group: group, projectStore: projectStore)
                    }

                    AddGroupRow(projectStore: projectStore)
                        .padding(.top, 4)
                }
                .padding(12)
            }
        }
    }

    private var includeBanner: some View {
        let isIncluded = hostStore.isIncludedAnywhere(configStore: configStore)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isIncluded ? .green : .orange)
                Text(isIncluded ? "Custom hosts are active" : "Custom hosts file is not Included")
                    .font(.caption.bold())
                Spacer()
            }
            Text("Hosts written to: \(HostStore.managedConfigPath)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if !isIncluded {
                HStack(spacing: 6) {
                    Text(HostStore.includeDirective)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(HostStore.includeDirective, forType: .string)
                    }
                    .controlSize(.small)
                    if let first = configStore.configs.first {
                        Button("Add to \(first.name)") {
                            hostStore.addIncludeDirective(to: first.path)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }
}

struct SSHConfigFileRow: View {
    @Binding var config: SSHConfigFile
    @ObservedObject var configStore: SSHConfigStore
    @State private var editName = ""
    @State private var editPath = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $editName)
                    .font(.body)
                    .onSubmit { commit() }
                TextField("Path", text: $editPath, prompt: Text("~/.ssh/config"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .onSubmit { commit() }
            }
            Button(action: { configStore.remove(config) }) {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .disabled(configStore.configs.count <= 1)
        }
        .padding(.vertical, 4)
        .onAppear { editName = config.name; editPath = config.path }
        .onDisappear { commit() }
    }

    private func commit() {
        if editName != config.name { config.name = editName }
        if editPath != config.path { config.path = editPath }
    }
}

struct AddSSHConfigRow: View {
    @ObservedObject var configStore: SSHConfigStore
    @State private var name = ""
    @State private var path = ""

    var body: some View {
        HStack {
            TextField("Name", text: $name, prompt: Text("e.g. Work"))
                .frame(maxWidth: 100)
            TextField("Path", text: $path, prompt: Text("~/.ssh/config"))
            Button("Add") {
                let n = name.trimmingCharacters(in: .whitespaces)
                let p = path.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && !p.isEmpty {
                    configStore.add(SSHConfigFile(name: n, path: p))
                    name = ""
                    path = ""
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || path.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

struct AddEditorRow: View {
    @ObservedObject var editorStore: EditorStore
    @State private var name = ""
    @State private var cliPath = ""

    var body: some View {
        HStack {
            TextField("Name", text: $name, prompt: Text("e.g. Windsurf"))
                .frame(maxWidth: 120)
            TextField("CLI Path", text: $cliPath, prompt: Text("/usr/local/bin/windsurf"))
            Button("Add") {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let trimmedPath = cliPath.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty && !trimmedPath.isEmpty {
                    editorStore.add(Editor(name: trimmedName, cliPath: trimmedPath))
                    name = ""
                    cliPath = ""
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || cliPath.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

struct CustomHostRow: View {
    @Binding var host: CustomHost
    @ObservedObject var hostStore: HostStore
    @State private var isExpanded = false
    @State private var editName = ""
    @State private var editHostName = ""
    @State private var editPort = ""
    @State private var editUser = ""
    @State private var editIdentityFile = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: { if isExpanded { commitAll() }; isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Text(host.name).font(.body.bold())
                Spacer()
                if !host.hostName.isEmpty {
                    Text("\(host.hostName)\(host.port.map { ":\($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(action: { hostStore.remove(host) }) {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
            if isExpanded {
                VStack(spacing: 6) {
                    TextField("Alias", text: $editName)
                        .onSubmit { commitAll() }
                    TextField("HostName", text: $editHostName, prompt: Text("192.168.1.100 or example.com"))
                        .onSubmit { commitAll() }
                    HStack {
                        Text("Port").frame(width: 80, alignment: .leading)
                        TextField("22", text: $editPort, prompt: Text("22"))
                            .onSubmit { commitAll() }
                    }
                    TextField("User", text: $editUser, prompt: Text("username"))
                        .onSubmit { commitAll() }
                    TextField("IdentityFile", text: $editIdentityFile, prompt: Text("~/.ssh/id_rsa"))
                        .onSubmit { commitAll() }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.leading, 16)
                .padding(.top, 4)
                .onAppear { loadFields() }
                .onDisappear { commitAll() }
            }
        }
        .padding(.vertical, 4)
    }

    private func loadFields() {
        editName = host.name
        editHostName = host.hostName
        editPort = host.port.map(String.init) ?? ""
        editUser = host.user
        editIdentityFile = host.identityFile
    }

    private func commitAll() {
        var changed = false
        if editName != host.name { host.name = editName; changed = true }
        if editHostName != host.hostName { host.hostName = editHostName; changed = true }
        let newPort = Int(editPort)
        if newPort != host.port { host.port = newPort; changed = true }
        if editUser != host.user { host.user = editUser; changed = true }
        if editIdentityFile != host.identityFile { host.identityFile = editIdentityFile; changed = true }
        _ = changed
    }
}

struct AddHostRow: View {
    @ObservedObject var hostStore: HostStore
    @State private var name = ""

    var body: some View {
        HStack {
            TextField("New host alias", text: $name, prompt: Text("e.g. MyServer"))
            Button("Add") {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    hostStore.add(CustomHost(name: trimmed))
                    name = ""
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

struct GroupManagementRow: View {
    let group: String
    @ObservedObject var projectStore: ProjectStore
    @State private var isEditing = false
    @State private var editedName = ""

    private var projectCount: Int {
        projectStore.projects.filter { $0.group == group }.count
    }

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            if isEditing {
                TextField("Group name", text: $editedName, onCommit: commitRename)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { commitRename() }
                    .controlSize(.small)
                Button("Cancel") { isEditing = false }
                    .controlSize(.small)
            } else {
                Text(group).font(.body)
                Spacer()
                Text("\(projectCount) project\(projectCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if group != "Default" {
                    Button(action: {
                        editedName = group
                        isEditing = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    Button(action: { projectStore.removeGroup(group) }) {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete group and move its projects to Default")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != group {
            projectStore.renameGroup(from: group, to: trimmed)
        }
        isEditing = false
    }
}

struct AddGroupRow: View {
    @ObservedObject var projectStore: ProjectStore
    @State private var name = ""

    var body: some View {
        HStack {
            TextField("New group name", text: $name, prompt: Text("e.g. Work Projects"))
            Button("Add") {
                projectStore.addGroup(name)
                name = ""
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
