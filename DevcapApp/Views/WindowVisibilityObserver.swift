import AppKit
import SwiftUI

/// Reports whether the hosting window is visible. `onAppear` is not enough for a
/// `MenuBarExtra` window: its content stays alive between openings.
struct WindowVisibilityObserver: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onChange = onChange
    }

    final class ObserverView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
            guard let window else { return }

            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self, weak window] _ in
                guard let window else { return }
                let isVisible = window.occlusionState.contains(.visible)
                MainActor.assumeIsolated { self?.onChange?(isVisible) }
            }
            onChange?(window.occlusionState.contains(.visible))
        }
    }
}
