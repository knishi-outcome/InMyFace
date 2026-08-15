import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--preview") {
            // Keeping preview runs visible to UI inspection tools makes it possible
            // to verify the full-screen design without requesting calendar access.
            NSApp.setActivationPolicy(.regular)

            let theme = previewTheme(from: arguments)

            DispatchQueue.main.async {
                AppEnvironment.shared.reminderCoordinator.preview(theme: theme)
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

    private func previewTheme(from arguments: [String]) -> NotificationTheme? {
        if let themeArgument = arguments.first(where: { $0.hasPrefix("--theme=") }) {
            return NotificationTheme(rawValue: String(themeArgument.dropFirst("--theme=".count)))
        }

        guard
            let themeFlagIndex = arguments.firstIndex(of: "--theme"),
            arguments.indices.contains(themeFlagIndex + 1)
        else {
            return nil
        }

        return NotificationTheme(rawValue: arguments[themeFlagIndex + 1])
    }
}
