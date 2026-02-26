import Testing

@testable import SlowQ

private enum MockMainAppServiceError: Error {
    case failed
}

private final class MockMainAppService: MainAppServiceControlling {
    var status: MainAppServiceStatus
    var registerCalls = 0
    var unregisterCalls = 0
    var registerError: Error?
    var unregisterError: Error?

    init(status: MainAppServiceStatus) {
        self.status = status
    }

    func register() throws {
        registerCalls += 1
        if let registerError {
            throw registerError
        }
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError {
            throw unregisterError
        }
    }
}

@Suite("LaunchAtLoginService")
struct LaunchAtLoginServiceTests {
    @Test("isEnabled reflects service status")
    func statusMapping() {
        let enabledService = LaunchAtLoginService(service: MockMainAppService(status: .enabled))
        let disabledService = LaunchAtLoginService(service: MockMainAppService(status: .notEnabled))

        #expect(enabledService.isEnabled)
        #expect(!disabledService.isEnabled)
    }

    @Test("setEnabled(true) registers")
    func setEnabledTrue() throws {
        let mock = MockMainAppService(status: .notEnabled)
        let service = LaunchAtLoginService(service: mock)

        try service.setEnabled(true)
        #expect(mock.registerCalls == 1)
        #expect(mock.unregisterCalls == 0)
    }

    @Test("setEnabled(false) unregisters")
    func setEnabledFalse() throws {
        let mock = MockMainAppService(status: .enabled)
        let service = LaunchAtLoginService(service: mock)

        try service.setEnabled(false)
        #expect(mock.unregisterCalls == 1)
        #expect(mock.registerCalls == 0)
    }

    @Test("errors are propagated")
    func errorPropagation() {
        let mock = MockMainAppService(status: .notEnabled)
        mock.registerError = MockMainAppServiceError.failed
        let service = LaunchAtLoginService(service: mock)

        #expect(throws: MockMainAppServiceError.self) {
            try service.setEnabled(true)
        }
    }
}
