import Foundation

struct Commit: Codable, Identifiable {
    let hash: String
    let message: String
    let commitType: String?
    let timestamp: String
    let relativeTime: String

    var id: String { hash }

    var displayMessage: String {
        if let rest = message.split(separator: ":", maxSplits: 1).last {
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return message
    }

    enum CodingKeys: String, CodingKey {
        case hash, message, timestamp
        case commitType = "commit_type"
        case relativeTime = "relative_time"
    }
}

struct BranchLog: Codable, Identifiable {
    let name: String
    let commits: [Commit]

    var id: String { name }

    var latestActivity: String? {
        commits.first?.relativeTime
    }
}

struct ProjectLog: Codable, Identifiable {
    let project: String
    let path: String
    let origin: String?
    let remoteUrl: String?
    let branches: [BranchLog]

    enum CodingKeys: String, CodingKey {
        case project, path, origin, branches
        case remoteUrl = "remote_url"
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
}
