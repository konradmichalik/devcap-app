import Foundation

struct DiffStat: Codable {
    let filesChanged: Int
    let insertions: Int
    let deletions: Int

    enum CodingKeys: String, CodingKey {
        case filesChanged = "files_changed"
        case insertions, deletions
    }
}

struct Commit: Codable, Identifiable {
    let hash: String
    let message: String
    let commitType: String?
    /// Author date: when the work was written. Drives every display value.
    let timestamp: String
    /// Committer date: when the commit entered history. This is what the scan's
    /// period filter selects on, so it is the only field that can narrow a
    /// result set the same way a dedicated scan would.
    let committerTimestamp: String
    let relativeTime: String
    let url: String?
    let diffStat: DiffStat?

    var id: String { hash }

    var displayMessage: String {
        if let rest = message.split(separator: ":", maxSplits: 1).last {
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return message
    }

    enum CodingKeys: String, CodingKey {
        case hash, message, timestamp, url
        case commitType = "commit_type"
        case committerTimestamp = "committer_timestamp"
        case relativeTime = "relative_time"
        case diffStat = "diff_stat"
    }
}

struct BranchLog: Codable, Identifiable {
    let name: String
    let url: String?
    let commits: [Commit]
    let diffStat: DiffStat?

    var id: String { name }

    var latestActivity: String? {
        commits.first?.relativeTime
    }

    enum CodingKeys: String, CodingKey {
        case name, url, commits
        case diffStat = "diff_stat"
    }
}

struct ProjectLog: Codable, Identifiable {
    let project: String
    let path: String
    let origin: String?
    let remoteUrl: String?
    let branches: [BranchLog]
    let diffStat: DiffStat?

    enum CodingKeys: String, CodingKey {
        case project, path, origin, branches
        case remoteUrl = "remote_url"
        case diffStat = "diff_stat"
    }

    var id: String { path }

    var totalCommits: Int {
        var seen = Set<String>()
        return branches
            .flatMap(\.commits)
            .filter { seen.insert($0.hash).inserted }
            .count
    }

    var latestActivity: String? {
        branches
            .flatMap(\.commits)
            .first?
            .relativeTime
    }

    var latestTimestamp: String? {
        branches
            .flatMap(\.commits)
            .map(\.timestamp)
            .max()
    }
}
