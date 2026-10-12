import AppKit

/// Blinks the menubar icon's dot while a scan runs. A separate object, so the
/// half-second tick only redraws the icon and not everything observing `AppState`.
@MainActor
final class ScanPulse: ObservableObject {
    @Published private(set) var isOn = true
    private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.isOn.toggle()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isOn = true
    }
}
