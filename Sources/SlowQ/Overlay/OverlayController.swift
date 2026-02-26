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

private final class FrostRailProgressView: NSView {
    var progress: CGFloat = 0 {
        didSet {
            progress = min(max(progress, 0), 1)
            needsDisplay = true
        }
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let railRect = bounds.insetBy(dx: 0, dy: bounds.height * 0.18)
        let radius = railRect.height / 2

        let railPath = NSBezierPath(roundedRect: railRect, xRadius: radius, yRadius: radius)
        NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.22, alpha: 0.9).setFill()
        railPath.fill()

        let fillWidth = railRect.width * progress
        guard fillWidth > 0 else {
            return
        }

        let fillRect = NSRect(
            x: railRect.minX,
            y: railRect.minY,
            width: max(fillWidth, radius * 2),
            height: railRect.height
        )

        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
        fillPath.addClip()
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.20, green: 0.71, blue: 0.98, alpha: 1),
            NSColor(calibratedRed: 0.15, green: 0.57, blue: 0.93, alpha: 1),
        ])
        gradient?.draw(in: fillRect, angle: 0)
    }
}

@MainActor
final class OverlayController: @preconcurrency OverlayPresenting {
    private let panel: NSPanel
    private let titleLabel: NSTextField
    private let subtitleLabel: NSTextField
    private let progressView: FrostRailProgressView
    private(set) var state: OverlayState = .hidden

    init() {
        titleLabel = NSTextField(labelWithString: "Hold ⌘Q to Quit")
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 42, weight: .bold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.95)

        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.9)

        progressView = FrostRailProgressView()
        progressView.wantsLayer = true
        progressView.layer?.masksToBounds = true

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 220),
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
        material.wantsLayer = true
        material.layer?.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.11, blue: 0.20, alpha: 0.55).cgColor
        material.layer?.cornerRadius = 26
        material.layer?.masksToBounds = true
        material.layer?.borderWidth = 1
        material.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor

        let stack = NSStackView(views: [titleLabel, subtitleLabel, progressView])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(16, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        material.addSubview(stack)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressView.widthAnchor.constraint(equalToConstant: 580),
            progressView.heightAnchor.constraint(equalToConstant: 16),
            stack.leadingAnchor.constraint(equalTo: material.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: material.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: material.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(equalTo: material.bottomAnchor, constant: -30),
        ])

        panel.contentView = material
    }

    func show(appName: String, duration: TimeInterval) {
        state = .presenting(appName: appName)
        subtitleLabel.stringValue = state.subtitle
        progressView.progress = CGFloat(state.progress)
        panel.center()
        panel.orderFrontRegardless()
    }

    func update(progress: Double) {
        state.updateProgress(progress)
        progressView.progress = CGFloat(state.progress)
    }

    func hideAndReset() {
        state.hideAndReset()
        subtitleLabel.stringValue = state.subtitle
        progressView.progress = CGFloat(state.progress)
        panel.orderOut(nil)
    }
}
