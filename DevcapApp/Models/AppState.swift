import SwiftUI
import Combine
import OSLog

@MainActor
final class AppState: ObservableObject {
    @Published var projects: [ProjectLog] = [] {
        didSet { recomputeTotals() }
    }
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    @Published var allExpanded = true
    @Published var expansionID = UUID()

    @AppStorage("scanPath") var scanPath = ""
    @AppStorage("period") var period = "today"
    @AppStorage("refreshInterval") var refreshInterval: TimeInterval = 900 // 15 min
    @AppStorage("menubarBadge") var menubarBadge = "none"
    @AppStorage("coloredCommitTypes") var coloredCommitTypes = true
    @AppStorage("showOriginIcons") var showOriginIcons = true
    @AppStorage("showDiffStats") var showDiffStats = true
    @AppStorage("sortOrder") var sortOrder = "time"
    @AppStorage("exportEnabled") var exportEnabled = false
    @AppStorage("exportInterval") var exportInterval: TimeInterval = 900 // 15 min

    /// Bridged from @Environment(\.openSettings) via MenubarView.onAppear,
    /// because the AppDelegate has no access to SwiftUI scene environments.
    var openSettingsAction: (() -> Void)?

    private var timer: AnyCancellable?
    private var exportTimer: AnyCancellable?

    /// Cached aggregates, recomputed only when `projects` changes — avoids
    /// re-deduping commit hashes on every header/badge redraw (e.g. during the
    /// refresh animation).
    private(set) var totalCommits = 0
    private(set) var totalBranches = 0

    private func recomputeTotals() {
        totalCommits = projects.reduce(0) { $0 + $1.totalCommits }
        totalBranches = projects.reduce(0) { $0 + $1.branches.count }
    }

    var badgeCount: Int? {
        switch menubarBadge {
        case "projects": return projects.isEmpty ? nil : projects.count
        case "branches": return totalBranches == 0 ? nil : totalBranches
        case "commits": return totalCommits == 0 ? nil : totalCommits
        default: return nil
        }
    }

    func toggleExpansion() {
        allExpanded.toggle()
        expansionID = UUID()
    }

    init() {
        if scanPath.isEmpty {
            scanPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Sites")
                .path
        }
        Task { [weak self] in
            self?.refresh()
            self?.startAutoRefresh()
            if self?.exportEnabled == true {
                self?.enableExport()
            }
        }
    }

    func refresh() {
        guard !scanPath.isEmpty else { return }
        isLoading = true
        Task.detached { [scanPath, period] in
            let results = DevcapBridge.scan(path: scanPath, period: period, author: nil)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.projects = self.sorted(results)
                self.isLoading = false
                self.lastRefresh = Date()
            }
        }
    }

    func applySort() {
        projects = sorted(projects)
    }

    private func sorted(_ items: [ProjectLog]) -> [ProjectLog] {
        ProjectSorting.sorted(items, order: sortOrder)
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        guard refreshInterval > 0 else { return }
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stopAutoRefresh() {
        timer?.cancel()
        timer = nil
    }

    func startExportTimer() {
        stopExportTimer()
        guard exportInterval > 0 else { return }
        exportTimer = Timer.publish(every: exportInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performExport()
            }
    }

    func stopExportTimer() {
        exportTimer?.cancel()
        exportTimer = nil
    }

    func performExport() {
        guard !scanPath.isEmpty else { return }
        let interval = exportInterval
        Task.detached { [scanPath] in
            let today = DevcapBridge.scan(path: scanPath, period: "today", author: nil)
            let week = DevcapBridge.scan(path: scanPath, period: "week", author: nil)
            let payload = ExportService.buildPayload(
                today: today, week: week, ttlSeconds: Int(interval) + 60
            )
            do {
                let dir = try ExportService.applicationSupportURL()
                try ExportService.write(payload, to: dir)
            } catch {
                Self.exportLogger.error("Export write failed: \(error)")
            }
        }
    }

    func enableExport() {
        performExport()
        startExportTimer()
    }

    func disableExport() {
        stopExportTimer()
        do {
            let dir = try ExportService.applicationSupportURL()
            try ExportService.delete(from: dir)
        } catch {
            Self.exportLogger.error("Export delete failed: \(error)")
        }
    }

    nonisolated(unsafe) private static let exportLogger = Logger(subsystem: "com.konradmichalik.devcap", category: "export")
}
