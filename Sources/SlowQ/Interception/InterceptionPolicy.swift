import Foundation

enum InterceptionEventKind: Equatable {
    case tapDisabledByTimeout
    case tapDisabledByUserInput
    case flagsChanged
    case keyDown
    case keyUp
    case other
}

enum InterceptionKey: Equatable {
    case q
    case tab
    case other
}

struct InterceptionInput: Equatable {
    let event: InterceptionEventKind
    let key: InterceptionKey
    let commandPressed: Bool
    let controlPressed: Bool
}

enum InterceptionDecision: Equatable {
    case pass
    case swallow
    case reenableTapAndPass
    case beginHold
    case cancelHold
}

struct InterceptionPolicy {
    private(set) var appSwitcherActive = false

    mutating func decide(
        input: InterceptionInput,
        holdIsActive: Bool,
        shouldHandleCmdQ: () -> Bool
    ) -> InterceptionDecision {
        switch input.event {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .reenableTapAndPass
        case .flagsChanged, .keyDown, .keyUp:
            break
        case .other:
            return .pass
        }

        if input.commandPressed && input.key == .tab {
            appSwitcherActive = true
        } else if !input.commandPressed {
            appSwitcherActive = false
        }

        if holdIsActive {
            if (input.event == .flagsChanged && !input.commandPressed) || (input.event == .keyUp && input.key == .q) {
                return .cancelHold
            }

            if input.key == .q {
                return .swallow
            }
        }

        guard input.event == .keyDown else {
            return .pass
        }

        guard input.commandPressed, input.key == .q, !input.controlPressed else {
            return .pass
        }

        guard !appSwitcherActive else {
            return .pass
        }

        guard shouldHandleCmdQ() else {
            return .pass
        }

        return .beginHold
    }
}
