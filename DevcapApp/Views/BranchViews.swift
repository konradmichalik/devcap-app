import SwiftUI

struct BranchMenu: View {
    let branch: BranchLog

    var body: some View {
        if let url = WebURL.from(branch.url) {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open in Browser", systemImage: "globe")
            }

            Divider()
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(branch.name, forType: .string)
        } label: {
            Label("Copy Branch Name", systemImage: "doc.on.doc")
        }
    }
}

/// Stands in for the branch level when a project has only one branch.
struct BranchChip: View {
    let branch: BranchLog

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9, weight: .semibold))
            Text(branch.name)
                .font(.system(size: 10.5, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .contextMenu { BranchMenu(branch: branch) }
    }
}

struct BranchGroup: View {
    let branch: BranchLog
    let showsDays: Bool
    @State private var isExpanded: Bool

    init(branch: BranchLog, showsDays: Bool, expanded: Bool) {
        self.branch = branch
        self.showsDays = showsDays
        _isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(nil) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(branch.name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 1)
                    Text("\(branch.commits.count)")
                        .font(.caption)
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .padding(.leading, 22)
            .padding(.trailing, 14)
            .padding(.vertical, 4)
            .contextMenu { BranchMenu(branch: branch) }

            if isExpanded {
                CommitList(commits: branch.commits, showsDays: showsDays)
                    .padding(.leading, 22)
            }
        }
    }
}
