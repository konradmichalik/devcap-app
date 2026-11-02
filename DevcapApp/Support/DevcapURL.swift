import Foundation

/// Inbound URLs come from arbitrary processes, so only an exact `devcap://show` is accepted.
enum DevcapURL {
    static func isShow(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "devcap"
            && url.host?.lowercased() == "show"
            && (url.path.isEmpty || url.path == "/")
            && url.query == nil
            && url.fragment == nil
    }
}
