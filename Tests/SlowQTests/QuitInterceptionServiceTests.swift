import Carbon
import Foundation
import Testing

@testable import SlowQ

private final class MockOverlayController: OverlayPresenting {
    var showCalls: [(appName: String, duration: TimeInterval)] = []
    var updateCalls: [Double] = []
    var hideCalls = 0

    func show(appName: String, duration: TimeInterval) {
        showCalls.append((appName: appName, duration: duration))
    }

    func update(progress: Double) {
        updateCalls.append(progress)
    }

    func hideAndReset() {
        hideCalls += 1
    }
}

private final class MockFrontmostApplicationProvider: FrontmostApplicationProviding {
    var frontmostApplication: FrontmostApplicationSnapshot?
}

private final class MockCommandKeyStateProvider: CommandKeyStateProviding {
    var isPressed = true

    func isCommandPressed() -> Bool {
        isPressed
    }
}

private final class TerminationTracker {
    var terminateCalls = 0
}

private func makeKeyboardEvent(
    keyCode: CGKeyCode,
    flags: CGEventFlags = []
) -> CGEvent {
    guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
        fatalError("Failed to create keyboard event")
    }
    event.flags = flags
    return event
}

@Suite("QuitInterceptionService")
@MainActor
struct QuitInterceptionServiceTests {
    private func makeService(
        overlay: MockOverlayController,
        frontmostProvider: MockFrontmostApplicationProvider,
        commandKeyState: MockCommandKeyStateProvider,
        delayMs: @escaping () -> Int = { 1_000 }
    ) -> QuitInterceptionService {
        QuitInterceptionService(
            isEnabledProvider: { true },
            delayMsProvider: delayMs,
            overlayController: overlay,
            frontmostApplicationProvider: frontmostProvider,
            commandKeyStateProvider: commandKeyState,
            holdTimerFactory: { _ in nil }
        )
    }

    @Test("non cmd+q keydown passes through")
    func nonInterceptedEventPasses() {
        let overlay = MockOverlayController()
        let frontmost = MockFrontmostApplicationProvider()
        let commandState = MockCommandKeyStateProvider()
        let service = makeService(overlay: overlay, frontmostProvider: frontmost, commandKeyState: commandState)
        let event = makeKeyboardEvent(keyCode: CGKeyCode(kVK_ANSI_Q))

        let result = service.handleEvent(type: .keyDown, event: event, shouldHandleOverride: true)
        #expect(result != nil)
        #expect(overlay.showCalls.isEmpty)
    }

    @Test("cmd+q keydown starts hold and keyup cancels")
    func beginAndCancelHoldFlow() {
        let overlay = MockOverlayController()
        let frontmost = MockFrontmostApplicationProvider()
        let commandState = MockCommandKeyStateProvider()
        let tracker = TerminationTracker()
        frontmost.frontmostApplication = FrontmostApplicationSnapshot(
            bundleIdentifier: "com.example.target",
            localizedName: "TargetApp",
            terminate: { tracker.terminateCalls += 1 }
        )

        let service = makeService(overlay: overlay, frontmostProvider: frontmost, commandKeyState: commandState)
        let cmdQDown = makeKeyboardEvent(keyCode: CGKeyCode(kVK_ANSI_Q), flags: [.maskCommand])
        let cmdQUp = makeKeyboardEvent(keyCode: CGKeyCode(kVK_ANSI_Q), flags: [.maskCommand])

        let startResult = service.handleEvent(type: .keyDown, event: cmdQDown, shouldHandleOverride: true)
        #expect(startResult == nil)
        #expect(overlay.showCalls.count == 1)
        #expect(overlay.showCalls.first?.appName == "TargetApp")

        let cancelResult = service.handleEvent(type: .keyUp, event: cmdQUp, shouldHandleOverride: true)
        #expect(cancelResult == nil)
        #expect(overlay.hideCalls >= 1)
        #expect(tracker.terminateCalls == 0)
    }

    @Test("hold tick completion terminates tracked app")
    func tickCompletesHold() {
        let overlay = MockOverlayController()
        let frontmost = MockFrontmostApplicationProvider()
        let commandState = MockCommandKeyStateProvider()
        let tracker = TerminationTracker()
        frontmost.frontmostApplication = FrontmostApplicationSnapshot(
            bundleIdentifier: "com.example.target",
            localizedName: "TargetApp",
            terminate: { tracker.terminateCalls += 1 }
        )

        let service = makeService(
            overlay: overlay,
            frontmostProvider: frontmost,
            commandKeyState: commandState,
            delayMs: { 1 }
        )
        let decision = service.processForTesting(
            input: InterceptionInput(event: .keyDown, key: .q, commandPressed: true, controlPressed: false),
            shouldHandleCmdQ: true
        )
        #expect(decision == .beginHold)

        Thread.sleep(forTimeInterval: 0.02)
        service.tickHoldForTesting()

        #expect(tracker.terminateCalls == 1)
        #expect(overlay.hideCalls >= 1)
    }

    @Test("hold tick cancels when command is no longer pressed")
    func tickCancelsWhenCommandReleased() {
        let overlay = MockOverlayController()
        let frontmost = MockFrontmostApplicationProvider()
        let commandState = MockCommandKeyStateProvider()
        let tracker = TerminationTracker()
        frontmost.frontmostApplication = FrontmostApplicationSnapshot(
            bundleIdentifier: "com.example.target",
            localizedName: "TargetApp",
            terminate: { tracker.terminateCalls += 1 }
        )

        let service = makeService(overlay: overlay, frontmostProvider: frontmost, commandKeyState: commandState)
        _ = service.processForTesting(
            input: InterceptionInput(event: .keyDown, key: .q, commandPressed: true, controlPressed: false),
            shouldHandleCmdQ: true
        )

        commandState.isPressed = false
        service.tickHoldForTesting()

        #expect(tracker.terminateCalls == 0)
        #expect(overlay.hideCalls >= 1)
    }

    @Test("start then stop is safe even without active event tap")
    func startStopSafety() {
        let overlay = MockOverlayController()
        let frontmost = MockFrontmostApplicationProvider()
        let commandState = MockCommandKeyStateProvider()
        let service = makeService(overlay: overlay, frontmostProvider: frontmost, commandKeyState: commandState)

        let started = service.start()
        #expect(service.isRunning == started)

        service.stop()
        #expect(!service.isRunning)
    }
}
