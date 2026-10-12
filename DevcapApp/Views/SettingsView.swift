import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            DisplayTab()
                .tabItem { Label("Display", systemImage: "macwindow") }
            ExportTab()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480)
    }
}

private func abbreviated(_ path: String) -> String {
    (path as NSString).abbreviatingWithTildeInPath
}

private let refreshOptions: [(String, TimeInterval)] = [
    ("Off", 0),
    ("5 minutes", 300),
    ("15 minutes", 900),
    ("30 minutes", 1800),
]

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                LabeledContent("Scan folder") {
                    HStack(spacing: 8) {
                        Label(abbreviated(appState.scanPath), systemImage: "folder")
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { selectFolder() }
                    }
                }
            } header: {
                Text("Repositories")
            } footer: {
                Text(projectStatus)
            }

            Section {
                Picker("Auto-refresh", selection: $appState.refreshInterval) {
                    ForEach(refreshOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .onChange(of: appState.refreshInterval) {
                    appState.startAutoRefresh()
                }
            } header: {
                Text("Refresh")
            } footer: {
                Text("devcap rescans the folder in the background while it is running.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var projectStatus: String {
        appState.projects.isEmpty
            ? "No projects with commits in the selected period."
            : "\(ActivityMetrics.pluralized(appState.projects.count, "project")) with commits in the selected period."
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            appState.scanPath = url.path
            appState.refresh()
        }
    }
}

// MARK: - Display

private struct DisplayTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                AppearancePreview()
            } header: {
                Text("Preview")
            } footer: {
                Text("Updates as you change the options below. Diff numbers show when you hover a commit.")
            }

            Section("Popover") {
                Picker("Sort projects by", selection: $appState.sortOrder) {
                    Text("Latest activity").tag("time")
                    Text("Name").tag("name")
                    Text("Commit count").tag("commits")
                }
                .onChange(of: appState.sortOrder) {
                    appState.applySort()
                }

                Toggle("Colored commit types", isOn: $appState.coloredCommitTypes)
                Toggle("Provider icons", isOn: $appState.showOriginIcons)
                Toggle("Diff statistics", isOn: $appState.showDiffStats)
            }

            Section {
                Picker("Count next to icon", selection: $appState.menubarBadge) {
                    Text("None").tag("none")
                    Text("Projects").tag("projects")
                    Text("Branches").tag("branches")
                    Text("Commits").tag("commits")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Menu bar")
            } footer: {
                menubarFooter
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var menubarFooter: some View {
        if let count = appState.badgeCount {
            HStack(spacing: 4) {
                Text("Shown as")
                HStack(spacing: 3) {
                    Image(nsImage: MenubarGlyph.image(for: .normal))
                        .renderingMode(.template)
                    Text("\(count)")
                }
                .foregroundStyle(.primary)
                Text("in the menu bar.")
            }
        } else {
            Text("Only the icon is shown in the menu bar.")
        }
    }
}

/// Mirrors a project row and two commit rows so each toggle has a visible effect.
private struct AppearancePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("coloredCommitTypes") private var coloredCommitTypes = true
    @AppStorage("showOriginIcons") private var showOriginIcons = true
    @AppStorage("showDiffStats") private var showDiffStats = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(.secondary)
                if showOriginIcons {
                    Image("OriginGitHub")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.secondary)
                } else {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                }
                Text("beacon").fontWeight(.semibold)
                Spacer()
                Text("14").fontWeight(.semibold).monospacedDigit()
            }

            row(type: "feat", message: "add logo motion store", hovering: false)
            row(type: "fix", message: "keep filter after refresh", hovering: true)
        }
        .font(.system(size: 12.5))
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of a project with two commits")
    }

    private func row(type: String, message: String, hovering: Bool) -> some View {
        let tint = coloredCommitTypes ? CommitTypeStyle.color(type, scheme: colorScheme) : Color.secondary
        return HStack(spacing: 8) {
            Text(type)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(minWidth: 56, alignment: .leading)
            Text(message)
            Spacer()
            if hovering, showDiffStats {
                DiffStatLabel(stat: DiffStat(filesChanged: 2, insertions: 145, deletions: 2))
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(hovering ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Export

private struct ExportTab: View {
    @EnvironmentObject var appState: AppState

    private var exportIntervalOptions: [(String, TimeInterval)] {
        Array(refreshOptions.dropFirst())
    }

    private var exportFileURL: URL? {
        try? ExportService.locationURL().appendingPathComponent(ExportService.fileName)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Export data", isOn: $appState.exportEnabled)
                    .onChange(of: appState.exportEnabled) {
                        appState.exportEnabled ? appState.enableExport() : appState.disableExport()
                    }

                Picker("Refresh interval", selection: $appState.exportInterval) {
                    ForEach(exportIntervalOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .disabled(!appState.exportEnabled)
                .onChange(of: appState.exportInterval) {
                    guard appState.exportEnabled else { return }
                    appState.performExport()
                    appState.startExportTimer()
                }

                LabeledContent("File") {
                    Button("Reveal") { reveal() }
                        .disabled(!appState.exportEnabled)
                }

                Text(exportFileURL.map { abbreviated($0.path) } ?? "–")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("Data for other apps")
            } footer: {
                Text("A small JSON file with today's and this week's commit counts and the most active project. Only you can read it.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func reveal() {
        guard let file = exportFileURL else { return }
        if FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            NSWorkspace.shared.open(file.deletingLastPathComponent())
        }
    }
}
