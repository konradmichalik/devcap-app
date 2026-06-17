import AppKit
import SwiftUI

/// Resizes the hosting `MenuBarExtra(.window)` panel to a measured content height.
///
/// The window-style menu bar panel grows to its largest content size but never
/// shrinks back, which leaves the content vertically centered inside a stale,
/// oversized window when sections collapse. The system hosting view stretches to
/// fill that oversized window, so its `fittingSize` cannot be trusted — the real
/// content height has to be measured on the SwiftUI side and passed in here.
struct WindowSizer: NSViewRepresentable {
    /// The actual rendered height of the menu bar content, measured by the caller.
    var contentHeight: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let target = contentHeight
        DispatchQueue.main.async {
            guard target > 0, let window = nsView.window else { return }

            // Work in deltas against the current content rect so any titlebar
            // inset on the panel is preserved (matches FluidMenuBarExtra).
            let currentHeight = window.contentRect(forFrameRect: window.frame).size.height
            let deltaY = target - currentHeight
            guard abs(deltaY) > 0.5 else { return }

            var frame = window.frame
            frame.origin.y -= deltaY // pin the top edge under the menu bar
            frame.size.height += deltaY
            window.setFrame(frame, display: true, animate: true)
        }
    }
}
