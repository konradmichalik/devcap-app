import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WindowHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MenubarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var listContentHeight: CGFloat = 200
    @State private var windowContentHeight: CGFloat = 0

    private static let maxListHeight: CGFloat = 480
    private static let periodPhrases = [
        "today": "today",
        "yesterday": "yesterday",
        "week": "this week",
        "7d": "in the last 7 days",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if appState.isLoading && appState.projects.isEmpty {
                loadingView
            } else if appState.projects.isEmpty {
                emptyView
            } else {
                projectList
            }

            Divider()
            footer
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: WindowHeightKey.self, value: geo.size.height)
            }
        )
        .background(WindowSizer(contentHeight: windowContentHeight))
        .onPreferenceChange(WindowHeightKey.self) { windowContentHeight = $0 }
        .background(WindowVisibilityObserver { isVisible in
            isVisible ? appState.popoverDidAppear() : appState.popoverDidDisappear()
        })
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DevcapWordmark()
                Spacer()
                statusLine
            }

            PeriodPicker(selection: $appState.period)
                .onChange(of: appState.period) {
                    appState.refresh()
                }

            HStack(alignment: .bottom) {
                summaryLine
                Spacer()
                if appState.activity.count > 1 {
                    ActivitySparkline(activity: appState.activity)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var summaryLine: some View {
        let commits = appState.totalCommits
        let projects = appState.projects.count
        return HStack(spacing: 4) {
            Text(ActivityMetrics.pluralized(commits, "commit"))
                .fontWeight(.semibold)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .default, value: commits)
            Text("in \(ActivityMetrics.pluralized(projects, "project"))")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }

    /// Fixed height, so toggling between "Refreshing" and "Updated" never changes
    /// the header and with it the window.
    private var statusLine: some View {
        HStack(spacing: 4) {
            if appState.isLoading && !appState.projects.isEmpty {
                ProgressView()
                    .controlSize(.mini)
                Text("Refreshing...")
            } else if let lastRefresh = appState.lastRefresh {
                Text(updatedText(since: lastRefresh))
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(height: 16)
    }

    private func updatedText(since date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "Updated just now" }
        if minutes == 1 { return "Updated 1 min ago" }
        return "Updated \(minutes) min ago"
    }

    // MARK: - Content

    private var projectList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(appState.projects) { project in
                    ProjectSection(
                        project: project,
                        isFresh: appState.freshProjectIDs.contains(project.id),
                        expanded: appState.allExpanded
                    )
                }

                if let phrase = nudgePhrase {
                    nudge(phrase)
                }
            }
            .padding(.vertical, 6)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                }
            )
        }
        .scrollIndicators(.never)
        .id(appState.expansionID)
        .onPreferenceChange(ContentHeightKey.self) { height in
            listContentHeight = min(max(height, 80), Self.maxListHeight)
        }
        .frame(height: listContentHeight)
    }

    /// A short list for a single-day period usually means the day is young, so
    /// point to the wider view instead of leaving the popover looking broken.
    private var nudgePhrase: String? {
        guard appState.projects.count <= 3, appState.totalCommits <= 10,
              appState.period == "today" || appState.period == "yesterday" else { return nil }
        return Self.periodPhrases[appState.period]
    }

    private func nudge(_ phrase: String) -> some View {
        HStack(spacing: 6) {
            Text("That is all for \(phrase).")
                .foregroundStyle(.secondary)
            Button("Show last 7 days") {
                appState.period = "7d"
            }
            .buttonStyle(.link)
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("Scanning repositories...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 80)
    }

    private var emptyView: some View {
        let phrase = Self.periodPhrases[appState.period] ?? "in this period"
        let path = (appState.scanPath as NSString).abbreviatingWithTildeInPath

        return VStack(spacing: 4) {
            DevcapGlyph(
                size: 44,
                tint: Color.secondary.opacity(0.7),
                accent: Color.brandMint.opacity(0.35)
            )
            Text("No commits \(phrase)")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 8)
            Text("Nothing committed in the repositories under \(path).")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if appState.period == "7d" {
                Button("Open Settings") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .padding(.top, 12)
            } else {
                Button("Show last 7 days") {
                    appState.period = "7d"
                }
                .padding(.top, 12)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 40)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 2) {
            footerButton("Refresh", disabled: appState.isLoading) {
                appState.refresh()
            } icon: {
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }

            if !appState.projects.isEmpty {
                footerButton(appState.allExpanded ? "Collapse All" : "Expand All") {
                    appState.toggleExpansion()
                } icon: {
                    Image(systemName: appState.allExpanded
                        ? "rectangle.compress.vertical"
                        : "rectangle.expand.vertical")
                }
            }

            Spacer()

            footerButton("Settings") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } icon: {
                Image(systemName: "gear")
            }

            footerButton("Quit devcap") {
                NSApplication.shared.terminate(nil)
            } icon: {
                Image(systemName: "power")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func footerButton<Icon: View>(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .help(title)
        .accessibilityLabel(title)
    }
}
