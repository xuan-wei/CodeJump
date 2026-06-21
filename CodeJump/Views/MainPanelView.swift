import SwiftUI

struct MainPanelView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            if updateChecker.hasUpdate {
                updateBanner
            }
            Divider()
            if projectStore.projects.isEmpty {
                emptyState
            } else {
                searchBar
                projectList
                if projectStore.hiddenCount > 0 {
                    hiddenToggle
                }
            }
        }
        .frame(width: 360)
    }

    private var updateBanner: some View {
        HStack(spacing: 0) {
            Button {
                if let url = updateChecker.releaseURL { NSWorkspace.shared.open(url) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                    Text("Version \(updateChecker.latestVersion ?? "") available")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                updateChecker.skipCurrentVersion()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Skip this version")
            .padding(.trailing, 4)
        }
        .background(
            LinearGradient(colors: [.orange, Color(red: 1.0, green: 0.55, blue: 0.0)],
                           startPoint: .leading, endPoint: .trailing)
        )
    }

    private var header: some View {
        HStack {
            Text("CodeJump")
                .font(.headline)
            Spacer()
            Button(action: openAddProject) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search projects...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No remote projects")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add Project") { openAddProject() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var projectList: some View {
        let groups = projectStore.groupedProjects(searchText: searchText)
        return ScrollView {
            LazyVStack(spacing: 0) {
                if groups.isEmpty && !searchText.isEmpty {
                    Text("No matching projects")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                }
                ForEach(groups) { group in
                    groupSection(group)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func groupSection(_ group: GroupedProjects) -> some View {
        let isCollapsed = projectStore.collapsedGroups.contains(group.name)
        return VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { projectStore.toggleGroup(group.name) } }) {
                HStack(spacing: 6) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Image(systemName: group.isFavoriteGroup ? "star.fill" : "folder.fill")
                        .font(.caption)
                        .foregroundStyle(group.isFavoriteGroup ? .yellow : .secondary)
                    Text(group.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(group.projects.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(group.projects) { project in
                    ProjectRowView(project: project)
                        .environmentObject(projectStore)
                }
            }
        }
    }

    private var hiddenToggle: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: { projectStore.showHidden.toggle() }) {
                HStack {
                    Image(systemName: projectStore.showHidden ? "eye" : "eye.slash")
                        .font(.caption)
                    Text(projectStore.showHidden ? "Hide hidden projects" : "Show \(projectStore.hiddenCount) hidden")
                        .font(.caption)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func openAddProject() {
        WindowManager.shared.open(id: "add-project", title: "Add Project", width: 460, height: 400) {
            AddProjectView(projectStore: projectStore)
        }
    }

    private func openSettings() {
        WindowManager.shared.open(id: "settings", title: "CodeJump Settings", width: 540, height: 460) {
            SettingsView()
        }
    }
}
