import Foundation

/// What the menu bar icon reports at a glance.
enum MenubarIconState: Equatable {
    case normal
    /// No commits in the selected period.
    case empty
    case scanning
    /// Commits arrived since the popover was last opened.
    case fresh

    static func resolve(isLoading: Bool, hasProjects: Bool, hasUnseenChanges: Bool) -> MenubarIconState {
        if isLoading { return .scanning }
        if hasUnseenChanges { return .fresh }
        return hasProjects ? .normal : .empty
    }
}
