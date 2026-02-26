import Foundation
import Testing

@testable import SlowQ

private final class UISmokePermissionService: PermissionServicing {
    let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func preflightListenPermission() -> Bool {
        granted
    }

    func requestListenPermission() -> Bool {
        granted
    }
}

private final class UISmokeLaunchService: LaunchAtLoginControlling {
    var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}

private final class UISmokeInterceptionService: QuitInterceptionControlling {
    var isRunning = false

    func start() -> Bool {
        isRunning = true
        return true
    }

    func stop() {
        isRunning = false
    }
}

private final class UISmokeOverlay: OverlayPresenting {
    func show(appName: String, duration: TimeInterval) {}
    func update(progress: Double) {}
    func hideAndReset() {}
}

@MainActor
private func makeSmokeSettings() -> SettingsStore {
    let suiteName = "io.github.manas.SlowQ.tests.ui.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Unable to create isolated defaults for UI smoke test")
    }
    return SettingsStore(defaults: defaults)
}

@MainActor
private func makeSmokeCoordinator(permissionGranted: Bool = true) -> AppCoordinator {
    let settings = makeSmokeSettings()
    let permission = UISmokePermissionService(granted: permissionGranted)
    let launch = UISmokeLaunchService()
    let interception = UISmokeInterceptionService()

    return AppCoordinator(
        settings: settings,
        permissionService: permission,
        launchAtLoginService: launch,
        overlayController: UISmokeOverlay(),
        interceptionFactory: { _, _, _ in interception }
    )
}

@MainActor
@Suite("UI Smoke")
struct UISmokeTests {
    @Test("menu and settings views build")
    func menuAndSettingsBodyBuild() {
        let coordinator = makeSmokeCoordinator()
        let menu = MenuContentView(coordinator: coordinator)
        let settings = SettingsView(coordinator: coordinator)

        _ = menu.body
        _ = settings.body
    }

    @Test("views build in denied permission state with diagnostics")
    func deniedStateBodyBuild() {
        let coordinator = makeSmokeCoordinator(permissionGranted: false)
        coordinator.lastError = "Sample error"
        let menu = MenuContentView(coordinator: coordinator)
        let settings = SettingsView(coordinator: coordinator)

        _ = menu.body
        _ = settings.body
    }

    @Test("app scene graph builds with injected coordinator")
    func appBodyBuilds() {
        let coordinator = makeSmokeCoordinator()
        let app = SlowQApp(coordinator: coordinator)
        _ = app.body
    }
}
