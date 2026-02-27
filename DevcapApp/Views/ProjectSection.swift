import SwiftUI

// MARK: - Project

struct ProjectSection: View {
    let project: ProjectLog
    private let defaultExpanded: Bool
    @State private var isExpanded: Bool
    @AppStorage("showOriginIcons") private var showOriginIcons = true

    init(project: ProjectLog, expanded: Bool = true) {
        self.project = project
        self.defaultExpanded = expanded
        _isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(project.branches, id: \.name) { branch in
                BranchSection(branch: branch, idPrefix: project.path, expanded: defaultExpanded)
            }
        } label: {
            Label {
                HStack {
                    Text(project.project)
                        .fontWeight(.semibold)
                    if showOriginIcons, let origin = project.origin,
                       origin != "github", origin != "gitlab", origin != "gitlab-self-hosted",
                       origin != "bitbucket" {
                        Text(originDisplayName(origin))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("\(project.totalCommits)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .font(.callout)
                }
            } icon: {
                if showOriginIcons {
                    originIcon
                } else {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .contextMenu {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                } label: {
                    Label("Open in Finder", systemImage: "folder")
                }

                Button {
                    let script = "tell application \"Terminal\" to do script \"cd \(project.path.replacing("\"", with: "\\\""))\""
                    if let appleScript = NSAppleScript(source: script) {
                        appleScript.executeAndReturnError(nil)
                    }
                } label: {
                    Label("Open in Terminal", systemImage: "terminal")
                }

                if let remoteUrl = project.remoteUrl,
                   let url = URL(string: remoteUrl) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open in Browser", systemImage: "globe")
                    }
                }

                Divider()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(project.path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
            }
        }
    }

    @ViewBuilder
    private var originIcon: some View {
        switch project.origin {
        case "github":
            Image("OriginGitHub")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        case "gitlab", "gitlab-self-hosted":
            Image("OriginGitLab")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        case "bitbucket":
            Image("OriginBitbucket")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        default:
            Image(systemName: project.origin != nil ? "globe" : "folder.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func originDisplayName(_ origin: String) -> String {
        switch origin {
        case "github": "GitHub"
        case "gitlab": "GitLab"
        case "bitbucket": "Bitbucket"
        case "gitlab-self-hosted": "GitLab"
        default: origin
        }
    }

}

// MARK: - Branch

private struct BranchSection: View {
    let branch: BranchLog
    let idPrefix: String
    @State private var isExpanded: Bool

    init(branch: BranchLog, idPrefix: String, expanded: Bool = true) {
        self.branch = branch
        self.idPrefix = idPrefix
        _isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(branch.commits, id: \.hash) { commit in
                CommitRow(commit: commit)
                    .id("\(idPrefix)/\(branch.name)/\(commit.hash)")
            }
        } label: {
            Label {
                HStack {
                    Text(branch.name)
                    Spacer()
                    Text("\(branch.commits.count)")
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .font(.caption)
                }
            } icon: {
                Image(systemName: "arrow.triangle.branch")
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .contextMenu {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(branch.name, forType: .string)
                } label: {
                    Label("Copy Branch Name", systemImage: "doc.on.doc")
                }
            }
        }
        .id("\(idPrefix)/\(branch.name)")
    }
}

// MARK: - Commit

private struct CommitRow: View {
    let commit: Commit
    @AppStorage("coloredCommitTypes") private var coloredCommitTypes = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let type = commit.commitType {
                Text(type)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(coloredCommitTypes ? colorForType(type) : .secondary)
            }

            Text(commit.displayMessage)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(commit.message)

            Spacer()

            Text(commit.relativeTime)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contextMenu {
            Button {
                copyToClipboard(commit.hash)
            } label: {
                Label("Copy Hash (\(String(commit.hash.prefix(7))))", systemImage: "doc.on.doc")
            }

            Button {
                copyToClipboard(commit.message)
            } label: {
                Label("Copy Message", systemImage: "text.quote")
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "feat": .green
        case "fix": .red
        case "refactor": .cyan
        case "docs": .blue
        case "test": .orange
        case "style": .purple
        case "chore", "ci", "perf", "build": .secondary
        default: .primary
        }
    }
}
