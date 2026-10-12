import SwiftUI

struct ProjectSection: View {
    let project: ProjectLog
    let isFresh: Bool
    private let defaultExpanded: Bool
    @State private var isExpanded: Bool
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("showOriginIcons") private var showOriginIcons = true
    @AppStorage("showDiffStats") private var showDiffStats = true

    init(project: ProjectLog, isFresh: Bool, expanded: Bool = true) {
        self.project = project
        self.isFresh = isFresh
        self.defaultExpanded = expanded
        _isExpanded = State(initialValue: expanded)
    }

    private var singleBranch: BranchLog? {
        project.branches.count == 1 ? project.branches.first : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                expandedContent
            }
        }
        .padding(.vertical, isExpanded ? 2 : 0)
        .background {
            if isExpanded {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .padding(.horizontal, isExpanded ? 6 : 0)
        .padding(.vertical, isExpanded ? 2 : 0)
    }

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(nil) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isExpanded)
                    .frame(width: 12)

                originIcon
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 4) {
                    titleRow
                    if !isExpanded, let latest = project.latestActivity {
                        Text("Last commit \(latest)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if showDiffStats, !isExpanded, let stat = project.diffStat {
                    DiffStatLabel(stat: stat)
                        .frame(width: 84, alignment: .trailing)
                }

                Text("\(project.totalCommits)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .default, value: project.totalCommits)
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .padding(.leading, isExpanded ? 4 : 10)
            .padding(.trailing, isExpanded ? 8 : 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(isHovering && !isExpanded, cornerRadius: 0)
        .onHover { isHovering = $0 && !isExpanded }
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .contextMenu { projectMenu }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(project.project)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .layoutPriority(1)

            if isFresh {
                Circle()
                    .fill(Color.brandMint)
                    .frame(width: 6, height: 6)
                    .help("New commits since the last refresh")
                    .accessibilityLabel("New commits")
            }

            if showOriginIcons, let origin = project.origin, !Self.knownHosts.contains(origin) {
                Text(originDisplayName(origin))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isExpanded, let branch = singleBranch {
                BranchChip(branch: branch)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var expandedContent: some View {
        let showsDays = ActivityMetrics
            .dayGroups(project.branches.flatMap(\.commits), now: Date(), calendar: .current)
            .count > 1

        if let branch = singleBranch {
            CommitList(commits: branch.commits, showsDays: showsDays)
                .padding(.leading, 22)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(project.branches, id: \.name) { branch in
                    BranchGroup(branch: branch, showsDays: showsDays, expanded: defaultExpanded)
                }
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var projectMenu: some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
        } label: {
            Label("Open in Finder", systemImage: "folder")
        }

        Button {
            TerminalLauncher.open(path: project.path)
        } label: {
            Label("Open in Terminal", systemImage: "terminal")
        }

        if let url = WebURL.from(project.remoteUrl) {
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

    // MARK: - Origin

    private static let knownHosts: Set<String> = ["github", "gitlab", "gitlab-self-hosted", "bitbucket"]

    @ViewBuilder
    private var originIcon: some View {
        if showOriginIcons {
            switch project.origin {
            case "github":
                providerImage("OriginGitHub")
            case "gitlab", "gitlab-self-hosted":
                providerImage("OriginGitLab")
            case "bitbucket":
                providerImage("OriginBitbucket")
            default:
                Image(systemName: project.origin != nil ? "globe" : "folder.fill")
                    .foregroundStyle(.secondary)
            }
        } else {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func providerImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
            .foregroundStyle(Color.secondary)
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
