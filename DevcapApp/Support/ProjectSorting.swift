import Foundation

/// Sorts scan results without recomputing derived values inside the comparator.
///
/// The previous comparators called `latestTimestamp` / `totalCommits` on every
/// comparison, so each expensive computation (a `flatMap` over all commits or a
/// `Set`-based dedup) ran O(n log n) times. Here each sort key is computed once
/// per project (decorate–sort–undecorate).
enum ProjectSorting {
    static func sorted(_ items: [ProjectLog], order: String) -> [ProjectLog] {
        switch order {
        case "name":
            return items.sorted {
                $0.project.localizedCaseInsensitiveCompare($1.project) == .orderedAscending
            }
        case "commits":
            return items
                .map { ($0, $0.totalCommits) }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        default: // "time"
            return items
                .map { ($0, $0.latestTimestamp ?? "") }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        }
    }
}
