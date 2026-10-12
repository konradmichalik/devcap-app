import Foundation

/// Remembers the previous scan so the next one can report what is new. A scan
/// is only comparable to the one before when path and period are the same,
/// otherwise every project would look new after changing either.
struct FreshnessTracker {
    private var key: String?
    private var projects: [ProjectLog] = []

    mutating func fresh(in current: [ProjectLog], key: String) -> Set<String> {
        let previous = self.key == key ? projects : []
        self.key = key
        projects = current
        return ActivityMetrics.freshProjectIDs(previous: previous, current: current)
    }
}
