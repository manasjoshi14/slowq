import Testing

@testable import SlowQ

@Suite("InterceptionPolicy")
struct InterceptionPolicyTests {
    private func input(
        event: InterceptionEventKind,
        key: InterceptionKey = .other,
        commandPressed: Bool = false,
        controlPressed: Bool = false
    ) -> InterceptionInput {
        InterceptionInput(
            event: event,
            key: key,
            commandPressed: commandPressed,
            controlPressed: controlPressed
        )
    }

    @Test("tap disabled events re-enable tap and pass")
    func tapDisabledEvents() {
        var policy = InterceptionPolicy()
        let decision = policy.decide(
            input: input(event: .tapDisabledByTimeout),
            holdIsActive: false,
            shouldHandleCmdQ: { false }
        )

        #expect(decision == .reenableTapAndPass)
    }

    @Test("cmd+q key down starts hold when allowed")
    func cmdQStartsHold() {
        var policy = InterceptionPolicy()
        let decision = policy.decide(
            input: input(event: .keyDown, key: .q, commandPressed: true),
            holdIsActive: false,
            shouldHandleCmdQ: { true }
        )

        #expect(decision == .beginHold)
    }

    @Test("cmd+ctrl+q is passed through")
    func commandControlQPasses() {
        var policy = InterceptionPolicy()
        let decision = policy.decide(
            input: input(event: .keyDown, key: .q, commandPressed: true, controlPressed: true),
            holdIsActive: false,
            shouldHandleCmdQ: { true }
        )

        #expect(decision == .pass)
    }

    @Test("holding swallows q presses and cancels on release")
    func holdingBehavior() {
        var policy = InterceptionPolicy()

        let swallow = policy.decide(
            input: input(event: .keyDown, key: .q, commandPressed: true),
            holdIsActive: true,
            shouldHandleCmdQ: { true }
        )
        #expect(swallow == .swallow)

        let cancel = policy.decide(
            input: input(event: .keyUp, key: .q, commandPressed: true),
            holdIsActive: true,
            shouldHandleCmdQ: { true }
        )
        #expect(cancel == .cancelHold)
    }

    @Test("app switcher path blocks cmd+q until command released")
    func appSwitcherBlocksInterception() {
        var policy = InterceptionPolicy()

        let switcherEvent = policy.decide(
            input: input(event: .keyDown, key: .tab, commandPressed: true),
            holdIsActive: false,
            shouldHandleCmdQ: { true }
        )
        #expect(switcherEvent == .pass)

        let blockedCmdQ = policy.decide(
            input: input(event: .keyDown, key: .q, commandPressed: true),
            holdIsActive: false,
            shouldHandleCmdQ: { true }
        )
        #expect(blockedCmdQ == .pass)

        let commandReleased = policy.decide(
            input: input(event: .flagsChanged, commandPressed: false),
            holdIsActive: false,
            shouldHandleCmdQ: { true }
        )
        #expect(commandReleased == .pass)

        let cmdQAfterRelease = policy.decide(
            input: input(event: .keyDown, key: .q, commandPressed: true),
            holdIsActive: false,
            shouldHandleCmdQ: { true }
        )
        #expect(cmdQAfterRelease == .beginHold)
    }
}
