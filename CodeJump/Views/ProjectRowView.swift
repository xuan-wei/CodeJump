import SwiftUI

struct ProjectRowView: View {
    let project: RemoteProject
    @EnvironmentObject var projectStore: ProjectStore
    @State private var isHovering = false

    var body: some View {
        Button(action: openProject) {
            HStack(spacing: 10) {
                ZStack {
                    Image(systemName: project.editor.iconName)
                        .font(.title3)
                        .foregroundStyle(.blue)
                    if project.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.yellow)
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(project.editor.name)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                        if project.isLocal {
                            Text("Local")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text(project.host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if project.group != "Default" {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(project.group)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(project.remotePath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: "arrowshape.right.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
            .opacity(project.isHidden ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(project.isFavorite ? "Unfavorite" : "Favorite") {
                projectStore.toggleFavorite(project)
            }
            Button(project.isHidden ? "Show" : "Hide") {
                projectStore.toggleHidden(project)
            }
            Divider()
            Menu("Move to Group") {
                ForEach(projectStore.allGroups, id: \.self) { group in
                    Button(group) {
                        projectStore.setGroup(project, group: group)
                    }
                    .disabled(group == project.group)
                }
                Divider()
                Button("New Group...") { promptNewGroup() }
            }
            Divider()
            Button("Edit...") { editProject() }
            Button("Copy Command") { copyCommand() }
            Divider()
            Button("Delete", role: .destructive) { projectStore.remove(project) }
        }
    }

    private func openProject() {
        ShellExecutor.openRemoteProject(project)
        PanelManager.shared.hide()
    }

    private func editProject() {
        WindowManager.shared.open(id: "edit-\(project.id)", title: "Edit Project", width: 460, height: 400) {
            AddProjectView(projectStore: projectStore, editingProject: project)
        }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ShellExecutor.commandString(for: project), forType: .string)
    }

    private func promptNewGroup() {
        let alert = NSAlert()
        alert.messageText = "New Group"
        alert.informativeText = "Enter a name for the new group:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = ""
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        if alert.runModal() == .alertFirstButtonReturn {
            let newGroup = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !newGroup.isEmpty {
                projectStore.setGroup(project, group: newGroup)
            }
        }
    }
}
