import Foundation
import Testing

@testable import SlowQ

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {
    private var delayKey: String { "io.github.manas.SlowQ.delayMs" }

    @Test("delay clamps into supported range")
    func delayClamp() {
        #expect(SettingsStore.clampDelay(-1) == SettingsStore.minDelayMs)
        #expect(SettingsStore.clampDelay(9_999) == SettingsStore.maxDelayMs)
        #expect(SettingsStore.clampDelay(1_000) == 1_000)
    }

    @Test("initialization corrects invalid persisted delay")
    func initializationClampsPersistedValue() {
        let suiteName = "io.github.manas.SlowQ.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(-50, forKey: "io.github.manas.SlowQ.delayMs")

        let settings = SettingsStore(defaults: defaults)
        #expect(settings.delayMs == SettingsStore.minDelayMs)
    }

    @Test("setting out-of-range delay clamps and persists")
    func assignmentClampsAndPersists() {
        let suiteName = "io.github.manas.SlowQ.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = SettingsStore(defaults: defaults)
        settings.delayMs = 99_999

        #expect(settings.delayMs == SettingsStore.maxDelayMs)
        #expect(defaults.integer(forKey: delayKey) == SettingsStore.maxDelayMs)
    }
}
