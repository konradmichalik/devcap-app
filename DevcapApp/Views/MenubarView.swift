import SwiftUI

struct MenubarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var visibleProjectIDs: Set<String> = []

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
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("devcap.app")
                    .font(.headline)
                Spacer()
                Picker("", selection: $appState.period) {
                    Text("Today").tag("today")
                    Text("Yesterday").tag("yesterday")
                    Text("This Week").tag("week")
                    Text("Last 7 Days").tag("7d")
                }
                .pickerStyle(.menu)
                .frame(width: 110)
                .onChange(of: appState.period) {
                    appState.refresh()
                }
            }
            HStack(spacing: 4) {
                if appState.isLoading && !appState.projects.isEmpty {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Refreshing...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(appState.totalCommits) commits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastRefresh = appState.lastRefresh {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text(updatedText(since: lastRefresh))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appState.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func updatedText(since date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "Updated just now" }
        if minutes == 1 { return "Updated 1 min ago" }
        return "Updated \(minutes) min ago"
    }

    // MARK: - Content

    private var projectList: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                List {
                    ForEach(appState.projects) { project in
                        ProjectSection(project: project, expanded: appState.allExpanded)
                            .listRowSeparator(.hidden)
                            .onAppear { visibleProjectIDs.insert(project.id) }
                            .onDisappear { visibleProjectIDs.remove(project.id) }
                    }
                }
                .listStyle(.inset)
                .scrollIndicators(.never)
                .id(appState.expansionID)

                if appState.projects.count > 1 {
                    ProjectScrollIndicator(
                        projects: appState.projects,
                        visibleIDs: visibleProjectIDs,
                        onJump: { id in
                            withAnimation { proxy.scrollTo(id, anchor: .top) }
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 450)
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
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No commits found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                appState.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(appState.isLoading ? 360 : 0))
                    .animation(
                        appState.isLoading
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: appState.isLoading
                    )
            }
            .buttonStyle(.borderless)
            .disabled(appState.isLoading)

            Button {
                appState.toggleExpansion()
            } label: {
                Image(systemName: appState.allExpanded
                    ? "rectangle.compress.vertical"
                    : "rectangle.expand.vertical")
            }
            .buttonStyle(.borderless)
            .help(appState.allExpanded ? "Collapse All" : "Expand All")

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Project Scroll Indicator

private struct ProjectScrollIndicator: View {
    let projects: [ProjectLog]
    let visibleIDs: Set<String>
    let onJump: (String) -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary.opacity(0.5))
                .frame(width: 1)

            VStack(spacing: 0) {
                ForEach(projects) { project in
                    Button {
                        onJump(project.id)
                    } label: {
                        Circle()
                            .fill(visibleIDs.contains(project.id) ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
                            .frame(width: visibleIDs.contains(project.id) ? 6 : 4,
                                   height: visibleIDs.contains(project.id) ? 6 : 4)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .help(project.project)
                }
            }
        }
        .frame(width: 14)
        .padding(.vertical, 4)
    }
}
