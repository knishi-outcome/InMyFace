import SwiftUI

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings: AppSettings
    let calendarService: CalendarService
    let overlayController: OverlayController
    let reminderCoordinator: ReminderCoordinator

    private init() {
        let settings = AppSettings()
        let calendarService = CalendarService()
        let overlayController = OverlayController()

        self.settings = settings
        self.calendarService = calendarService
        self.overlayController = overlayController
        reminderCoordinator = ReminderCoordinator(
            calendarService: calendarService,
            settings: settings,
            overlayController: overlayController
        )
    }

    func start() {
        reminderCoordinator.start()
    }

    func stop() {
        reminderCoordinator.stop()
    }
}

@main
@MainActor
struct InMyFaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let environment = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                calendarService: environment.calendarService,
                settings: environment.settings,
                reminderCoordinator: environment.reminderCoordinator
            )
        } label: {
            Label("InMyFace", systemImage: "bell.and.waves.left.and.right.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                calendarService: environment.calendarService,
                settings: environment.settings,
                reminderCoordinator: environment.reminderCoordinator
            )
            .frame(width: 720, height: 620)
        }
        .windowResizability(.contentSize)
    }
}
