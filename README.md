# CodeJump

A native macOS menu bar app for one-click opening of remote (SSH) and local code projects in Cursor, VSCode, or any editor you add.

## Why?

Opening a remote project in Cursor or VSCode normally requires a long command like:

```bash
cursor --remote ssh-remote+MyServer /home/me/some/project
```

If you have many remote projects across many SSH hosts, this gets tedious fast. CodeJump lives in your menu bar and gives you saved projects you can launch with one click — pick a host from your SSH config, pick a path, save, done.

## Features

- **Multi-editor** — Built-in support for Cursor and VSCode; add any other CLI-based editor (Windsurf, Trae, etc.)
- **Multi-host source** — Hosts can come from multiple SSH config files, CodeJump-managed custom hosts, or just be a local path
- **Local projects** — `cursor /path` style, no SSH
- **Project organization** — Group, favorite (pinned), hide, and search across many projects
- **Custom SSH hosts** — Define hosts with full SSH fields (HostName/Port/User/IdentityFile), written to `~/.codejump/ssh_config` for Cursor/VSCode to consume
- **Auto-hide panel** — Click outside to dismiss
- **Auto-update check** — Daily check against GitHub Releases; non-intrusive banner when a new version ships
- **Launch at login** — optional via `SMAppService`

## Requirements

- macOS 14.0 (Sonoma) or later
- `cursor` and/or `code` CLI installed (the editors' "Install 'cursor' command in PATH" command)

## Install

1. Download the latest `CodeJump-vX.Y.Z.zip` from [Releases](https://github.com/xuan-wei/CodeJump/releases)
2. Unzip and move `CodeJump.app` to `/Applications`
3. Remove the quarantine flag (the app is ad-hoc signed, not notarized):

   ```bash
   xattr -cr /Applications/CodeJump.app
   ```

4. Launch it — a square-with-arrow icon appears in your menu bar

## Usage

- **Left-click** the menu bar icon → opens the project panel
- **Right-click** → Settings / Quit
- **+** in the panel → add a new project
- **Right-click a project row** → favorite, hide, move to group, edit, copy command, delete

### Adding a project

1. Pick an Editor (Cursor / VSCode / your own)
2. Pick a Host — `💻 Local`, a host from your SSH config, or a CodeJump-managed custom host
3. Enter the Remote Path (or Local Path)
4. Optionally name it and put it in a Group

### Custom hosts

If a host isn't in your SSH config, add it in **Settings → Hosts**. CodeJump writes them to `~/.codejump/ssh_config`. To make Cursor/VSCode pick them up, add this line to your VSCode SSH config (the banner in Settings can do it for you):

```sshconfig
Include ~/.codejump/ssh_config
```

## Build from source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/xuan-wei/CodeJump.git
cd CodeJump
xcodegen generate
xcodebuild -project CodeJump.xcodeproj -scheme CodeJump -configuration Release build
```

The built app lands in `~/Library/Developer/Xcode/DerivedData/CodeJump-*/Build/Products/Release/CodeJump.app`.

## Project structure

```
CodeJump/
├── CodeJumpApp.swift          # @main, AppDelegate, NSStatusItem
├── Models/
│   ├── Editor.swift           # Editor + EditorStore
│   ├── SSHHost.swift          # SSHHost, CustomHost, HostStore (writes ~/.codejump/ssh_config)
│   ├── SSHConfigFile.swift    # SSHConfigFile + SSHConfigStore (multi-file)
│   └── RemoteProject.swift    # RemoteProject + ProjectStore
├── Services/
│   ├── SSHConfigParser.swift  # parses Host entries from SSH config
│   ├── ShellExecutor.swift    # runs the editor command (local or --remote ssh-remote+...)
│   └── UpdateChecker.swift    # GitHub releases poll
├── Utilities/
│   ├── PanelManager.swift     # Floating NSPanel
│   └── WindowManager.swift    # Settings/editor NSWindow
└── Views/
    ├── MainPanelView.swift    # Project list (grouped, search, hide)
    ├── ProjectRowView.swift   # One row
    ├── AddProjectView.swift   # Add/edit form
    ├── HostPickerView.swift   # Custom popover with hover-detail
    └── SettingsView.swift     # General / Editors / Hosts tabs
```

## License

MIT

## Author

[Xuan Wei](https://github.com/xuan-wei)

Built with [Claude Code](https://claude.com/claude-code).
