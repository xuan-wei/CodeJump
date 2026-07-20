import SwiftUI

struct ProjectRowView: View {
    let project: RemoteProject
    @EnvironmentObject var projectStore: ProjectStore
    @State private var isHovering = false
    @State private var isOpening = false

    var body: some View {
        Button {
            Task { await openProject() }
        } label: {
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
                    HStack(spacing: 6) {
                        Text(project.name)
                            .font(.system(.body, weight: .medium))
                            .lineLimit(1)
                        if let timeAgo = RemoteProject.relativeTime(from: project.lastUsedAt) {
                            Text(timeAgo)
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(project.editor.name + " ▾")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 0.5))
                            )
                            .onTapGesture { showEditorMenu() }
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
        .disabled(isOpening)
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
            Button("Duplicate") { duplicateProject() }
            Button("Edit...") { editProject() }
            Button("Copy Command") { copyCommand() }
            Divider()
            Button("Delete", role: .destructive) { confirmDelete() }
        }
    }

    @MainActor
    private func openProject() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }

        let result = await ShellExecutor.openRemoteProject(project)
        if result.success {
            projectStore.recordUsage(project)
            PanelManager.shared.hide()
        } else if let msg = result.errorMessage {
            let alert = NSAlert()
            alert.messageText = "Failed to Open Project"
            alert.informativeText = msg
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func duplicateProject() {
        let copy = RemoteProject(
            name: project.name + " (Copy)",
            host: project.host,
            remotePath: project.remotePath,
            editorId: project.editorId,
            group: project.group,
            isLocal: project.isLocal
        )
        projectStore.add(copy)
    }

    private func editProject() {
        WindowManager.shared.open(id: "edit-\(project.id)", title: "Edit Project", width: 460, height: 400) {
            AddProjectView(projectStore: projectStore, editingProject: project)
        }
    }

    private func showEditorMenu() {
        let menu = NSMenu()
        for editor in EditorStore.shared.editors {
            let item = NSMenuItem(title: editor.name, action: #selector(EditorMenuTarget.selectEditor(_:)), keyEquivalent: "")
            item.state = editor.id == project.editorId ? .on : .off
            item.representedObject = EditorMenuAction(editorId: editor.id, projectId: project.id, store: projectStore)
            item.target = EditorMenuTarget.shared
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func confirmDelete() {
        let alert = NSAlert()
        alert.messageText = "Delete \"\(project.name)\"?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            projectStore.remove(project)
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
                projectStore.addGroup(newGroup)
                projectStore.setGroup(project, group: newGroup)
            }
        }
    }
}

private struct EditorMenuAction {
    let editorId: UUID
    let projectId: UUID
    let store: ProjectStore
}

private class EditorMenuTarget: NSObject {
    static let shared = EditorMenuTarget()
    @objc func selectEditor(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? EditorMenuAction else { return }
        action.store.mutateProject(action.projectId) { $0.editorId = action.editorId }
    }
}