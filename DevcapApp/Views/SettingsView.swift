import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    private let refreshOptions: [(String, TimeInterval)] = [
        ("Off", 0),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800),
    ]

    private var exportIntervalOptions: [(String, TimeInterval)] {
        Array(refreshOptions.dropFirst())
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 60)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .about:
                    AboutView()
                }
            }
            .frame(height: selectedTab == .general ? 540 : 300)
        }
        .frame(width: 400)
    }

    private var generalTab: some View {
        Form {
            Section("Scan Path") {
                HStack {
                    TextField("Path to scan", text: $appState.scanPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        selectFolder()
                    }
                }
            }

            Section("General") {
                Picker("Auto-refresh", selection: $appState.refreshInterval) {
                    ForEach(refreshOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .onChange(of: appState.refreshInterval) {
                    appState.startAutoRefresh()
                }

                Picker("Sort projects by", selection: $appState.sortOrder) {
                    Text("Latest activity").tag("time")
                    Text("Name").tag("name")
                    Text("Commit count").tag("commits")
                }
                .onChange(of: appState.sortOrder) {
                    appState.applySort()
                }

                Picker("Menubar count", selection: $appState.menubarBadge) {
                    Text("None").tag("none")
                    Text("Projects").tag("projects")
                    Text("Branches").tag("branches")
                    Text("Commits").tag("commits")
                }
            }

            Section("Appearance") {
                Toggle("Colored commit types", isOn: $appState.coloredCommitTypes)
                Toggle("Show provider icons", isOn: $appState.showOriginIcons)
                Toggle("Show diff stats", isOn: $appState.showDiffStats)
            }

            Section("Export") {
                Toggle("Export data for external apps", isOn: $appState.exportEnabled)
                    .onChange(of: appState.exportEnabled) {
                        appState.exportEnabled ? appState.enableExport() : appState.disableExport()
                    }

                Picker("Export refresh interval", selection: $appState.exportInterval) {
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
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
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

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .about: "About"
        }
    }
}
