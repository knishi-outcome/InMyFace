import AppKit
import Combine
import EventKit
import Foundation

@MainActor
final class CalendarService: NSObject, ObservableObject {
    @Published private(set) var authorizationState: EKAuthorizationStatus
    @Published private(set) var calendars: [CalendarDescriptor] = []
    @Published private(set) var errorMessage: String?

    /// Increments whenever EventKit reports that its store changed. Consumers can
    /// observe `$eventStoreRevision` to refresh or reschedule their own state.
    @Published private(set) var eventStoreRevision: UInt64 = 0

    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        authorizationState = EKEventStore.authorizationStatus(for: .event)

        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreDidChange(_:)),
            name: .EKEventStoreChanged,
            object: eventStore
        )

        if hasReadAccess {
            reloadCalendars()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestAccess() async {
        errorMessage = nil
        refreshAuthorizationState()

        if hasReadAccess {
            reloadCalendars()
            return
        }

        guard authorizationState == .notDetermined else {
            calendars = []
            errorMessage = authorizationErrorMessage(for: authorizationState)
            return
        }

        do {
            _ = try await eventStore.requestFullAccessToEvents()
            refreshAuthorizationState()

            if hasReadAccess {
                reloadCalendars()
            } else {
                calendars = []
                errorMessage = authorizationErrorMessage(for: authorizationState)
            }
        } catch {
            refreshAuthorizationState()
            calendars = []
            errorMessage = "カレンダーへのアクセスを許可できませんでした: \(error.localizedDescription)"
        }
    }

    func reloadCalendars() {
        refreshAuthorizationState()

        guard hasReadAccess else {
            calendars = []
            return
        }

        calendars = eventStore.calendars(for: .event)
            .map { calendar in
                CalendarDescriptor(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: Self.colorHex(for: calendar)
                )
            }
            .sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    func fetchEvents(
        calendarIDs: Set<String>,
        from startDate: Date,
        to endDate: Date
    ) async -> [CalendarEventItem] {
        errorMessage = nil
        refreshAuthorizationState()

        guard hasReadAccess else {
            errorMessage = authorizationErrorMessage(for: authorizationState)
            return []
        }

        guard startDate < endDate, !calendarIDs.isEmpty else {
            return []
        }

        let selectedCalendars = eventStore.calendars(for: .event).filter {
            calendarIDs.contains($0.calendarIdentifier)
        }

        guard !selectedCalendars.isEmpty else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .map(Self.makeEventItem)
            .sorted {
                if $0.startDate != $1.startDate {
                    return $0.startDate < $1.startDate
                }
                if $0.endDate != $1.endDate {
                    return $0.endDate < $1.endDate
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    @objc nonisolated private func eventStoreDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            reloadCalendars()
            eventStoreRevision &+= 1
        }
    }

    private var hasReadAccess: Bool {
        switch authorizationState {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    private func refreshAuthorizationState() {
        authorizationState = EKEventStore.authorizationStatus(for: .event)
    }

    private func authorizationErrorMessage(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return "カレンダーへのアクセスが拒否されています。システム設定の「プライバシーとセキュリティ」から許可してください。"
        case .restricted:
            return "このMacではカレンダーへのアクセスが制限されています。"
        case .writeOnly:
            return "予定を読み取るには、カレンダーへのフルアクセスが必要です。"
        case .notDetermined:
            return "予定を読み取るには、カレンダーへのアクセスを許可してください。"
        case .fullAccess, .authorized:
            return ""
        @unknown default:
            return "カレンダーへのアクセス状態を確認できませんでした。"
        }
    }

    private static func makeEventItem(from event: EKEvent) -> CalendarEventItem {
        CalendarEventItem(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? "名称未設定の予定",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarTitle: event.calendar.title,
            calendarColorHex: colorHex(for: event.calendar),
            meetingURL: meetingURL(for: event)
        )
    }

    private static func meetingURL(for event: EKEvent) -> URL? {
        var candidates: [URL] = []

        if let eventURL = event.url, eventURL.scheme?.lowercased() == "https" {
            candidates.append(eventURL)
        }

        for text in [event.notes, event.location].compactMap({ $0 }) {
            candidates.append(contentsOf: secureURLs(in: text))
        }

        // Calendar invitations can be sent by untrusted people. Only surface
        // links from meeting providers we explicitly recognize so the prominent
        // Join button cannot be used to disguise an arbitrary phishing URL.
        return candidates.first(where: isKnownMeetingURL)
    }

    private static func secureURLs(in text: String) -> [URL] {
        guard
            !text.isEmpty,
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            )
        else {
            return []
        }

        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: searchRange)
            .compactMap(\.url)
            .filter { $0.scheme?.lowercased() == "https" }
    }

    private static func isKnownMeetingURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        return host == "meet.google.com"
            || host == "teams.microsoft.com"
            || host == "teams.live.com"
            || host.hasSuffix(".zoom.us")
            || host.hasSuffix(".webex.com")
            || host.hasSuffix(".whereby.com")
    }

    private static func colorHex(for calendar: EKCalendar) -> String {
        guard
            let calendarColor = calendar.cgColor,
            let color = NSColor(cgColor: calendarColor)?.usingColorSpace(.sRGB)
        else {
            return "#5E5CE6"
        }

        let red = channelByte(color.redComponent)
        let green = channelByte(color.greenComponent)
        let blue = channelByte(color.blueComponent)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func channelByte(_ value: CGFloat) -> Int {
        Int((min(max(value, 0), 1) * 255).rounded())
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
