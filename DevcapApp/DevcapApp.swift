import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?
    /// Set once the menubar label exists, so the status item can be clicked.
    weak var appState: AppState? {
        didSet { runPendingShow() }
    }
    private var pendingShow = false

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: DevcapURL.isShow) else { return }
        pendingShow = true
        runPendingShow()
    }

    /// A URL can launch the app, so it may arrive before `appState` is set.
    private func runPendingShow() {
        guard let appState, pendingShow else { return }
        pendingShow = false
        guard !appState.isPopoverVisible else { return }
        NSApp.activate(ignoringOtherApps: true)
        Task { await clickStatusItemWhenReady() }
    }

    /// On a cold launch the status item window may not exist yet, so retry briefly.
    private func clickStatusItemWhenReady() async {
        for _ in 0..<10 {
            if clickStatusItem() { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// MenuBarExtra has no public API to open its popup, so click the status item button.
    /// Finds it through the private window class name, like the right-click detection.
    private func clickStatusItem() -> Bool {
        let button = NSApp.windows
            .filter { String(describing: type(of: $0)).contains("StatusBar") }
            .lazy
            .compactMap { $0.contentView.flatMap(Self.firstButton) }
            .first
        button?.performClick(nil)
        return button != nil
    }

    private static func firstButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        return view.subviews.lazy.compactMap(firstButton).first
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Detect right-clicks on the MenuBarExtra status item.
        // Uses private window class name — no public API exists for this.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] event in
            guard let window = event.window,
                  String(describing: type(of: window)).contains("StatusBar") else {
                return event
            }
            self?.showContextMenu(with: event)
            return nil
        }
    }

    private func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit devcap", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let contentView = event.window?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        }
    }

    @objc private func refreshNow() {
        appState?.refresh()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        appState?.openSettingsAction?()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

/// The label exists from launch, unlike the popover content. The right-click menu
/// needs `appState` and the settings action before the popover was ever opened.
private struct MenubarLabel: View {
    @ObservedObject var appState: AppState
    @ObservedObject var pulse: ScanPulse
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Image(nsImage: MenubarGlyph.image(for: appState.menubarIconState, pulse: pulse.isOn))
            if let count = appState.badgeCount {
                Text("\(count)")
            }
        }
        .task {
            appDelegate.appState = appState
            appState.openSettingsAction = { openSettings() }
        }
    }
}

@main
struct DevcapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenubarView()
                .environmentObject(appState)
        } label: {
            MenubarLabel(appState: appState, pulse: appState.scanPulse, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
