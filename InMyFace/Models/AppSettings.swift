import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let leadTimeRange = 1...60
    static let snoozeRange = 1...15

    @Published var leadTimeMinutes: Int {
        didSet {
            let clampedValue = Self.clamp(
                leadTimeMinutes,
                to: Self.leadTimeRange
            )
            guard clampedValue == leadTimeMinutes else {
                leadTimeMinutes = clampedValue
                return
            }

            defaults.set(clampedValue, forKey: Keys.leadTimeMinutes)
        }
    }

    @Published var snoozeMinutes: Int {
        didSet {
            let clampedValue = Self.clamp(
                snoozeMinutes,
                to: Self.snoozeRange
            )
            guard clampedValue == snoozeMinutes else {
                snoozeMinutes = clampedValue
                return
            }

            defaults.set(clampedValue, forKey: Keys.snoozeMinutes)
        }
    }

    @Published var selectedCalendarIDs: Set<String> {
        didSet {
            let sanitizedIDs = Set(selectedCalendarIDs.filter { !$0.isEmpty })
            guard sanitizedIDs == selectedCalendarIDs else {
                selectedCalendarIDs = sanitizedIDs
                return
            }

            defaults.set(sanitizedIDs.sorted(), forKey: Keys.selectedCalendarIDs)
            markCalendarSelectionInitialized()
        }
    }

    @Published var showOnAllDisplays: Bool {
        didSet {
            defaults.set(showOnAllDisplays, forKey: Keys.showOnAllDisplays)
        }
    }

    /// Distinguishes a deliberate empty selection from the first launch, when no
    /// calendar list was available yet.
    @Published private(set) var hasInitializedCalendarSelection: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedLeadTime = defaults.object(forKey: Keys.leadTimeMinutes) as? NSNumber
        leadTimeMinutes = Self.clamp(
            storedLeadTime?.intValue ?? 5,
            to: Self.leadTimeRange
        )

        let storedSnoozeTime = defaults.object(forKey: Keys.snoozeMinutes) as? NSNumber
        snoozeMinutes = Self.clamp(
            storedSnoozeTime?.intValue ?? 5,
            to: Self.snoozeRange
        )

        selectedCalendarIDs = Set(
            defaults.stringArray(forKey: Keys.selectedCalendarIDs) ?? []
        )

        if defaults.object(forKey: Keys.showOnAllDisplays) == nil {
            // Avoid exposing event titles on a shared or presentation display
            // until the user explicitly opts in.
            showOnAllDisplays = false
        } else {
            showOnAllDisplays = defaults.bool(forKey: Keys.showOnAllDisplays)
        }

        hasInitializedCalendarSelection = defaults.bool(
            forKey: Keys.hasInitializedCalendarSelection
        )
    }

    /// Selects every available calendar exactly once, after EventKit returns its
    /// first non-empty calendar list. Later empty selections are kept as an
    /// intentional user choice.
    @discardableResult
    func selectAllCalendarsIfNeeded<S: Sequence>(
        _ availableCalendarIDs: S
    ) -> Bool where S.Element == String {
        guard !hasInitializedCalendarSelection else { return false }

        let calendarIDs = Set(availableCalendarIDs.filter { !$0.isEmpty })
        guard !calendarIDs.isEmpty else { return false }

        selectedCalendarIDs = calendarIDs
        return true
    }

    /// A descriptive alias useful at calendar-loading call sites.
    @discardableResult
    func initializeCalendarSelectionIfNeeded<S: Sequence>(
        availableCalendarIDs: S
    ) -> Bool where S.Element == String {
        selectAllCalendarsIfNeeded(availableCalendarIDs)
    }

    private func markCalendarSelectionInitialized() {
        guard !hasInitializedCalendarSelection else { return }
        hasInitializedCalendarSelection = true
        defaults.set(true, forKey: Keys.hasInitializedCalendarSelection)
    }

    private static func clamp(
        _ value: Int,
        to range: ClosedRange<Int>
    ) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private enum Keys {
        static let leadTimeMinutes = "settings.leadTimeMinutes"
        static let snoozeMinutes = "settings.snoozeMinutes"
        static let selectedCalendarIDs = "settings.selectedCalendarIDs"
        static let showOnAllDisplays = "settings.showOnAllDisplays"
        static let hasInitializedCalendarSelection =
            "settings.hasInitializedCalendarSelection"
    }
}
