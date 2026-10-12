import Foundation

struct DayGroup {
    let label: String
    let commits: [Commit]
}

struct DayActivity: Equatable {
    let day: Date
    let count: Int
}

/// Pure derivations over scan results for the popover: compact numbers, daily
/// activity, day grouping and change detection. Display values use the author
/// timestamp, matching `Commit.timestamp`.
enum ActivityMetrics {
    static func compactCount(_ value: Int) -> String {
        switch value {
        case ..<1000:
            return String(value)
        case ..<10_000:
            return trimmed(Double(value) / 1000) + "k"
        case ..<1_000_000:
            return String(Int((Double(value) / 1000).rounded())) + "k"
        default:
            return trimmed(Double(value) / 1_000_000) + "M"
        }
    }

    static func pluralized(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    private static func trimmed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    /// Start of every local day the period covers, oldest first. Single-day
    /// periods have no meaningful series. The week starts on Monday regardless
    /// of the calendar's `firstWeekday`, because that is how the scan selects it.
    static func bucketDays(period: String, now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let count: Int
        switch period {
        case "7d": count = 7
        case "week": count = (calendar.component(.weekday, from: today) + 5) % 7 + 1
        default: return []
        }
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    static func dailyCounts(_ projects: [ProjectLog], period: String, now: Date, calendar: Calendar) -> [Int] {
        let days = bucketDays(period: period, now: now, calendar: calendar)
        guard !days.isEmpty else { return [] }

        let parser = ISO8601DateFormatter()
        var perDay: [Date: Int] = [:]
        for project in projects {
            var seen = Set<String>()
            for commit in project.branches.flatMap(\.commits) where seen.insert(commit.hash).inserted {
                guard let date = parser.date(from: commit.timestamp) else { continue }
                perDay[calendar.startOfDay(for: date), default: 0] += 1
            }
        }
        return days.map { perDay[$0] ?? 0 }
    }

    /// Splits commits (newest first) into runs of the same local day. A commit
    /// whose timestamp cannot be parsed stays with the run before it.
    static func dayGroups(_ commits: [Commit], now: Date, calendar: Calendar) -> [DayGroup] {
        let parser = ISO8601DateFormatter()
        var runs: [(day: Date?, commits: [Commit])] = []

        for commit in commits {
            let day = parser.date(from: commit.timestamp).map { calendar.startOfDay(for: $0) }
            if let last = runs.last, day == nil || day == last.day {
                runs[runs.count - 1].commits.append(commit)
            } else {
                runs.append((day, [commit]))
            }
        }

        return runs.map { DayGroup(label: dayLabel($0.day, now: now, calendar: calendar), commits: $0.commits) }
    }

    private static func dayLabel(_ day: Date?, now: Date, calendar: Calendar) -> String {
        guard let day else { return "Earlier" }
        let today = calendar.startOfDay(for: now)
        if day == today { return "Today" }
        if calendar.date(byAdding: .day, value: -1, to: today) == day { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    /// Projects with a commit the previous scan did not contain. The first scan
    /// of a period has nothing to compare against, so it flags nothing.
    static func freshProjectIDs(previous: [ProjectLog], current: [ProjectLog]) -> Set<String> {
        guard !previous.isEmpty else { return [] }

        let known = Dictionary(
            previous.map { ($0.id, Set($0.branches.flatMap(\.commits).map(\.hash))) },
            uniquingKeysWith: { first, _ in first }
        )
        return Set(current.filter { project in
            guard let hashes = known[project.id] else { return true }
            return project.branches.flatMap(\.commits).contains { !hashes.contains($0.hash) }
        }.map(\.id))
    }
}
