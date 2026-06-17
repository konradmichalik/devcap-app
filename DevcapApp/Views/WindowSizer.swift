import AppKit
import SwiftUI

/// Resizes the hosting `MenuBarExtra(.window)` panel to fit its SwiftUI content.
///
/// The window-style menu bar panel grows to its largest content size but never
/// shrinks back, which leaves the content vertically centered inside a stale,
/// oversized window when sections collapse. Observing `fittingSize` and pinning
/// the top edge keeps the panel snug under the menu bar.
struct WindowSizer: NSViewRepresentable {
    var trigger: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window,
                  let content = window.contentView else { return }

            let contentHeight = content.fittingSize.height
            guard contentHeight > 0 else { return }

            // Work in deltas against the current content rect so any titlebar
            // inset on the panel is preserved (matches FluidMenuBarExtra).
            let previousHeight = window.contentRect(forFrameRect: window.frame).size.height
            let deltaY = contentHeight - previousHeight
            guard abs(deltaY) > 0.5 else { return }

            var frame = window.frame
            frame.origin.y -= deltaY // pin the top edge under the menu bar
            frame.size.height += deltaY
            window.setFrame(frame, display: true, animate: true)
        }
    }
}
