import SwiftUI
import Combine

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

    /// Bridged from @Environment(\.openSettings) via MenubarView.onAppear,
    /// because the AppDelegate has no access to SwiftUI scene environments.
    var openSettingsAction: (() -> Void)?

    private var timer: AnyCancellable?

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
}
