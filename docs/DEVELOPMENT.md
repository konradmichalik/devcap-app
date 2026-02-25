# Development

## 🏗️ Architecture

```
SwiftUI (MenuBarExtra)
    │
    ├── AppState          @AppStorage persisted settings
    ├── MenubarView       Collapsible project/branch/commit tree
    └── DevcapBridge      Swift ↔ C FFI wrapper
            │
            ▼
    devcap-ffi            Rust staticlib, cbindgen-generated C header
            │
            ▼
    devcap-core           Git scanning, discovery, period parsing
```

The Rust FFI layer exposes a single `devcap_scan()` function that takes a path, time period, and optional author filter — returning a JSON-encoded array of project logs. The Swift side decodes this into native structs and renders the UI.

## 🛠️ Building from Source

### Requirements

- macOS 14.0+
- Xcode 16+
- Rust toolchain (`rustup`)
- [XcodeGen](https://github.com/yonaskolb/xcodegen) — `brew install xcodegen`

### Build

```bash
# Build Rust FFI + generate Xcode project + build macOS app
make build

# Or step by step:
make ffi      # Build Rust static library
make xcode    # Generate Xcode project from project.yml
make build    # Build the .app bundle
```

To run from Xcode, open `DevcapApp.xcodeproj` and press `Cmd+R`. The Rust library is built automatically via a pre-build script.
