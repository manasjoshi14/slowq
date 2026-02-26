import AppKit
import Combine
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    private static let permissionErrorMessage =
        "Accessibility permission is required for SlowQ to protect Cmd+Q."
    private static let interceptionStartErrorMessage =
        "Failed to start keyboard interception. Another tool may be blocking event tap registration."

    @Published var settings: SettingsStore
    @Published private(set) var permissionState: PermissionState
    @Published private(set) var isInterceptionRunning = false
    @Published var lastError: String?

    private let permissionService: any PermissionServicing
    private let launchAtLoginService: any LaunchAtLoginControlling
    private let interceptionService: QuitInterceptionControlling
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsStore = SettingsStore(),
        permissionService: any PermissionServicing = AccessibilityPermissionService(),
        launchAtLoginService: any LaunchAtLoginControlling = LaunchAtLoginService(),
        overlayController: OverlayPresenting = OverlayController(),
        interceptionFactory: (
            (@escaping () -> Bool, @escaping () -> Int, OverlayPresenting) -> QuitInterceptionControlling
        )? = nil
    ) {
        self.settings = settings
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.permissionState = permissionService.preflightListenPermission() ? .granted : .denied
        let factory =
            interceptionFactory ?? { isEnabledProvider, delayMsProvider, overlay in
                QuitInterceptionService(
                    isEnabledProvider: isEnabledProvider,
                    delayMsProvider: delayMsProvider,
                    overlayController: overlay
                )
            }
        self.interceptionService = factory(
            { settings.isProtectionEnabled },
            { settings.delayMs },
            overlayController
        )

        bindSettings()
        applyLaunchAtLoginIfNeeded(settings.launchAtLogin)
        refreshPermissionState(requestIfNeeded: true)
        reconcileInterception(isProtectionEnabled: settings.isProtectionEnabled)
    }

    var menuBarSymbolName: String {
        isInterceptionRunning ? "shield.lefthalf.filled" : "shield"
    }

    func requestPermissions() {
        refreshPermissionState(requestIfNeeded: true)
        reconcileInterception(isProtectionEnabled: settings.isProtectionEnabled)
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func showSettings() {
        NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func bindSettings() {
        settings.$isProtectionEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.reconcileInterception(isProtectionEnabled: isEnabled)
            }
            .store(in: &cancellables)

        settings.$launchAtLogin
            .dropFirst()
            .sink { [weak self] enabled in
                self?.applyLaunchAtLoginIfNeeded(enabled)
            }
            .store(in: &cancellables)
    }

    private func refreshPermissionState(requestIfNeeded: Bool) {
        if permissionService.preflightListenPermission() {
            permissionState = .granted
            return
        }

        guard requestIfNeeded else {
            permissionState = .denied
            return
        }

        permissionState = permissionService.requestListenPermission() ? .granted : .denied
    }

    private func reconcileInterception(isProtectionEnabled: Bool) {
        guard isProtectionEnabled else {
            interceptionService.stop()
            isInterceptionRunning = false
            return
        }

        guard permissionState == .granted else {
            interceptionService.stop()
            isInterceptionRunning = false
            lastError = Self.permissionErrorMessage
            return
        }

        if interceptionService.start() {
            isInterceptionRunning = true
            clearInterceptionErrorIfNeeded()
            return
        }

        isInterceptionRunning = false
        lastError = Self.interceptionStartErrorMessage
    }

    private func applyLaunchAtLoginIfNeeded(_ enabled: Bool) {
        guard launchAtLoginService.isEnabled != enabled else {
            return
        }

        do {
            try launchAtLoginService.setEnabled(enabled)
        } catch {
            lastError = "Unable to update Launch at Login: \(error.localizedDescription)"
        }
    }

    private func clearInterceptionErrorIfNeeded() {
        guard let lastError else {
            return
        }

        if lastError == Self.permissionErrorMessage || lastError == Self.interceptionStartErrorMessage {
            self.lastError = nil
        }
    }
}
