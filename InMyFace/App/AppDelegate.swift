import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--preview") {
            // Keeping preview runs visible to UI inspection tools makes it possible
            // to verify the full-screen design without requesting calendar access.
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.async {
                AppEnvironment.shared.reminderCoordinator.preview()
            }
        } else {
            NSApp.setActivationPolicy(.accessory)
            AppEnvironment.shared.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.stop()
    }
}
