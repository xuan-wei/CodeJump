import SwiftUI

struct HostPickerView: View {
    @Binding var selectedHost: String
    let hostGroups: [HostGroup]
    static let localTag = "__local__"

    @State private var isOpen = false
    @State private var hoveredHostName: String?

    var body: some View {
        HStack {
            Text("Host")
            Spacer()
            Button(action: { isOpen.toggle() }) {
                HStack(spacing: 4) {
                    Text(displayLabel)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isOpen, arrowEdge: .top) {
                popoverContent
            }
        }
    }

    private var displayLabel: String {
        if selectedHost == Self.localTag { return "💻 Local (no SSH)" }
        if selectedHost.isEmpty { return "Select host..." }
        return selectedHost
    }

    private func host(named name: String) -> SSHHost? {
        for group in hostGroups {
            if let h = group.hosts.first(where: { $0.name == name }) {
                return h
            }
        }
        return nil
    }

    private var popoverContent: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    listRow(tag: Self.localTag, label: "💻 Local (no SSH)")
                    ForEach(hostGroups) { group in
                        sectionHeader(group.name)
                        ForEach(group.hosts) { host in
                            hostListRow(host)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            detailPanel
                .frame(width: 260)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(height: 360)
    }

    private func sectionHeader(_ name: String) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func listRow(tag: String, label: String) -> some View {
        let isHovered = hoveredHostName == tag
        let isSelected = selectedHost == tag
        Button(action: {
            selectedHost = tag
            isOpen = false
        }) {
            HStack {
                Text(label)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isHovered ? Color.accentColor.opacity(0.18) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { hoveredHostName = tag }
        }
    }

    private func hostListRow(_ host: SSHHost) -> some View {
        listRow(tag: host.name, label: host.name)
    }

    @ViewBuilder
    private var detailPanel: some View {
        Group {
            if hoveredHostName == Self.localTag {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "laptopcomputer")
                            .foregroundStyle(.green)
                            .font(.title3)
                        Text("Local").font(.headline)
                    }
                    Text("Opens the path directly with the editor — no SSH.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let name = hoveredHostName, let host = host(named: name) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                            .font(.title3)
                        Text(host.name).font(.headline)
                    }
                    if host.hostName == nil && host.user == nil && host.port == nil {
                        Text("No details defined for this host.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if let hn = host.hostName { detailRow("HostName", hn) }
                            if let u = host.user { detailRow("User", u) }
                            if let p = host.port { detailRow("Port", "\(p)") }
                        }
                    }
                    Spacer()
                }
            } else {
                VStack {
                    Spacer()
                    Text("Hover a host to see its details")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
