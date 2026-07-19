import Foundation

/// Every error surfaced by the portal client.
enum PortalError: LocalizedError {
    /// The portal answered with the `{ "message": "REDIRECT" }` sentinel, or a 302 to login.
    case sessionExpired
    /// Login POST re-rendered the login page instead of redirecting: bad credentials.
    case invalidCredentials
    /// The anti-forgery token could not be found in the page HTML.
    case antiForgeryMissing
    /// The pinned certificate is not bundled, so the client refuses to connect (fail closed).
    case certificateNotBundled
    /// Any non-success, non-redirect HTTP status.
    case http(Int)
    /// Transport failure — most often the portal being unreachable from outside Cuba.
    case unreachable

    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "Session expired. Please sign in again."
        case .invalidCredentials:
            return "Invalid username or password."
        case .antiForgeryMissing:
            return "Anti-forgery token not found in page HTML."
        case .certificateNotBundled:
            return "Pinned certificate not bundled. Add casero_rem_cu.cer to the app resources — see CLAUDE.md."
        case .http(let code):
            return "Portal returned HTTP \(code)."
        case .unreachable:
            return "Could not reach the portal (only reachable from inside Cuba)."
        }
    }
}
