import Foundation
import ServiceManagement

protocol LaunchAtLoginControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

enum MainAppServiceStatus {
    case enabled
    case notEnabled
}

protocol MainAppServiceControlling {
    var status: MainAppServiceStatus { get }
    func register() throws
    func unregister() throws
}

struct ServiceManagementMainAppService: MainAppServiceControlling {
    var status: MainAppServiceStatus {
        guard #available(macOS 13.0, *) else {
            return .notEnabled
        }
        return SMAppService.mainApp.status == .enabled ? .enabled : .notEnabled
    }

    func register() throws {
        guard #available(macOS 13.0, *) else {
            return
        }
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        guard #available(macOS 13.0, *) else {
            return
        }
        try SMAppService.mainApp.unregister()
    }
}

struct LaunchAtLoginService: LaunchAtLoginControlling {
    private let service: any MainAppServiceControlling

    init(service: any MainAppServiceControlling = ServiceManagementMainAppService()) {
        self.service = service
    }

    var isEnabled: Bool {
        service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
