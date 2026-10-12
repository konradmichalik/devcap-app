import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?
    weak var appState: AppState?

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
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Image(nsImage: MenubarGlyph.image(for: appState.menubarIconState, pulse: appState.scanPulse))
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
            MenubarLabel(appState: appState, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
