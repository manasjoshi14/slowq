import AppKit
import Carbon
import Foundation

protocol QuitInterceptionControlling: AnyObject {
    func start() -> Bool
    func stop()
    var isRunning: Bool { get }
}

protocol OverlayPresenting: AnyObject {
    func show(appName: String, duration: TimeInterval)
    func update(progress: Double)
    func hideAndReset()
}

struct FrontmostApplicationSnapshot {
    let bundleIdentifier: String?
    let localizedName: String
    let terminate: () -> Void
}

protocol FrontmostApplicationProviding {
    var frontmostApplication: FrontmostApplicationSnapshot? { get }
}

struct NSWorkspaceFrontmostApplicationProvider: FrontmostApplicationProviding {
    var frontmostApplication: FrontmostApplicationSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return FrontmostApplicationSnapshot(
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName ?? "",
            terminate: { app.terminate() }
        )
    }
}

protocol CommandKeyStateProviding {
    func isCommandPressed() -> Bool
}

struct CGEventCommandKeyStateProvider: CommandKeyStateProviding {
    func isCommandPressed() -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Command))
    }
}

final class QuitInterceptionService: QuitInterceptionControlling {
    typealias HoldTimerFactory = (@escaping () -> Void) -> DispatchSourceTimer?

    private let isEnabledProvider: () -> Bool
    private let delayMsProvider: () -> Int
    private let overlayController: OverlayPresenting
    private let frontmostApplicationProvider: any FrontmostApplicationProviding
    private let commandKeyStateProvider: any CommandKeyStateProviding
    private let holdTimerFactory: HoldTimerFactory

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var holdTimer: DispatchSourceTimer?
    private var trackedApplication: FrontmostApplicationSnapshot?
    private var policy = InterceptionPolicy()

    private let holdEngine = HoldToQuitEngine()

    var isRunning: Bool {
        eventTap != nil
    }

    init(
        isEnabledProvider: @escaping () -> Bool,
        delayMsProvider: @escaping () -> Int,
        overlayController: OverlayPresenting,
        frontmostApplicationProvider: any FrontmostApplicationProviding = NSWorkspaceFrontmostApplicationProvider(),
        commandKeyStateProvider: any CommandKeyStateProviding = CGEventCommandKeyStateProvider(),
        holdTimerFactory: HoldTimerFactory? = nil
    ) {
        self.isEnabledProvider = isEnabledProvider
        self.delayMsProvider = delayMsProvider
        self.overlayController = overlayController
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.commandKeyStateProvider = commandKeyStateProvider
        self.holdTimerFactory =
            holdTimerFactory ?? { handler in
                let timer = DispatchSource.makeTimerSource(queue: .main)
                timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(4))
                timer.setEventHandler(handler: handler)
                timer.resume()
                return timer
            }
    }

    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let eventMask =
            mask(for: .flagsChanged)
            | mask(for: .keyDown)
            | mask(for: .keyUp)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return nil
            }

            let service = Unmanaged<QuitInterceptionService>.fromOpaque(userInfo).takeUnretainedValue()
            return service.handleEvent(type: type, event: event)
        }

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        eventTapSource = source
        return true
    }

    func stop() {
        cancelHold()

        guard let tap = eventTap, let source = eventTapSource else {
            eventTap = nil
            eventTapSource = nil
            return
        }

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)

        eventTap = nil
        eventTapSource = nil
    }

    func handleEvent(
        type: CGEventType,
        event: CGEvent,
        shouldHandleOverride: Bool? = nil
    ) -> Unmanaged<CGEvent>? {
        let input = makeInput(type: type, event: event)
        let decision = policy.decide(
            input: input,
            holdIsActive: holdEngine.isHolding,
            shouldHandleCmdQ: { [weak self] in
                shouldHandleOverride ?? (self?.shouldHandleCmdQ() ?? false)
            }
        )

        perform(decision: decision)
        switch decision {
        case .pass, .reenableTapAndPass:
            return pass(event)
        case .swallow, .beginHold, .cancelHold:
            return nil
        }
    }

    @discardableResult
    func processForTesting(input: InterceptionInput, shouldHandleCmdQ: Bool) -> InterceptionDecision {
        let decision = policy.decide(
            input: input,
            holdIsActive: holdEngine.isHolding,
            shouldHandleCmdQ: { shouldHandleCmdQ }
        )
        perform(decision: decision)
        return decision
    }

    func tickHoldForTesting() {
        tickHold()
    }

    private func perform(decision: InterceptionDecision) {
        switch decision {
        case .pass, .swallow:
            break
        case .reenableTapAndPass:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .beginHold:
            beginHold()
        case .cancelHold:
            cancelHold()
        }
    }

    private func shouldHandleCmdQ() -> Bool {
        guard isEnabledProvider() else {
            return false
        }

        guard let app = frontmostApplicationProvider.frontmostApplication else {
            return false
        }

        if app.bundleIdentifier == "com.apple.finder" {
            return false
        }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        return true
    }

    private func beginHold() {
        guard let app = frontmostApplicationProvider.frontmostApplication else {
            return
        }

        trackedApplication = app
        holdEngine.start()
        overlayController.show(appName: app.localizedName, duration: Double(delayMsProvider()) / 1_000.0)
        startHoldTimer()
    }

    private func startHoldTimer() {
        holdTimer?.cancel()
        holdTimer = holdTimerFactory { [weak self] in
            self?.tickHold()
        }
    }

    private func tickHold() {
        guard holdEngine.isHolding else {
            return
        }

        if !commandKeyStateProvider.isCommandPressed() {
            cancelHold()
            return
        }

        let delay = max(delayMsProvider(), 1)
        switch holdEngine.tick(delayMs: delay) {
        case .notHolding:
            return
        case let .holding(progress):
            overlayController.update(progress: progress)
        case .completed:
            completeHold()
        }
    }

    private func completeHold() {
        trackedApplication?.terminate()
        cleanupHoldState()
    }

    private func cancelHold() {
        holdEngine.cancel()
        cleanupHoldState()
    }

    private func cleanupHoldState() {
        holdTimer?.cancel()
        holdTimer = nil
        trackedApplication = nil
        holdEngine.reset()
        overlayController.hideAndReset()
    }

    private func pass(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        Unmanaged.passUnretained(event)
    }

    private func makeInput(type: CGEventType, event: CGEvent) -> InterceptionInput {
        let eventKind: InterceptionEventKind
        switch type {
        case .tapDisabledByTimeout:
            eventKind = .tapDisabledByTimeout
        case .tapDisabledByUserInput:
            eventKind = .tapDisabledByUserInput
        case .flagsChanged:
            eventKind = .flagsChanged
        case .keyDown:
            eventKind = .keyDown
        case .keyUp:
            eventKind = .keyUp
        default:
            eventKind = .other
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let key: InterceptionKey
        switch keyCode {
        case CGKeyCode(kVK_ANSI_Q):
            key = .q
        case CGKeyCode(kVK_Tab):
            key = .tab
        default:
            key = .other
        }

        return InterceptionInput(
            event: eventKind,
            key: key,
            commandPressed: event.flags.contains(.maskCommand),
            controlPressed: event.flags.contains(.maskControl)
        )
    }

    private func mask(for type: CGEventType) -> CGEventMask {
        CGEventMask(1) << CGEventMask(type.rawValue)
    }
}
