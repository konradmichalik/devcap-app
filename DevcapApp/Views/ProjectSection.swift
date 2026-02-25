import SwiftUI

// MARK: - Project

struct ProjectSection: View {
    let project: ProjectLog
    private let defaultExpanded: Bool
    @State private var isExpanded: Bool

    init(project: ProjectLog, expanded: Bool = true) {
        self.project = project
        self.defaultExpanded = expanded
        _isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(project.branches) { branch in
                BranchSection(branch: branch, expanded: defaultExpanded)
            }
        } label: {
            Label {
                HStack {
                    Text(project.project)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(project.totalCommits)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .font(.callout)
                }
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Branch

private struct BranchSection: View {
    let branch: BranchLog
    @State private var isExpanded: Bool

    init(branch: BranchLog, expanded: Bool = true) {
        self.branch = branch
        _isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(branch.commits) { commit in
                CommitRow(commit: commit)
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
        }
    }
}

// MARK: - Commit

private struct CommitRow: View {
    let commit: Commit

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let type = commit.commitType {
                Text(type)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(colorForType(type))
            }

            Text(commit.displayMessage)
                .font(.callout)
                .lineLimit(2)

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
