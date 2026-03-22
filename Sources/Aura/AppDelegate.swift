import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        print("[Aura] App launched")
        #endif

        LauncherPanelController.shared.setup()

        HotkeyManager.shared.onToggle = {
            #if DEBUG
            print("[Aura] Toggle called")
            #endif
            LauncherPanelController.shared.toggle()
        }
        HotkeyManager.shared.start()

        setupStatusItem()

        // Show panel on first launch so user knows it works
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LauncherPanelController.shared.show()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Aura")
            button.image?.size = NSSize(width: 16, height: 16)
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Aura", action: #selector(openAura), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Aura", action: #selector(quitApp), keyEquivalent: "q")
            .target = self

        statusItem?.menu = menu
    }

    @objc private func openAura() {
        LauncherPanelController.shared.show()
    }

    @objc private func quitApp() {
        HotkeyManager.shared.stop()
        NSApp.terminate(nil)
    }
}
