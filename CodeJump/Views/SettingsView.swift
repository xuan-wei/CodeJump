import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("defaultEditorId") private var defaultEditorId = ""
    @State private var launchAtLogin = false
    @ObservedObject private var editorStore = EditorStore.shared
    @ObservedObject private var hostStore = HostStore.shared
    @ObservedObject private var configStore = SSHConfigStore.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            editorsTab.tabItem { Label("Editors", systemImage: "terminal") }.tag(1)
            hostsTab.tabItem { Label("Hosts", systemImage: "network") }.tag(2)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $config.name)
                    .font(.body)
                TextField("Path", text: $config.path, prompt: Text("~/.ssh/config"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Button(action: { configStore.remove(config) }) {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .disabled(configStore.configs.count <= 1)
        }
        .padding(.vertical, 4)
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
    @State private var portText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: { isExpanded.toggle() }) {
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
                    TextField("Alias", text: $host.name)
                    TextField("HostName", text: $host.hostName, prompt: Text("192.168.1.100 or example.com"))
                    HStack {
                        Text("Port").frame(width: 80, alignment: .leading)
                        TextField("22", text: $portText, prompt: Text("22"))
                            .onChange(of: portText) { _, newValue in
                                host.port = Int(newValue)
                            }
                    }
                    TextField("User", text: $host.user, prompt: Text("username"))
                    TextField("IdentityFile", text: $host.identityFile, prompt: Text("~/.ssh/id_rsa"))
                }
                .textFieldStyle(.roundedBorder)
                .padding(.leading, 16)
                .padding(.top, 4)
                .onAppear {
                    portText = host.port.map(String.init) ?? ""
                }
            }
        }
        .padding(.vertical, 4)
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
