import Testing

@testable import SlowQ

@Suite("HoldToQuitEngine")
struct HoldToQuitEngineTests {
    @Test("tick before start is not holding")
    func tickWithoutStart() {
        let engine = HoldToQuitEngine(now: { 0 })
        #expect(engine.tick(delayMs: 1_000) == .notHolding)
    }

    @Test("completes only after full delay")
    func completesAfterThreshold() {
        var now = 0.0
        let engine = HoldToQuitEngine(now: { now })

        engine.start()

        now = 0.50
        #expect(engine.tick(delayMs: 1_000) == .holding(progress: 0.5))

        now = 1.00
        #expect(engine.tick(delayMs: 1_000) == .completed)
        #expect(engine.state == .completed)
    }

    @Test("cancel transitions state")
    func cancelHolding() {
        let engine = HoldToQuitEngine(now: { 0 })
        engine.start()

        engine.cancel()

        #expect(engine.state == .cancelled)
    }

    @Test("reset returns to idle")
    func resetToIdle() {
        let engine = HoldToQuitEngine(now: { 0 })
        engine.start()
        engine.cancel()
        engine.reset()

        #expect(engine.state == .idle)
        #expect(engine.tick(delayMs: 1_000) == .notHolding)
    }
}
