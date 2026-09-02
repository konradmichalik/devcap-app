<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/devcap-app-logo-dark.svg">
    <img src="docs/images/devcap-app-logo.svg" width="400" alt="devcap.app logo">
  </picture>
</p>

<p align="center">
  Native macOS menubar app for <a href="https://github.com/konradmichalik/devcap">devcap</a> — shows your daily git commits at a glance without leaving the keyboard.
</p>

Scans a directory tree for git repos in parallel via the same Rust core, and renders a collapsible `Project > Branch > Commits` tree directly in your menubar.

![screenshot.jpg](docs/images/screenshot.jpg)

## ✨ Features

- **Menubar-native** — lives in the system menubar, no Dock icon
- **Collapsible tree** — drill down through projects, branches, and commits
- **Conventional commit highlighting** — color-coded type tags (`feat`, `fix`, `refactor`, ...)
- **Flexible time periods** — Today, Yesterday, This Week, Last 7 Days
- **Auto-refresh** — configurable interval (5 / 15 / 30 minutes)
- **Copy commit hash** — right-click any commit to copy its hash to the clipboard
- **Parallel scanning** — powered by [rayon](https://github.com/rayon-rs/rayon) via devcap-core
- **Export for external apps** — optional setting that writes a small `data.json` snapshot (today/week commit counts, top project) on a background interval, for consumers like a Stream Deck plugin

> [!NOTE]
> Requires `git` on `$PATH`. Author defaults to `git config --global user.name`.

### Export data for external apps

When enabled in Settings, devcap.app periodically scans in the background and writes a snapshot to:

```
~/Library/Application Support/com.konradmichalik.devcap/data.json
```

The file is written atomically with `0600` permissions and removed as soon as the setting is turned off.

## 🔥 Installation

### Homebrew (macOS)

[![Homebrew version](https://img.shields.io/endpoint?url=https%3A%2F%2Fkonradmichalik.github.io%2Fhomebrew-tap%2Fbadges%2Fdevcap-app-version.json&style=flat-square&logo=homebrew)](https://github.com/konradmichalik/homebrew-tap)
[![Homebrew downloads](https://img.shields.io/endpoint?url=https%3A%2F%2Fkonradmichalik.github.io%2Fhomebrew-tap%2Fbadges%2Fdevcap-app-downloads.json&style=flat-square&logo=homebrew)](https://github.com/konradmichalik/homebrew-tap)

```bash
brew install --cask konradmichalik/tap/devcap-app
```

To update to the latest version:

```bash
brew upgrade --cask konradmichalik/tap/devcap-app
```

### Download

Grab the latest `.dmg` from [Releases](https://github.com/konradmichalik/devcap-app/releases), open it, and drag the app to Applications.

> [!TIP]
> Want to build from source? See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## 📜 License

MIT
