import SwiftUI

@main
struct AuraApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene is required by SwiftUI but we don't use it —
        // everything runs through AppDelegate and the launcher panel.
        Settings { EmptyView() }
    }
}
