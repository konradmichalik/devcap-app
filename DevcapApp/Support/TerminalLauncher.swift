import Foundation

/// Opens a directory in Terminal.app without going through a shell.
///
/// The previous implementation interpolated the path into an AppleScript
/// `do script "cd …"` string, which runs in Terminal's shell. Characters such
/// as `$(…)`, backticks or `;` in a directory name would then be executed —
/// a command-injection vector. Here the path is handed to `/usr/bin/open` as a
/// single argument via `execve`, so it is never interpreted by any shell.
enum TerminalLauncher {
    /// Arguments passed to `/usr/bin/open` to reveal `path` in Terminal.
    ///
    /// The path is always the final, standalone element — no shell
    /// metacharacter in it can split or escape the argument.
    static func openArguments(for path: String) -> [String] {
        ["-a", "Terminal", path]
    }

    static func open(path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = openArguments(for: path)
        do {
            try process.run()
        } catch {
            NSLog("TerminalLauncher: failed to open Terminal at %@: %@", path, error.localizedDescription)
        }
    }
}
