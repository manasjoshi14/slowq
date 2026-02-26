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
        NSColor.white.withAlphaComponent(0.15).setFill()
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
        NSColor.white.withAlphaComponent(0.85).setFill()
        fillPath.fill()
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
        let iconView = NSImageView()
        if let symbolImage = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Shield") {
            let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
            iconView.image = symbolImage.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel = NSTextField(labelWithString: "Hold ⌘Q")
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.95)

        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.7)

        progressView = FrostRailProgressView()
        progressView.wantsLayer = true
        progressView.layer?.masksToBounds = true

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 180),
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
        material.maskImage = Self.roundedRectMask(cornerRadius: 20)

        let stack = NSStackView(views: [iconView, titleLabel, subtitleLabel, progressView])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        material.addSubview(stack)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            progressView.widthAnchor.constraint(equalToConstant: 160),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            stack.leadingAnchor.constraint(equalTo: material.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: material.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: material.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: material.bottomAnchor, constant: -20),
        ])

        panel.contentView = material
    }

    private static func roundedRectMask(cornerRadius: CGFloat) -> NSImage {
        let size = NSSize(width: cornerRadius * 2 + 1, height: cornerRadius * 2 + 1)
        let image = NSImage(size: size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: cornerRadius,
            left: cornerRadius,
            bottom: cornerRadius,
            right: cornerRadius
        )
        image.resizingMode = .stretch
        return image
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
