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
        case oneMonth = 2_592_000
        case threeMonths = 7_776_000
        case sixMonths = 15_552_000
        case twelveMonths = 31_536_000
        case forever = 0

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .oneHour: return String(localized: "1 hour")
            case .sixHours: return String(localized: "6 hours")
            case .oneDay: return String(localized: "1 day")
            case .threeDays: return String(localized: "3 days")
            case .oneWeek: return String(localized: "1 week")
            case .oneMonth: return String(localized: "1 month")
            case .threeMonths: return String(localized: "3 months")
            case .sixMonths: return String(localized: "6 months")
            case .twelveMonths: return String(localized: "12 months")
            case .forever: return String(localized: "Never expire")
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
        static let defaultGuestRangeDays = "settings.defaultGuestRangeDays"
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

    @Published var defaultGuestRangeDays: Int {
        didSet { defaults.set(defaultGuestRangeDays, forKey: Keys.defaultGuestRangeDays) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTTL = defaults.object(forKey: Keys.cacheTTL) as? Int
        cacheTTL = storedTTL.flatMap(CacheTTL.init(rawValue:)) ?? .oneWeek
        saveImages = defaults.object(forKey: Keys.saveImages) as? Bool ?? true
        autoReauth = defaults.object(forKey: Keys.autoReauth) as? Bool ?? false
        rememberCredentials = defaults.object(forKey: Keys.rememberCredentials) as? Bool ?? false
        let storedRange = defaults.object(forKey: Keys.defaultGuestRangeDays) as? Int
        defaultGuestRangeDays = [7, 15, 30, 60, 90, 180, 365].contains(storedRange ?? 90) ? (storedRange ?? 90) : 90
    }
}
