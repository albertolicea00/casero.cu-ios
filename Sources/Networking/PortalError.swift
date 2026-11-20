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
    case rejected(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .rejected(let message):
            return message
        case .invalidResponse:
            return String(
                localized: "The portal returned an unexpected response. Please try again or use the official portal.")
        case .sessionExpired:
            return String(localized: "Session expired. Please sign in again.")
        case .invalidCredentials:
            return String(localized: "Invalid username or password.")
        case .antiForgeryMissing:
            return String(localized: "Could not validate the portal form. Please try again.")
        case .certificateNotBundled:
            return String(localized: "The portal security certificate is missing from this installation.")
        case .http(let code):
            return String(localized: "Portal returned HTTP \(code).")
        case .unreachable:
            return String(localized: "Could not reach the portal (only reachable from inside Cuba).")
        }
    }
}
