import AppKit
import SwiftUI

/// Creates one full-screen reminder panel per requested display and owns their lifecycle.
@MainActor
final class OverlayController {
    private var panels: [ReminderPanel] = []
    private var escapeMonitor: Any?
    private var onDismiss: (() -> Void)?
    private var onSnooze: (() -> Void)?
    private var previouslyActiveApplication: NSRunningApplication?

    var isPresented: Bool {
        !panels.isEmpty
    }

    /// Presents the reminder above normal windows and full-screen apps.
    ///
    /// `onDismiss` is called for user-originated dismissal (including Escape and Join), while
    /// `onSnooze` is called for Snooze. Calling `dismiss()` programmatically never invokes either
    /// callback, which makes it safe for coordinators to call from inside those callbacks.
    func show(
        event: CalendarEventItem,
        snoozeMinutes: Int,
        theme: NotificationTheme,
        showOnAllDisplays: Bool,
        onDismiss: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        closePanels(restoreFocus: false)

        self.onDismiss = onDismiss
        self.onSnooze = onSnooze
        previouslyActiveApplication = NSWorkspace.shared.frontmostApplication

        let targetScreens: [NSScreen]
        if showOnAllDisplays {
            targetScreens = NSScreen.screens
        } else if let mainScreen = NSScreen.main ?? NSScreen.screens.first {
            targetScreens = [mainScreen]
        } else {
            targetScreens = []
        }

        guard !targetScreens.isEmpty else {
            self.onDismiss = nil
            self.onSnooze = nil
            previouslyActiveApplication = nil
            return
        }

        panels = targetScreens.map { screen in
            makePanel(
                for: screen,
                event: event,
                snoozeMinutes: max(1, snoozeMinutes),
                theme: theme
            )
        }

        installEscapeMonitor()

        for panel in panels {
            panel.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
        primaryPanel(for: targetScreens)?.makeKeyAndOrderFront(nil)
    }

    /// Closes any visible reminder without notifying action callbacks.
    func dismiss() {
        closePanels(restoreFocus: true)
    }

    private func makePanel(
        for screen: NSScreen,
        event: CalendarEventItem,
        snoozeMinutes: Int,
        theme: NotificationTheme
    ) -> ReminderPanel {
        let panel = ReminderPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.setFrame(screen.frame, display: true)
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.escapeHandler = { [weak self] in
            self?.dismissFromUser()
        }

        let rootView = ReminderOverlayView(
            event: event,
            snoozeMinutes: snoozeMinutes,
            theme: theme,
            onJoin: { [weak self] url in
                self?.join(url)
            },
            onSnooze: { [weak self] in
                self?.snoozeFromUser()
            },
            onDismiss: { [weak self] in
                self?.dismissFromUser()
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        return panel
    }

    private func primaryPanel(for targetScreens: [NSScreen]) -> ReminderPanel? {
        guard let mainScreen = NSScreen.main,
              let mainIndex = targetScreens.firstIndex(of: mainScreen),
              panels.indices.contains(mainIndex) else {
            return panels.first
        }
        return panels[mainIndex]
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.isPresented == true else {
                return event
            }

            self?.dismissFromUser()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    private func dismissFromUser() {
        let callback = onDismiss
        closePanels(restoreFocus: true)
        callback?()
    }

    private func snoozeFromUser() {
        let callback = onSnooze
        closePanels(restoreFocus: true)
        callback?()
    }

    private func join(_ url: URL) {
        let callback = onDismiss
        closePanels(restoreFocus: false)
        NSWorkspace.shared.open(url)
        callback?()
    }

    private func closePanels(restoreFocus: Bool) {
        removeEscapeMonitor()

        let panelsToClose = panels
        panels.removeAll()
        onDismiss = nil
        onSnooze = nil

        for panel in panelsToClose {
            panel.escapeHandler = nil
            panel.orderOut(nil)
            panel.close()
        }

        let applicationToRestore = previouslyActiveApplication
        previouslyActiveApplication = nil

        if restoreFocus,
           let applicationToRestore,
           !applicationToRestore.isTerminated,
           applicationToRestore != NSRunningApplication.current {
            applicationToRestore.activate()
        }
    }
}

@MainActor
private final class ReminderPanel: NSPanel {
    var escapeHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            escapeHandler?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        escapeHandler?()
    }
}
