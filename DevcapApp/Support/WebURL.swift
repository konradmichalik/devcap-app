import Foundation

/// Parses a string into a URL only when it is an `http`/`https` web address.
///
/// Remote/branch/commit URLs come from git config and the GitHub API — untrusted
/// input. Opening non-web schemes (`file://`, custom app schemes) via
/// `NSWorkspace` could trigger unexpected handlers, so everything else is rejected.
enum WebURL {
    static func from(_ string: String?) -> URL? {
        guard let string,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}
