import Foundation

struct CalendarDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let colorHex: String
}

struct CalendarEventItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColorHex: String
    let meetingURL: URL?
}
