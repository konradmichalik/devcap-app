import Foundation

enum ViewState: String, Codable, Equatable {
    case ok, warn, critical, idle
}

struct ExportView: Codable, Equatable {
    let id: String
    let label: String
    let value: String
    let detail: String?
    let progress: Double?
    let state: ViewState?
    let trend: [Double]?

    init(id: String, label: String, value: String, detail: String? = nil,
         progress: Double? = nil, state: ViewState? = nil, trend: [Double]? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.detail = detail
        self.progress = progress
        self.state = state
        self.trend = trend
    }
}

struct ExportPayload: Codable, Equatable {
    let schemaVersion: Int
    let app: String
    let displayName: String
    let updatedAt: String
    let ttlSeconds: Int
    let views: [ExportView]
}

enum ExportService {
    static let fileName = "data.json"
    private static let tempFileName = "data.json.tmp"

    static func buildPayload(
        ttlSeconds: Int,
        displayName: String = "devcap",
        now: Date = Date(),
        calendar: Calendar = .current,
        scan: (String) -> [ProjectLog]
    ) -> ExportPayload {
        let week = scan("week")
        let today = todayTotals(week, on: now, calendar: calendar)
        let weekCount = week.reduce(0) { $0 + $1.totalCommits }
        let top = ProjectSorting.sorted(week, order: "commits").first

        let views: [ExportView] = [
            ExportView(
                id: "today", label: "Heute", value: String(today.commits),
                detail: "\(today.projects) Projekte",
                state: today.commits == 0 ? .idle : .ok
            ),
            ExportView(
                id: "week", label: "Woche", value: String(weekCount),
                detail: "Mo bis So", state: .ok
            ),
            top.map {
                ExportView(
                    id: "top", label: "Top", value: $0.project,
                    detail: "\($0.totalCommits) Commits", state: .ok
                )
            } ?? ExportView(id: "top", label: "Top", value: "–", state: .idle),
        ]

        return ExportPayload(
            schemaVersion: 1,
            app: "devcap",
            displayName: displayName,
            updatedAt: ISO8601DateFormatter().string(from: now),
            ttlSeconds: ttlSeconds,
            views: views
        )
    }

    /// Today's figures are a filter over the week's scan, not a second scan.
    /// The week window starts at local Monday midnight, so it always contains
    /// today, and one traversal of ~150 repositories is enough.
    ///
    /// The filter runs on `committerTimestamp`, not on `timestamp`. The scan's
    /// own period selection is `git log --after`, which selects on the committer
    /// date, so only that field reproduces what a dedicated `today` scan would
    /// have returned. Filtering on the author date instead undercounts by every
    /// commit rebased, amended or cherry-picked into today.
    ///
    /// The day boundary is local. A commit at `2026-09-02T00:30:00+02:00` belongs
    /// to 2 September in Berlin but to 1 September in UTC, which is why the
    /// comparison runs over absolute instants and an explicit `Calendar`.
    private static func todayTotals(
        _ week: [ProjectLog],
        on day: Date,
        calendar: Calendar
    ) -> (commits: Int, projects: Int) {
        let parser = ISO8601DateFormatter()

        return week.reduce(into: (commits: 0, projects: 0)) { totals, project in
            var seen = Set<String>()
            let count = project.branches
                .flatMap(\.commits)
                .filter { isSameDay($0.committerTimestamp, as: day, calendar: calendar, parser: parser) }
                .filter { seen.insert($0.hash).inserted }
                .count

            guard count > 0 else { return }
            totals.commits += count
            totals.projects += 1
        }
    }

    private static func isSameDay(
        _ timestamp: String,
        as day: Date,
        calendar: Calendar,
        parser: ISO8601DateFormatter
    ) -> Bool {
        guard let date = parser.date(from: timestamp) else { return false }
        return calendar.isDate(date, inSameDayAs: day)
    }

    static func applicationSupportURL(
        baseDirectory: URL? = nil,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.konradmichalik.devcap"
    ) throws -> URL {
        let base = try baseDirectory ?? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func write(_ payload: ExportPayload, to directory: URL) throws {
        let data = try JSONEncoder().encode(payload)

        let target = directory.appendingPathComponent(fileName)
        let tmp = directory.appendingPathComponent(tempFileName)

        try data.write(to: tmp)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)

        guard rename(tmp.path, target.path) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    static func delete(from directory: URL) throws {
        let target = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        try FileManager.default.removeItem(at: target)
    }
}
