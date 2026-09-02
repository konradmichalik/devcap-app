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
        today: [ProjectLog],
        week: [ProjectLog],
        displayName: String = "devcap",
        ttlSeconds: Int,
        now: Date = Date()
    ) -> ExportPayload {
        let todayCount = today.reduce(0) { $0 + $1.totalCommits }
        let weekCount = week.reduce(0) { $0 + $1.totalCommits }
        let top = ProjectSorting.sorted(week, order: "commits").first

        let views: [ExportView] = [
            ExportView(
                id: "today", label: "Heute", value: String(todayCount),
                detail: "\(today.count) Projekte",
                state: todayCount == 0 ? .idle : .ok
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
