# worklog.app

Native macOS menubar app for [worklog-git](https://github.com/konradmichalik/worklog-git) — shows your daily git commits at a glance without leaving the keyboard.

Scans a directory tree for git repos in parallel via the same Rust core, and renders a collapsible `Project > Branch > Commits` tree directly in your menubar.

## Features

- **Menubar-native** — lives in the system menubar, no Dock icon
- **Collapsible tree** — drill down through projects, branches, and commits
- **Conventional commit highlighting** — color-coded type tags (`feat`, `fix`, `refactor`, ...)
- **Flexible time periods** — Today, Yesterday, This Week, Last 7 Days
- **Auto-refresh** — configurable interval (5 / 15 / 30 minutes)
- **Copy commit hash** — click any commit to copy its hash to the clipboard
- **Parallel scanning** — powered by [rayon](https://github.com/rayon-rs/rayon) via worklog-core

> [!NOTE]
> Requires `git` on `$PATH`. Author defaults to `git config --global user.name`.

## Requirements

- macOS 14.0+
- Xcode 16+
- Rust toolchain (`rustup`)
- [XcodeGen](https://github.com/yonaskolb/xcodegen) — `brew install xcodegen`

## Build

```bash
# Build Rust FFI + generate Xcode project + build macOS app
make build

# Or step by step:
make ffi      # Build Rust static library
make xcode    # Generate Xcode project from project.yml
make build    # Build the .app bundle
```

To run from Xcode, open `WorklogApp.xcodeproj` and press `Cmd+R`. The Rust library is built automatically via a pre-build script.

## Architecture

```
SwiftUI (MenuBarExtra)
    │
    ├── AppState          @AppStorage persisted settings
    ├── MenubarView       Collapsible project/branch/commit tree
    └── WorklogBridge     Swift ↔ C FFI wrapper
            │
            ▼
    worklog-ffi           Rust staticlib, cbindgen-generated C header
            │
            ▼
    worklog-core          Git scanning, discovery, period parsing
```

The Rust FFI layer exposes a single `worklog_scan()` function that takes a path, time period, and optional author filter — returning a JSON-encoded array of project logs. The Swift side decodes this into native structs and renders the UI.

## Configuration

All settings are accessible via the gear icon in the menubar popover:

| Setting | Default | Description |
|---------|---------|-------------|
| Scan Path | `~/Sites` | Root directory to scan for git repos |
| Period | Today | Time filter for commits |
| Auto-refresh | 15 min | Background refresh interval (Off / 5 / 15 / 30 min) |

## Related

- [worklog-git](https://github.com/konradmichalik/worklog-git) — CLI tool (Homebrew: `brew install konradmichalik/tap/worklog-git`)

## License

MIT
