import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultDelayMs = 1_000
    static let minDelayMs = 300
    static let maxDelayMs = 5_000

    private enum Keys {
        static let delayMs = "io.github.manas.SlowQ.delayMs"
        static let isProtectionEnabled = "io.github.manas.SlowQ.isProtectionEnabled"
        static let launchAtLogin = "io.github.manas.SlowQ.launchAtLogin"
    }

    private let defaults: UserDefaults

    @Published var delayMs: Int {
        didSet {
            let clamped = Self.clampDelay(delayMs)
            if clamped != delayMs {
                delayMs = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.delayMs)
        }
    }

    @Published var isProtectionEnabled: Bool {
        didSet {
            defaults.set(isProtectionEnabled, forKey: Keys.isProtectionEnabled)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.delayMs: Self.defaultDelayMs,
            Keys.isProtectionEnabled: true,
            Keys.launchAtLogin: false,
        ])

        let persistedDelay = defaults.integer(forKey: Keys.delayMs)
        let clampedDelay = Self.clampDelay(persistedDelay)
        self.delayMs = clampedDelay
        self.isProtectionEnabled = defaults.bool(forKey: Keys.isProtectionEnabled)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        if persistedDelay != clampedDelay {
            defaults.set(clampedDelay, forKey: Keys.delayMs)
        }
    }

    static func clampDelay(_ value: Int) -> Int {
        min(max(value, minDelayMs), maxDelayMs)
    }
}
