import Testing

@testable import SlowQ

@Suite("OverlayState")
struct OverlayStateTests {
    @Test("presenting with app name sets subtitle and visibility")
    func presentingNamedApp() {
        let state = OverlayState.presenting(appName: "Xcode")
        #expect(state.subtitle == "Quitting Xcode")
        #expect(state.progress == 0)
        #expect(state.isVisible)
    }

    @Test("presenting without app name uses generic subtitle")
    func presentingUnnamedApp() {
        let state = OverlayState.presenting(appName: "")
        #expect(state.subtitle == "Keep holding until progress completes")
        #expect(state.isVisible)
    }

    @Test("progress clamps to [0, 1]")
    func progressClamp() {
        var state = OverlayState.presenting(appName: "Test")
        state.updateProgress(-1)
        #expect(state.progress == 0)

        state.updateProgress(2)
        #expect(state.progress == 1)
    }

    @Test("hide resets state")
    func hideReset() {
        var state = OverlayState.presenting(appName: "Test")
        state.updateProgress(0.5)
        state.hideAndReset()

        #expect(state == .hidden)
    }
}

@MainActor
@Suite("OverlayController")
struct OverlayControllerTests {
    @Test("controller updates public state through lifecycle")
    func controllerStateFlow() {
        let controller = OverlayController()
        controller.show(appName: "Terminal", duration: 1.0)

        #expect(controller.state.isVisible)
        #expect(controller.state.subtitle == "Quitting Terminal")
        #expect(controller.state.progress == 0)

        controller.update(progress: 0.75)
        #expect(controller.state.progress == 0.75)

        controller.hideAndReset()
        #expect(controller.state == .hidden)
    }
}
