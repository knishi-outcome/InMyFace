import AppKit
import EventKit
import SwiftUI

@MainActor
struct MenuBarView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var settings: AppSettings
    @ObservedObject var reminderCoordinator: ReminderCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.45)
            statusContent
                .padding(16)
            Divider().opacity(0.45)
            actions
                .padding(10)
        }
        .frame(width: 350)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("InMyFace")
                    .font(.headline)
                Text("次の予定を見逃さない")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(isAuthorized ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: (isAuthorized ? Color.green : Color.orange).opacity(0.55), radius: 5)
                .help(isAuthorized ? "カレンダー接続済み" : "カレンダーの許可が必要です")
        }
        .padding(14)
    }

    @ViewBuilder
    private var statusContent: some View {
        if !isAuthorized {
            VStack(alignment: .leading, spacing: 10) {
                Label("カレンダーへのアクセスが必要です", systemImage: "calendar.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold))

                if let message = calendarService.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if calendarService.authorizationState == .notDetermined {
                    Button("アクセスを許可") {
                        Task {
                            await calendarService.requestAccess()
                            settings.selectAllCalendarsIfNeeded(calendarService.calendars.map(\.id))
                            reminderCoordinator.reschedule()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else if settings.selectedCalendarIDs.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("通知するカレンダーが未選択です", systemImage: "calendar.badge.minus")
                    .font(.subheadline.weight(.semibold))
                Text("設定から1つ以上選んでください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let event = reminderCoordinator.nextEvent {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(menuCalendarHex: event.calendarColorHex))
                        .frame(width: 8, height: 8)
                    Text(event.calendarTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(event.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                HStack {
                    Label(event.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    Spacer()
                    if let reminderDate = reminderCoordinator.nextReminderDate {
                        Text("通知 \(reminderDate.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 7) {
                Label("準備完了", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Text("今後7日間に通知対象の予定はありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 4) {
            Button {
                reminderCoordinator.preview()
            } label: {
                Label("通知画面をプレビュー", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuActionButtonStyle())

            SettingsLink {
                Label("設定…", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuActionButtonStyle())

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("InMyFaceを終了", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuActionButtonStyle())
        }
    }

    private var isAuthorized: Bool {
        switch calendarService.authorizationState {
        case .authorized, .fullAccess:
            return true
        default:
            return false
        }
    }
}

private struct MenuActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.09) : .clear)
            )
            .contentShape(Rectangle())
    }
}

private extension Color {
    init(menuCalendarHex hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = UInt64(clean, radix: 16) else {
            self = .indigo
            return
        }
        self = Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
