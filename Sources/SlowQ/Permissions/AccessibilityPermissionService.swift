@preconcurrency import ApplicationServices
import Foundation

enum PermissionState {
    case notDetermined
    case denied
    case granted
}

protocol PermissionServicing {
    func preflightListenPermission() -> Bool
    func requestListenPermission() -> Bool
    func isAccessibilityTrusted() -> Bool
}

protocol AccessibilityPermissionAPI {
    func preflightListenEventAccess() -> Bool
    func requestListenEventAccess() -> Bool
    func isProcessTrusted() -> Bool
    func isProcessTrustedWithPrompt() -> Bool
}

struct SystemAccessibilityPermissionAPI: AccessibilityPermissionAPI {
    func preflightListenEventAccess() -> Bool {
        CGPreflightListenEventAccess()
    }

    func requestListenEventAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func isProcessTrustedWithPrompt() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

struct AccessibilityPermissionService {
    private let api: any AccessibilityPermissionAPI
    private let usesCGListenAccess: Bool

    init(
        api: any AccessibilityPermissionAPI = SystemAccessibilityPermissionAPI(),
        usesCGListenAccess: Bool = Self.defaultUsesCGListenAccess
    ) {
        self.api = api
        self.usesCGListenAccess = usesCGListenAccess
    }

    private static var defaultUsesCGListenAccess: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }

    func preflightListenPermission() -> Bool {
        if usesCGListenAccess {
            return api.preflightListenEventAccess()
        }
        return api.isProcessTrusted()
    }

    func requestListenPermission() -> Bool {
        if usesCGListenAccess {
            _ = api.requestListenEventAccess()
            return api.preflightListenEventAccess()
        }
        return api.isProcessTrustedWithPrompt()
    }

    func isAccessibilityTrusted() -> Bool {
        api.isProcessTrusted()
    }
}

extension AccessibilityPermissionService: PermissionServicing {}
