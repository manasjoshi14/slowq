import Foundation
import QuartzCore

enum HoldState: Equatable {
    case idle
    case holding(startTimestamp: TimeInterval)
    case completed
    case cancelled
}

enum HoldTickResult: Equatable {
    case notHolding
    case holding(progress: Double)
    case completed
}

final class HoldToQuitEngine {
    typealias TimeProvider = () -> TimeInterval

    private let now: TimeProvider
    private(set) var state: HoldState = .idle

    init(now: @escaping TimeProvider = CACurrentMediaTime) {
        self.now = now
    }

    var isHolding: Bool {
        if case .holding = state {
            return true
        }
        return false
    }

    func start() {
        switch state {
        case .idle, .cancelled, .completed:
            state = .holding(startTimestamp: now())
        case .holding:
            break
        }
    }

    func cancel() {
        guard isHolding else {
            return
        }
        state = .cancelled
    }

    func reset() {
        state = .idle
    }

    func tick(delayMs: Int) -> HoldTickResult {
        guard case let .holding(startTimestamp) = state else {
            return .notHolding
        }

        let duration = max(delayMs, 1)
        let elapsedMs = max((now() - startTimestamp) * 1_000.0, 0)
        let progress = min(elapsedMs / Double(duration), 1.0)

        if progress >= 1.0 {
            state = .completed
            return .completed
        }

        return .holding(progress: progress)
    }
}
