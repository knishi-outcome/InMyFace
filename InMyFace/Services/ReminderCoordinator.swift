import AppKit
import Combine
import Foundation

@MainActor
final class ReminderCoordinator: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var nextEvent: CalendarEventItem?
    @Published private(set) var nextReminderDate: Date?

    private let calendarService: CalendarService
    private let settings: AppSettings
    private let overlayController: OverlayController

    private var cachedEvents: [CalendarEventItem] = []
    private var deliveredOccurrences: [String: Date] = [:]
    private var snoozedOccurrences: [String: Date] = [:]
    private var activePresentation: ActivePresentation?
    private var scheduledReminder: ReminderCandidate?

    private var reminderTimer: Timer?
    private var periodicRefreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration: UInt64 = 0
    private var cancellables = Set<AnyCancellable>()

    private static let fetchHorizon: TimeInterval = 7 * 24 * 60 * 60
    private static let wakeGraceWindow: TimeInterval = 10 * 60
    private static let periodicRefreshInterval: TimeInterval = 15 * 60

    init(
        calendarService: CalendarService,
        settings: AppSettings,
        overlayController: OverlayController
    ) {
        self.calendarService = calendarService
        self.settings = settings
        self.overlayController = overlayController
        super.init()
    }

    func start() {
        guard !isRunning else {
            reschedule()
            return
        }

        isRunning = true
        installObservers()
        installPeriodicRefreshTimer()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await calendarService.requestAccess()
            settings.selectAllCalendarsIfNeeded(calendarService.calendars.map(\.id))
            reschedule(for: .startup)
        }
    }

    func stop() {
        isRunning = false
        refreshGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        invalidateReminderTimer()
        periodicRefreshTimer?.invalidate()
        periodicRefreshTimer = nil
        cancellables.removeAll()

        NotificationCenter.default.removeObserver(
            self,
            name: .NSSystemClockDidChange,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        overlayController.dismiss()
        activePresentation = nil
        cachedEvents = []
        nextEvent = nil
        nextReminderDate = nil
    }

    /// Refetches the next seven days and replaces the current one-shot timer.
    func reschedule() {
        reschedule(for: .routine)
    }

    /// Shows a realistic sample without requiring an upcoming calendar event.
    func preview() {
        let startDate = Date().addingTimeInterval(
            TimeInterval(settings.leadTimeMinutes * 60)
        )
        let sampleEvent = CalendarEventItem(
            id: "inmyface-preview",
            title: "プロジェクト・シンク",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(45 * 60),
            calendarTitle: "プレビュー",
            calendarColorHex: "#7C5CFC",
            meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")
        )

        preview(event: sampleEvent)
    }

    func preview(event: CalendarEventItem) {
        overlayController.dismiss()

        let token = UUID()
        activePresentation = ActivePresentation(
            token: token,
            occurrenceKey: nil
        )

        overlayController.show(
            event: event,
            snoozeMinutes: settings.snoozeMinutes,
            showOnAllDisplays: settings.showOnAllDisplays,
            onDismiss: { [weak self] in
                self?.finishPreview(token: token)
            },
            onSnooze: { [weak self] in
                self?.finishPreview(token: token)
            }
        )
    }

    private func installObservers() {
        settings.$leadTimeMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.reschedule()
            }
            .store(in: &cancellables)

        settings.$selectedCalendarIDs
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.reschedule()
            }
            .store(in: &cancellables)

        calendarService.$calendars
            .map { Set($0.map(\.id)) }
            .removeDuplicates()
            .sink { [weak self] calendarIDs in
                guard let self else { return }
                if !settings.selectAllCalendarsIfNeeded(calendarIDs) {
                    reschedule()
                }
            }
            .store(in: &cancellables)

        calendarService.$eventStoreRevision
            .dropFirst()
            .sink { [weak self] _ in
                self?.reschedule()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemClockDidChange(_:)),
            name: .NSSystemClockDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemClockDidChange(_:)),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func installPeriodicRefreshTimer() {
        periodicRefreshTimer?.invalidate()

        let timer = Timer(
            timeInterval: Self.periodicRefreshInterval,
            target: self,
            selector: #selector(periodicRefreshTimerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 60
        periodicRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func reschedule(for reason: RefreshReason) {
        guard isRunning else { return }

        refreshGeneration &+= 1
        let generation = refreshGeneration
        refreshTask?.cancel()
        invalidateReminderTimer()

        let calendarIDs = settings.selectedCalendarIDs
        guard !calendarIDs.isEmpty else {
            cachedEvents = []
            nextEvent = nil
            nextReminderDate = nil
            return
        }

        let now = Date()
        let queryStart = now.addingTimeInterval(-Self.wakeGraceWindow)
        let queryEnd = now.addingTimeInterval(Self.fetchHorizon)

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let events = await calendarService.fetchEvents(
                calendarIDs: calendarIDs,
                from: queryStart,
                to: queryEnd
            )

            guard
                !Task.isCancelled,
                isRunning,
                refreshGeneration == generation
            else {
                return
            }

            cachedEvents = events.sorted(by: Self.eventOrdering)
            pruneTrackingState(now: Date())
            scheduleNextReminder(
                allowingGrace: reason.allowsGrace,
                now: Date()
            )
        }
    }

    private func scheduleNextReminder(
        allowingGrace: Bool,
        now: Date
    ) {
        invalidateReminderTimer()

        guard isRunning, activePresentation == nil else { return }

        let leadTime = TimeInterval(settings.leadTimeMinutes * 60)
        let candidates = cachedEvents.compactMap { event -> ReminderCandidate? in
            guard event.endDate > now else { return nil }

            let key = occurrenceKey(for: event)

            if let snoozeDate = snoozedOccurrences[key] {
                guard snoozeDate < event.endDate else { return nil }
                return ReminderCandidate(
                    event: event,
                    occurrenceKey: key,
                    fireDate: max(snoozeDate, now),
                    kind: .snoozed
                )
            }

            guard deliveredOccurrences[key] == nil else { return nil }

            let reminderDate = event.startDate.addingTimeInterval(-leadTime)
            if reminderDate > now {
                return ReminderCandidate(
                    event: event,
                    occurrenceKey: key,
                    fireDate: reminderDate,
                    kind: .scheduled
                )
            }

            // If the app launches or refreshes while already inside the lead-time
            // window, an upcoming meeting is still useful and should appear now.
            if event.startDate > now {
                return ReminderCandidate(
                    event: event,
                    occurrenceKey: key,
                    fireDate: now,
                    kind: .scheduled
                )
            }

            // A wake or wall-clock change may cause a timer to be missed. Keep the
            // recovery deliberately short so an old meeting cannot take over the
            // screen much later in the day.
            if allowingGrace,
               now.timeIntervalSince(reminderDate) <= Self.wakeGraceWindow {
                return ReminderCandidate(
                    event: event,
                    occurrenceKey: key,
                    fireDate: now,
                    kind: .scheduled
                )
            }

            return nil
        }
        .sorted(by: Self.reminderOrdering)

        guard let candidate = candidates.first else {
            nextEvent = nil
            nextReminderDate = nil
            return
        }

        scheduledReminder = candidate
        nextEvent = candidate.event
        nextReminderDate = candidate.fireDate

        if candidate.fireDate <= now.addingTimeInterval(0.05) {
            handle(candidate: candidate, firedAt: now)
            return
        }

        let timer = Timer(
            fireAt: candidate.fireDate,
            interval: 0,
            target: self,
            selector: #selector(reminderTimerDidFire(_:)),
            userInfo: nil,
            repeats: false
        )
        timer.tolerance = 0
        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleReminderTimerFired() {
        reminderTimer = nil
        guard let candidate = scheduledReminder else { return }

        scheduledReminder = nil
        nextEvent = nil
        nextReminderDate = nil

        let now = Date()
        if candidate.fireDate > now.addingTimeInterval(0.5) {
            scheduleNextReminder(allowingGrace: false, now: now)
            return
        }

        handle(candidate: candidate, firedAt: now)
    }

    private func handle(
        candidate: ReminderCandidate,
        firedAt now: Date
    ) {
        scheduledReminder = nil
        nextEvent = nil
        nextReminderDate = nil

        guard isRunning, candidate.event.endDate > now else {
            scheduleNextReminder(allowingGrace: false, now: now)
            return
        }

        switch candidate.kind {
        case .scheduled:
            guard deliveredOccurrences[candidate.occurrenceKey] == nil else {
                scheduleNextReminder(allowingGrace: false, now: now)
                return
            }

            let meetingHasStarted = candidate.event.startDate <= now
            let isWithinGrace = now.timeIntervalSince(candidate.fireDate)
                <= Self.wakeGraceWindow
            guard !meetingHasStarted || isWithinGrace else {
                scheduleNextReminder(allowingGrace: false, now: now)
                return
            }
        case .snoozed:
            snoozedOccurrences.removeValue(forKey: candidate.occurrenceKey)
        }

        deliveredOccurrences[candidate.occurrenceKey] = candidate.event.startDate
        present(event: candidate.event, occurrenceKey: candidate.occurrenceKey)
    }

    private func present(event: CalendarEventItem, occurrenceKey: String) {
        let token = UUID()
        let snoozeMinutes = settings.snoozeMinutes
        activePresentation = ActivePresentation(
            token: token,
            occurrenceKey: occurrenceKey
        )

        overlayController.show(
            event: event,
            snoozeMinutes: snoozeMinutes,
            showOnAllDisplays: settings.showOnAllDisplays,
            onDismiss: { [weak self] in
                self?.dismiss(event: event, token: token)
            },
            onSnooze: { [weak self] in
                self?.snooze(
                    event: event,
                    token: token,
                    minutes: snoozeMinutes
                )
            }
        )
    }

    private func dismiss(event: CalendarEventItem, token: UUID) {
        guard activePresentation?.token == token else { return }

        overlayController.dismiss()
        activePresentation = nil
        snoozedOccurrences.removeValue(forKey: occurrenceKey(for: event))
        scheduleNextReminder(allowingGrace: false, now: Date())
    }

    private func snooze(
        event: CalendarEventItem,
        token: UUID,
        minutes: Int
    ) {
        guard activePresentation?.token == token else { return }

        overlayController.dismiss()
        activePresentation = nil

        let key = occurrenceKey(for: event)
        let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        if snoozeDate < event.endDate {
            snoozedOccurrences[key] = snoozeDate
        }

        scheduleNextReminder(allowingGrace: false, now: Date())
    }

    private func finishPreview(token: UUID) {
        guard activePresentation?.token == token else { return }
        overlayController.dismiss()
        activePresentation = nil
        scheduleNextReminder(allowingGrace: false, now: Date())
    }

    private func invalidateReminderTimer() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        scheduledReminder = nil
        nextEvent = nil
        nextReminderDate = nil
    }

    private func pruneTrackingState(now: Date) {
        let oldestRetainedStart = now.addingTimeInterval(-24 * 60 * 60)
        deliveredOccurrences = deliveredOccurrences.filter {
            $0.value >= oldestRetainedStart
        }

        let currentKeys = Set(cachedEvents.map(occurrenceKey(for:)))
        snoozedOccurrences = snoozedOccurrences.filter {
            currentKeys.contains($0.key)
        }
    }

    private func occurrenceKey(for event: CalendarEventItem) -> String {
        let start = event.startDate.timeIntervalSinceReferenceDate.bitPattern
        return "\(event.id)|\(start)"
    }

    private static func eventOrdering(
        _ lhs: CalendarEventItem,
        _ rhs: CalendarEventItem
    ) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
        }
        if lhs.endDate != rhs.endDate {
            return lhs.endDate < rhs.endDate
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func reminderOrdering(
        _ lhs: ReminderCandidate,
        _ rhs: ReminderCandidate
    ) -> Bool {
        if lhs.fireDate != rhs.fireDate {
            return lhs.fireDate < rhs.fireDate
        }
        return eventOrdering(lhs.event, rhs.event)
    }

    @objc nonisolated private func reminderTimerDidFire(_ timer: Timer) {
        Task { @MainActor [weak self] in
            self?.handleReminderTimerFired()
        }
    }

    @objc nonisolated private func periodicRefreshTimerDidFire(_ timer: Timer) {
        Task { @MainActor [weak self] in
            self?.reschedule(for: .routine)
        }
    }

    @objc nonisolated private func workspaceDidWake(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.reschedule(for: .wake)
        }
    }

    @objc nonisolated private func systemClockDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.reschedule(for: .clockChange)
        }
    }

    private struct ActivePresentation {
        let token: UUID
        let occurrenceKey: String?
    }

    private struct ReminderCandidate {
        let event: CalendarEventItem
        let occurrenceKey: String
        let fireDate: Date
        let kind: ReminderKind
    }

    private enum ReminderKind {
        case scheduled
        case snoozed
    }

    private enum RefreshReason {
        case routine
        case startup
        case wake
        case clockChange

        var allowsGrace: Bool {
            switch self {
            case .routine:
                return false
            case .startup, .wake, .clockChange:
                return true
            }
        }
    }
}
