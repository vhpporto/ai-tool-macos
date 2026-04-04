import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func mouseDown(with event: NSEvent) {
        makeKey()
        super.mouseDown(with: event)
    }
}

// Zeroes out safe area insets so NSHostingView doesn't add
// phantom padding at the top and bottom of the SwiftUI content.
private final class ZeroInsetsHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { .init() }
}

@MainActor
final class LauncherPanelController {

    static let shared = LauncherPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<ContentView>?
    private let panelWidth: CGFloat = 816
    private let initialHeight: CGFloat = 148
    private let maxHeight: CGFloat = 676
    private let store = ConversationStore()

    var isVisible: Bool { panel?.isVisible ?? false }

    private init() {}

    func setup() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false

        let hosting = ZeroInsetsHostingView(rootView:
            ContentView(store: store, onDismiss: { [weak self] in self?.hide() }, onHeightChange: { [weak self] in self?.constrainHeight() })
        )
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        self.hostingView = hosting

        let visualEffect = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 28
        visualEffect.layer?.masksToBounds = true
        visualEffect.autoresizingMask = [.width, .height]

        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.focusRingType = .none
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView.layer?.cornerRadius = 28
            // masksToBounds = true clips subviews to rounded corners,
            // eliminating the rectangular corner artifacts.
            // Shadow is handled by panel.hasShadow = true above.
            contentView.layer?.masksToBounds = true
            contentView.addSubview(visualEffect)
            contentView.addSubview(hosting)
        }

        self.panel = panel
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        guard let panel else { return }

        store.clear()

        if let saved = loadSavedFrame() {
            panel.setFrame(saved, display: true)
        } else {
            positionPanel(height: initialHeight)
        }

        // Animate in: start transparent + slightly scaled, then animate to full
        panel.alphaValue = 0
        if let contentLayer = panel.contentView?.layer {
            contentLayer.setAffineTransform(CGAffineTransform(scaleX: 0.97, y: 0.97))
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        if let contentLayer = panel.contentView?.layer {
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 0.97
            anim.toValue = 1.0
            anim.duration = 0.2
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentLayer.setAffineTransform(.identity)
            contentLayer.add(anim, forKey: "scaleIn")
        }

        ClipboardMonitor.shared.start()

        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: panel.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.constrainHeight()
            }
        }
    }

    func hide() {
        guard let panel else { return }

        // Save position before hiding
        let topEdge = panel.frame.origin.y + panel.frame.height
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "aura_panel_x")
        UserDefaults.standard.set(topEdge, forKey: "aura_panel_top_edge")

        // Animate out: fade to transparent
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1 // Reset for next show
            NotificationCenter.default.removeObserver(self as Any)
        })

        ClipboardMonitor.shared.stop()
    }

    private func loadSavedFrame() -> NSRect? {
        guard UserDefaults.standard.object(forKey: "aura_panel_top_edge") != nil else { return nil }
        let x = UserDefaults.standard.double(forKey: "aura_panel_x")
        let topEdge = UserDefaults.standard.double(forKey: "aura_panel_top_edge")
        let y = topEdge - initialHeight
        let frame = NSRect(x: x, y: y, width: panelWidth, height: initialHeight)
        guard let screen = NSScreen.main, screen.visibleFrame.intersects(frame) else { return nil }
        return frame
    }

    private var defaultTopEdge: CGFloat {
        guard let screen = NSScreen.main else { return 600 }
        let f = screen.visibleFrame
        return f.maxY - (f.height * 0.22)
    }

    private func positionPanel(height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panelWidth / 2
        let y = defaultTopEdge - height
        panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: height), display: true)
    }

    func constrainHeight() {
        guard let panel, let hosting = hostingView else { return }

        // Force layout pass so fittingSize reflects current SwiftUI content
        hosting.layoutSubtreeIfNeeded()

        let ideal = hosting.fittingSize.height
        guard ideal > 0 else { return }
        var clamped = min(ideal, maxHeight)

        // Don't let the panel go below the visible screen area
        if let screen = NSScreen.main {
            let current = panel.frame
            let topEdge = current.origin.y + current.height
            let minY = screen.visibleFrame.minY + 8
            clamped = min(clamped, topEdge - minY)
        }

        clamped = max(clamped, 0)

        if abs(panel.frame.height - clamped) > 1 {
            let current = panel.frame
            let topEdge = current.origin.y + current.height
            panel.setFrame(NSRect(x: current.origin.x, y: topEdge - clamped, width: panelWidth, height: clamped), display: true)
        }
    }
}
