import SwiftUI

struct AboutView: View {
    @State private var updateState: UpdateCheckState = .idle

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            DevcapWordmark(size: 30, showsGlyph: false)
                .padding(.top, 4)

            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("GitHub repository") {
                    if let url = URL(string: "https://github.com/konradmichalik/devcap-app") {
                        NSWorkspace.shared.open(url)
                    }
                }
                updateCheckSection
            }
            .padding(.top, 6)

            Text("\u{00A9} 2026 Konrad Michalik")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 22)
    }

    @ViewBuilder
    private var updateCheckSection: some View {
        switch updateState {
        case .idle:
            Button("Check for Updates") {
                Task { await checkForUpdates() }
            }
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .upToDate:
            Label("You're up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available(let version, let url):
            VStack(spacing: 6) {
                Label("Version \(version) available", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.orange)
                Link("Download", destination: url)
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private func checkForUpdates() async {
        updateState = .checking

        guard let url = URL(string: "https://api.github.com/repos/konradmichalik/devcap-app/releases/latest") else {
            updateState = .error("Invalid URL")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

            if latestVersion == appVersion {
                updateState = .upToDate
            } else if let releaseURL = WebURL.from(release.htmlUrl) {
                updateState = .available(version: latestVersion, url: releaseURL)
            } else {
                updateState = .error("Could not parse release URL")
            }
        } catch {
            updateState = .error("Could not check for updates")
        }
    }
}

private enum UpdateCheckState {
    case idle
    case checking
    case upToDate
    case available(version: String, url: URL)
    case error(String)
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}
