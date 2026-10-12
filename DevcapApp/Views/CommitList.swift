import SwiftUI

extension View {
    func hoverHighlight(_ isHovering: Bool, cornerRadius: CGFloat = 6) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.07 : 0))
        )
    }
}

struct DiffStatLabel: View {
    let stat: DiffStat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text("+\(ActivityMetrics.compactCount(stat.insertions))")
                .foregroundStyle(CommitTypeStyle.green(colorScheme))
            Text("\u{2212}\(ActivityMetrics.compactCount(stat.deletions))")
                .foregroundStyle(CommitTypeStyle.red(colorScheme))
        }
        .font(.system(size: 11, design: .monospaced))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.insertions) added, \(stat.deletions) removed")
    }
}

struct CommitList: View {
    let commits: [Commit]
    /// Decided per project, so every branch of a project is grouped the same way.
    let showsDays: Bool

    var body: some View {
        let groups = showsDays
            ? ActivityMetrics.dayGroups(commits, now: Date(), calendar: .current)
            : [DayGroup(label: "", commits: commits)]

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                if showsDays {
                    Text(group.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .padding(.leading, 6)
                }
                ForEach(group.commits) { commit in
                    CommitRow(commit: commit, showsTime: !showsDays)
                }
            }
        }
    }
}

private struct CommitRow: View {
    let commit: Commit
    let showsTime: Bool
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("coloredCommitTypes") private var coloredCommitTypes = true
    @AppStorage("showDiffStats") private var showDiffStats = true

    var body: some View {
        HStack(spacing: 8) {
            if let type = commit.commitType {
                typeBadge(type)
            }

            Text(commit.displayMessage)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(commit.message)

            Spacer(minLength: 4)

            if showsTime {
                Text(shortTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .overlay(alignment: .trailing) {
            if isHovering, showDiffStats, let stat = commit.diffStat {
                DiffStatLabel(stat: stat)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Color(nsColor: .windowBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12))
                    )
                    .padding(.trailing, 6)
                    .help(filesHelp(stat))
            }
        }
        .hoverHighlight(isHovering)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
        .contextMenu {
            if let url = WebURL.from(commit.url) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open in Browser", systemImage: "globe")
                }

                Divider()
            }

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

    private var shortTime: String {
        commit.relativeTime.replacingOccurrences(of: " ago", with: "")
    }

    private func typeBadge(_ type: String) -> some View {
        let tint = coloredCommitTypes ? CommitTypeStyle.color(type, scheme: colorScheme) : Color.secondary
        return Text(type)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(tint)
            .frame(minWidth: 56, alignment: .leading)
    }

    private func filesHelp(_ stat: DiffStat) -> String {
        "\(ActivityMetrics.pluralized(stat.filesChanged, "file")) changed"
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

enum CommitTypeStyle {
    static func green(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .green : Color(red: 0.09, green: 0.42, blue: 0.19)
    }

    static func red(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .red : Color(red: 0.71, green: 0.14, blue: 0.12)
    }

    /// Light mode needs darker shades than the system colors to stay readable
    /// on the tinted badge background.
    static func color(_ type: String, scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch type {
        case "feat": return green(scheme)
        case "fix": return red(scheme)
        case "refactor": return dark ? .cyan : Color(red: 0.04, green: 0.39, blue: 0.47)
        case "docs": return dark ? .blue : Color(red: 0.12, green: 0.37, blue: 0.75)
        case "test": return dark ? .orange : Color(red: 0.54, green: 0.29, blue: 0.03)
        case "style": return dark ? .purple : Color(red: 0.42, green: 0.25, blue: 0.63)
        case "chore", "ci", "perf", "build": return .secondary
        default: return .primary
        }
    }
}
