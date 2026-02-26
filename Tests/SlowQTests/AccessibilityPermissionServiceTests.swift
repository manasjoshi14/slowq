import Testing

@testable import SlowQ

private final class MockAccessibilityPermissionAPI: AccessibilityPermissionAPI {
    var preflightListenEventAccessResult = false
    var requestListenEventAccessResult = false
    var isProcessTrustedResult = false
    var isProcessTrustedWithPromptResult = false

    var preflightListenEventAccessCalls = 0
    var requestListenEventAccessCalls = 0
    var isProcessTrustedCalls = 0
    var isProcessTrustedWithPromptCalls = 0

    func preflightListenEventAccess() -> Bool {
        preflightListenEventAccessCalls += 1
        return preflightListenEventAccessResult
    }

    func requestListenEventAccess() -> Bool {
        requestListenEventAccessCalls += 1
        return requestListenEventAccessResult
    }

    func isProcessTrusted() -> Bool {
        isProcessTrustedCalls += 1
        return isProcessTrustedResult
    }

    func isProcessTrustedWithPrompt() -> Bool {
        isProcessTrustedWithPromptCalls += 1
        return isProcessTrustedWithPromptResult
    }
}

@Suite("AccessibilityPermissionService")
struct AccessibilityPermissionServiceTests {
    @Test("CG access path is used when enabled")
    func cgPath() {
        let api = MockAccessibilityPermissionAPI()
        api.preflightListenEventAccessResult = true
        api.requestListenEventAccessResult = true
        let service = AccessibilityPermissionService(api: api, usesCGListenAccess: true)

        #expect(service.preflightListenPermission())
        #expect(service.requestListenPermission())
        #expect(api.preflightListenEventAccessCalls == 2)
        #expect(api.requestListenEventAccessCalls == 1)
        #expect(api.isProcessTrustedCalls == 0)
        #expect(api.isProcessTrustedWithPromptCalls == 0)
    }

    @Test("CG path does not fall back to AX trust when listen access is unavailable")
    func cgPathDoesNotFallBackToAX() {
        let api = MockAccessibilityPermissionAPI()
        api.preflightListenEventAccessResult = false
        api.isProcessTrustedResult = true
        api.requestListenEventAccessResult = false
        api.isProcessTrustedWithPromptResult = true

        let service = AccessibilityPermissionService(api: api, usesCGListenAccess: true)

        #expect(service.preflightListenPermission() == false)
        #expect(service.requestListenPermission() == false)
        #expect(api.preflightListenEventAccessCalls == 2)
        #expect(api.requestListenEventAccessCalls == 1)
        #expect(api.isProcessTrustedCalls == 0)
        #expect(api.isProcessTrustedWithPromptCalls == 0)
    }

    @Test("AX trust path uses prompt-based check")
    func axPathWithPrompt() {
        let api = MockAccessibilityPermissionAPI()
        api.isProcessTrustedResult = true
        api.isProcessTrustedWithPromptResult = true
        let service = AccessibilityPermissionService(api: api, usesCGListenAccess: false)

        #expect(service.preflightListenPermission())
        #expect(service.requestListenPermission())
        #expect(api.preflightListenEventAccessCalls == 0)
        #expect(api.requestListenEventAccessCalls == 0)
        #expect(api.isProcessTrustedCalls == 1)
        #expect(api.isProcessTrustedWithPromptCalls == 1)
    }
}
