import SwiftUI

struct MenubarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

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
                        Text("Updated \(Int(Date().timeIntervalSince(lastRefresh) / 60)) min ago")
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

    // MARK: - Content

    private var projectList: some View {
        List {
            ForEach(appState.projects) { project in
                ProjectSection(project: project, expanded: appState.allExpanded)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.inset)
        .scrollIndicators(.never)
        .id(appState.expansionID)
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
