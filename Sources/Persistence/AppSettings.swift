import Foundation

/// User-facing preferences, backed by `UserDefaults`. Everything here is local
/// device configuration — never portal data.
@MainActor
final class AppSettings: ObservableObject {

    enum CacheTTL: Int, CaseIterable, Identifiable {
        case oneHour = 3600
        case sixHours = 21600
        case oneDay = 86400
        case threeDays = 259200
        case oneWeek = 604800
        case forever = 0

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .oneHour: return "1 hour"
            case .sixHours: return "6 hours"
            case .oneDay: return "1 day"
            case .threeDays: return "3 days"
            case .oneWeek: return "1 week"
            case .forever: return "Never expire"
            }
        }

        /// `nil` means "forever" (never considered stale).
        var interval: TimeInterval? {
            self == .forever ? nil : TimeInterval(rawValue)
        }
    }

    private enum Keys {
        static let cacheTTL = "settings.cacheTTL"
        static let saveImages = "settings.saveImages"
        static let autoReauth = "settings.autoReauth"
        static let rememberCredentials = "settings.rememberCredentials"
    }

    private let defaults: UserDefaults

    @Published var cacheTTL: CacheTTL {
        didSet { defaults.set(cacheTTL.rawValue, forKey: Keys.cacheTTL) }
    }

    /// When `false`, guest photos are never written to the on-disk cache.
    @Published var saveImages: Bool {
        didSet { defaults.set(saveImages, forKey: Keys.saveImages) }
    }

    /// When `true`, an expired session is retried silently using the Keychain
    /// password before falling back to the "session lost, tap to sign in" banner.
    @Published var autoReauth: Bool {
        didSet { defaults.set(autoReauth, forKey: Keys.autoReauth) }
    }

    @Published var rememberCredentials: Bool {
        didSet {
            defaults.set(rememberCredentials, forKey: Keys.rememberCredentials)
            if !rememberCredentials { KeychainStore.clearAll() }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTTL = defaults.object(forKey: Keys.cacheTTL) as? Int
        cacheTTL = storedTTL.flatMap(CacheTTL.init(rawValue:)) ?? .oneDay
        saveImages = defaults.object(forKey: Keys.saveImages) as? Bool ?? true
        autoReauth = defaults.object(forKey: Keys.autoReauth) as? Bool ?? false
        rememberCredentials = defaults.object(forKey: Keys.rememberCredentials) as? Bool ?? false
    }
}
