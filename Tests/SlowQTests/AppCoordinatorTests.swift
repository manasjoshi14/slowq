import Foundation
import Testing

@testable import SlowQ

private final class MockPermissionService: PermissionServicing {
    var preflightResult: Bool
    var requestResult: Bool
    var requestCalls = 0

    init(preflightResult: Bool, requestResult: Bool) {
        self.preflightResult = preflightResult
        self.requestResult = requestResult
    }

    func preflightListenPermission() -> Bool {
        preflightResult
    }

    func requestListenPermission() -> Bool {
        requestCalls += 1
        return requestResult
    }

    func isAccessibilityTrusted() -> Bool {
        preflightResult
    }
}

private enum MockLaunchError: Error {
    case failed
}

private final class MockLaunchAtLoginService: LaunchAtLoginControlling {
    var isEnabled: Bool
    var setEnabledCalls: [Bool] = []
    var errorToThrow: Error?

    init(isEnabled: Bool, errorToThrow: Error? = nil) {
        self.isEnabled = isEnabled
        self.errorToThrow = errorToThrow
    }

    func setEnabled(_ enabled: Bool) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        setEnabledCalls.append(enabled)
        isEnabled = enabled
    }
}

private final class MockInterceptionService: QuitInterceptionControlling {
    var startResult: Bool
    var startCalls = 0
    var stopCalls = 0

    var isRunning: Bool {
        startCalls > stopCalls
    }

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func start() -> Bool {
        startCalls += 1
        return startResult
    }

    func stop() {
        stopCalls += 1
    }
}

private final class MockOverlayController: OverlayPresenting {
    func show(appName: String, duration: TimeInterval) {}
    func update(progress: Double) {}
    func hideAndReset() {}
}

@MainActor
private func makeSettings(
    delayMs: Int = SettingsStore.defaultDelayMs,
    isProtectionEnabled: Bool = true,
    launchAtLogin: Bool = false
) -> SettingsStore {
    let suiteName = "io.github.manas.SlowQ.tests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create isolated defaults suite")
    }

    defaults.set(delayMs, forKey: "io.github.manas.SlowQ.delayMs")
    defaults.set(isProtectionEnabled, forKey: "io.github.manas.SlowQ.isProtectionEnabled")
    defaults.set(launchAtLogin, forKey: "io.github.manas.SlowQ.launchAtLogin")

    return SettingsStore(defaults: defaults)
}

@MainActor
@Suite("AppCoordinator")
struct AppCoordinatorTests {
    @Test("starts interception when permission is granted")
    func startsInterceptionWithPermission() {
        let settings = makeSettings(isProtectionEnabled: true)
        let permission = MockPermissionService(preflightResult: true, requestResult: true)
        let launch = MockLaunchAtLoginService(isEnabled: false)
        let interception = MockInterceptionService(startResult: true)

        let coordinator = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            interceptionFactory: { _, _, _ in interception }
        )

        #expect(permission.requestCalls == 0)
        #expect(interception.startCalls == 1)
        #expect(interception.stopCalls == 0)
        #expect(coordinator.isInterceptionRunning)
        #expect(coordinator.lastError == nil)
    }

    @Test("reports permission error when interception cannot start without permission")
    func deniedPermissionReportsPermissionError() {
        let settings = makeSettings(isProtectionEnabled: true)
        let permission = MockPermissionService(preflightResult: false, requestResult: false)
        let launch = MockLaunchAtLoginService(isEnabled: false)
        let interception = MockInterceptionService(startResult: false)

        let coordinator = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            interceptionFactory: { _, _, _ in interception }
        )

        #expect(permission.requestCalls == 0)
        #expect(interception.startCalls == 1)
        #expect(interception.stopCalls == 1)
        #expect(!coordinator.isInterceptionRunning)
        #expect(coordinator.lastError?.contains("Input Monitoring permission") == true)
    }

    @Test("launch-at-login sync is skipped when already matching")
    func launchAtLoginNoopWhenMatching() {
        let settings = makeSettings(launchAtLogin: false)
        let permission = MockPermissionService(preflightResult: true, requestResult: true)
        let launch = MockLaunchAtLoginService(isEnabled: false)
        let interception = MockInterceptionService(startResult: true)

        _ = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            interceptionFactory: { _, _, _ in interception }
        )

        #expect(launch.setEnabledCalls.isEmpty)
    }

    @Test("launch-at-login sync happens when state mismatches")
    func launchAtLoginSyncWhenMismatched() {
        let settings = makeSettings(launchAtLogin: true)
        let permission = MockPermissionService(preflightResult: true, requestResult: true)
        let launch = MockLaunchAtLoginService(isEnabled: false)
        let interception = MockInterceptionService(startResult: true)

        _ = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            interceptionFactory: { _, _, _ in interception }
        )

        #expect(launch.setEnabledCalls == [true])
    }

    @Test("launch-at-login errors are surfaced")
    func launchAtLoginErrorsReported() {
        let settings = makeSettings(launchAtLogin: true)
        let permission = MockPermissionService(preflightResult: true, requestResult: true)
        let launch = MockLaunchAtLoginService(isEnabled: false, errorToThrow: MockLaunchError.failed)
        let interception = MockInterceptionService(startResult: true)

        let coordinator = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            interceptionFactory: { _, _, _ in interception }
        )

        #expect(coordinator.lastError?.contains("Launch at Login") == true)
    }

    @Test("disabling protection stops interception")
    func disablingProtectionStopsInterception() async {
        let settings = makeSettings(isProtectionEnabled: true)
        let permission = MockPermissionService(preflightResult: true, requestResult: true)
        let launch = MockLaunchAtLoginService(isEnabled: false)
        let interception = MockInterceptionService(startResult: true)

        let coordinator = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            interceptionFactory: { _, _, _ in interception }
        )

        settings.isProtectionEnabled = false
        await Task.yield()

        #expect(interception.startCalls == 1)
        #expect(interception.stopCalls >= 1)
        #expect(!coordinator.isInterceptionRunning)
    }

    @Test("requestPermissions opens system settings when permission remains denied")
    func requestPermissionsOpensSystemSettingsWhenDenied() {
        let settings = makeSettings(isProtectionEnabled: true)
        let permission = MockPermissionService(preflightResult: false, requestResult: false)
        let launch = MockLaunchAtLoginService(isEnabled: false)
        let interception = MockInterceptionService(startResult: false)
        var openSystemSettingsCalls = 0

        let coordinator = AppCoordinator(
            settings: settings,
            permissionService: permission,
            launchAtLoginService: launch,
            overlayController: MockOverlayController(),
            systemSettingsOpener: { openSystemSettingsCalls += 1 },
            interceptionFactory: { _, _, _ in interception }
        )

        #expect(openSystemSettingsCalls == 0)
        coordinator.requestPermissions()
        #expect(openSystemSettingsCalls == 1)
        #expect(permission.requestCalls == 1)
        #expect(interception.startCalls == 2)
        #expect(interception.stopCalls == 2)
        #expect(!coordinator.isInterceptionRunning)
    }
}
