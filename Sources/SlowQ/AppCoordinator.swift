import AppKit
import Combine
import SwiftUI

enum PermissionKind {
    case inputMonitoring
    case accessibility
}

@MainActor
final class AppCoordinator: ObservableObject {
    private static let permissionErrorMessage =
        "Input Monitoring permission is required for SlowQ to protect Cmd+Q."
    private static let interceptionStartErrorMessage =
        "Failed to start keyboard interception. Another tool may be blocking event tap registration."

    @Published var settings: SettingsStore
    @Published private(set) var inputMonitoringState: PermissionState
    @Published private(set) var accessibilityState: PermissionState
    @Published private(set) var isInterceptionRunning = false
    @Published var lastError: String?

    private let permissionService: any PermissionServicing
    private let launchAtLoginService: any LaunchAtLoginControlling
    private let interceptionService: QuitInterceptionControlling
    private let systemSettingsOpener: (PermissionKind) -> Void
    private var cancellables = Set<AnyCancellable>()
    private var fallbackSettingsWindowController: NSWindowController?

    init(
        settings: SettingsStore = SettingsStore(),
        permissionService: any PermissionServicing = AccessibilityPermissionService(),
        launchAtLoginService: any LaunchAtLoginControlling = LaunchAtLoginService(),
        overlayController: OverlayPresenting = OverlayController(),
        systemSettingsOpener: ((PermissionKind) -> Void)? = nil,
        interceptionFactory: (
            (@escaping () -> Bool, @escaping () -> Int, OverlayPresenting) -> QuitInterceptionControlling
        )? = nil
    ) {
        self.settings = settings
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.systemSettingsOpener = systemSettingsOpener ?? Self.defaultSystemSettingsOpener
        self.inputMonitoringState = permissionService.preflightListenPermission() ? .granted : .denied
        self.accessibilityState = permissionService.isAccessibilityTrusted() ? .granted : .denied
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
        refreshPermissionState(requestIfNeeded: false)
        reconcileInterception(isProtectionEnabled: settings.isProtectionEnabled)
    }

    var menuBarSymbolName: String {
        isInterceptionRunning ? "shield.lefthalf.filled" : "shield"
    }

    func requestPermission(_ kind: PermissionKind) {
        refreshPermissionState(requestIfNeeded: true)
        switch kind {
        case .inputMonitoring where inputMonitoringState != .granted:
            openSystemSettings(for: .inputMonitoring)
        case .accessibility where accessibilityState != .granted:
            openSystemSettings(for: .accessibility)
        default:
            break
        }
        reconcileInterception(isProtectionEnabled: settings.isProtectionEnabled)
    }

    func refreshRuntimeState() {
        refreshPermissionState(requestIfNeeded: false)
        reconcileInterception(isProtectionEnabled: settings.isProtectionEnabled)
    }

    func openSystemSettings(for kind: PermissionKind) {
        systemSettingsOpener(kind)
    }

    func showSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        showFallbackSettingsWindow()
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
        accessibilityState = permissionService.isAccessibilityTrusted() ? .granted : .denied

        if permissionService.preflightListenPermission() {
            inputMonitoringState = .granted
            return
        }

        guard requestIfNeeded else {
            inputMonitoringState = .denied
            return
        }

        inputMonitoringState = permissionService.requestListenPermission() ? .granted : .denied
    }

    private func reconcileInterception(isProtectionEnabled: Bool) {
        guard isProtectionEnabled else {
            interceptionService.stop()
            isInterceptionRunning = false
            return
        }

        if interceptionService.start() {
            isInterceptionRunning = true
            if inputMonitoringState != .granted {
                inputMonitoringState = .granted
            }
            clearInterceptionErrorIfNeeded()
            return
        }

        interceptionService.stop()
        isInterceptionRunning = false
        if inputMonitoringState == .granted {
            lastError = Self.interceptionStartErrorMessage
        } else {
            lastError = Self.permissionErrorMessage
        }
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

    private func showFallbackSettingsWindow() {
        if let window = fallbackSettingsWindowController?.window {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsRootView = SettingsView(coordinator: self)
            .frame(width: 420)
            .padding()

        let hostingController = NSHostingController(rootView: settingsRootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SlowQ Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        let windowController = NSWindowController(window: window)
        fallbackSettingsWindowController = windowController
        window.orderFrontRegardless()
        windowController.showWindow(nil)
    }

    private static let defaultSystemSettingsOpener: (PermissionKind) -> Void = { kind in
        NSApplication.shared.activate(ignoringOtherApps: true)

        let inputMonitoringCandidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
        ]

        let accessibilityCandidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]

        let genericCandidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:",
        ]

        let candidates: [String]
        switch kind {
        case .inputMonitoring:
            candidates = inputMonitoringCandidates + accessibilityCandidates + genericCandidates
        case .accessibility:
            candidates = accessibilityCandidates + inputMonitoringCandidates + genericCandidates
        }

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }

        let appURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        _ = NSWorkspace.shared.open(appURL)
    }
}
