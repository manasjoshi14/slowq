import AppKit
import Foundation

struct OverlayState: Equatable {
    private(set) var subtitle: String
    private(set) var progress: Double
    private(set) var isVisible: Bool

    static let hidden = OverlayState(subtitle: "", progress: 0, isVisible: false)

    static func presenting(appName: String) -> OverlayState {
        let subtitle = appName.isEmpty ? "Keep holding until progress completes" : "Quitting \(appName)"
        return OverlayState(subtitle: subtitle, progress: 0, isVisible: true)
    }

    mutating func updateProgress(_ value: Double) {
        progress = Self.clampProgress(value)
    }

    mutating func hideAndReset() {
        subtitle = ""
        progress = 0
        isVisible = false
    }

    private static func clampProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

@MainActor
final class OverlayController: @preconcurrency OverlayPresenting {
    private let panel: NSPanel
    private let titleLabel: NSTextField
    private let subtitleLabel: NSTextField
    private let progressIndicator: NSProgressIndicator
    private(set) var state: OverlayState = .hidden

    init() {
        titleLabel = NSTextField(labelWithString: "Hold ⌘Q to Quit")
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor

        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        progressIndicator = NSProgressIndicator()
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        progressIndicator.controlSize = .large
        progressIndicator.style = .bar

        let stack = NSStackView(views: [titleLabel, subtitleLabel, progressIndicator])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let material = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        material.autoresizingMask = [.width, .height]
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active

        material.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: material.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: material.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: material.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: material.bottomAnchor, constant: -8),
        ])

        panel.contentView = material
    }

    func show(appName: String, duration: TimeInterval) {
        state = .presenting(appName: appName)
        subtitleLabel.stringValue = state.subtitle
        progressIndicator.doubleValue = state.progress
        panel.center()
        panel.orderFrontRegardless()
    }

    func update(progress: Double) {
        state.updateProgress(progress)
        progressIndicator.doubleValue = state.progress
    }

    func hideAndReset() {
        state.hideAndReset()
        progressIndicator.doubleValue = state.progress
        panel.orderOut(nil)
    }
}
