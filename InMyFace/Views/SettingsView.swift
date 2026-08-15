import AppKit
import EventKit
import ServiceManagement
import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var settings: AppSettings
    @ObservedObject var reminderCoordinator: ReminderCoordinator

    @State private var launchAtLogin = false
    @State private var launchAtLoginMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            hero

            TabView {
                reminderSettings
                    .tabItem { Label("通知", systemImage: "bell.fill") }

                calendarSettings
                    .tabItem { Label("カレンダー", systemImage: "calendar") }
            }
            .padding([.horizontal, .bottom], 20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            refreshLaunchAtLogin()
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("InMyFace")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("集中していても、次の予定には間に合う。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                reminderCoordinator.preview()
            } label: {
                Label("プレビュー", systemImage: "play.fill")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.indigo)
        }
        .padding(24)
    }

    private var reminderSettings: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsCard(title: "通知デザイン", systemImage: "paintpalette.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("通知の見た目を選択できます。上のプレビューボタンで全画面表示を確認できます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ForEach(NotificationTheme.allCases) { theme in
                                themeChoice(theme)
                            }
                        }
                    }
                }

                settingsCard(title: "通知タイミング", systemImage: "timer") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("予定の何分前に表示するか")
                            Spacer()
                            Text("\(settings.leadTimeMinutes)分前")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.indigo)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.leadTimeMinutes) },
                                set: { settings.leadTimeMinutes = Int($0.rounded()) }
                            ),
                            in: Double(AppSettings.leadTimeRange.lowerBound)...Double(AppSettings.leadTimeRange.upperBound),
                            step: 1
                        )
                        .tint(.indigo)

                        HStack {
                            Text("1分")
                            Spacer()
                            Text("60分")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                        HStack(spacing: 7) {
                            ForEach([1, 3, 5, 10, 15, 30], id: \.self) { minutes in
                                Button("\(minutes)分") {
                                    settings.leadTimeMinutes = minutes
                                }
                                .buttonStyle(.bordered)
                                .tint(settings.leadTimeMinutes == minutes ? .indigo : .secondary)
                            }
                        }
                    }
                }

                settingsCard(title: "通知画面", systemImage: "rectangle.inset.filled") {
                    VStack(spacing: 14) {
                        Toggle("接続中のすべてのディスプレイに表示", isOn: $settings.showOnAllDisplays)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("スヌーズ時間")
                                Text("通知画面から一時的に閉じたときの時間")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper(
                                "\(settings.snoozeMinutes)分",
                                value: $settings.snoozeMinutes,
                                in: AppSettings.snoozeRange
                            )
                            .fixedSize()
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ログイン時に起動")
                                Text("通知を逃さないため、Macへのログイン時に自動起動")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { launchAtLogin },
                                set: { shouldLaunch in
                                    updateLaunchAtLogin(shouldLaunch)
                                }
                            ))
                            .labelsHidden()
                        }

                        if let launchAtLoginMessage {
                            Text(launchAtLoginMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func themeChoice(_ theme: NotificationTheme) -> some View {
        Button {
            settings.notificationTheme = theme
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                themeSwatch(theme)
                    .frame(height: 48)

                Label(theme.displayName, systemImage: theme.systemImage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text(theme.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(minHeight: 25, alignment: .topLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(settings.notificationTheme == theme
                          ? Color.indigo.opacity(0.10)
                          : Color.primary.opacity(0.025))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        settings.notificationTheme == theme
                            ? Color.indigo.opacity(0.85)
                            : Color.primary.opacity(0.09),
                        lineWidth: settings.notificationTheme == theme ? 1.5 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if settings.notificationTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                        .background(.background, in: Circle())
                        .padding(6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("通知デザイン: \(theme.displayName)")
        .accessibilityAddTraits(settings.notificationTheme == theme ? .isSelected : [])
    }

    @ViewBuilder
    private func themeSwatch(_ theme: NotificationTheme) -> some View {
        switch theme {
        case .auroraGlass:
            ZStack {
                LinearGradient(
                    colors: [Color.indigo.opacity(0.9), Color.purple.opacity(0.65), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .frame(width: 72, height: 27)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.28)) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .smartGlass:
            ZStack {
                LinearGradient(colors: [.black.opacity(0.74), .cyan.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.035))
                    .frame(width: 76, height: 27)
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(.cyan.opacity(0.7), lineWidth: 0.7) }
                HStack { Rectangle(); Spacer(); Rectangle() }
                    .foregroundStyle(.cyan.opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .aiConcierge:
            ZStack {
                Color(red: 0.01, green: 0.04, blue: 0.065)
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Rectangle().fill(.cyan).frame(width: 16, height: 2)
                        Rectangle().fill(.cyan.opacity(0.3)).frame(height: 1)
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.cyan.opacity(0.09))
                        .frame(width: 78, height: 21)
                        .overlay { RoundedRectangle(cornerRadius: 2).stroke(.cyan.opacity(0.42), lineWidth: 0.7) }
                }
                .padding(7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var calendarSettings: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("通知対象カレンダー")
                        .font(.headline)
                    Text("オンにしたカレンダーの予定だけを通知します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("すべて選択") {
                    settings.selectedCalendarIDs = Set(calendarService.calendars.map(\.id))
                }
                Button("すべて解除") {
                    settings.selectedCalendarIDs = []
                }
            }

            Group {
                if isAuthorized {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(calendarService.calendars) { calendar in
                                calendarRow(calendar)
                            }
                        }
                        .padding(10)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text("カレンダーへのアクセスを許可してください")
                            .font(.headline)
                        if let message = calendarService.errorMessage, !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .padding(.vertical, 12)
    }

    private func calendarRow(_ calendar: CalendarDescriptor) -> some View {
        let isSelected = settings.selectedCalendarIDs.contains(calendar.id)

        return Toggle(isOn: Binding(
            get: { settings.selectedCalendarIDs.contains(calendar.id) },
            set: { isSelected in
                if isSelected {
                    settings.selectedCalendarIDs.insert(calendar.id)
                } else {
                    settings.selectedCalendarIDs.remove(calendar.id)
                }
            }
        )) {
            HStack(spacing: 11) {
                Circle()
                    .fill(Color(settingsCalendarHex: calendar.colorHex))
                    .frame(width: 11, height: 11)
                    .shadow(color: Color(settingsCalendarHex: calendar.colorHex).opacity(0.4), radius: 4)
                Text(calendar.title)
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .toggleStyle(.switch)
        .tint(.indigo)
        .accessibilityValue(isSelected ? "通知する" : "通知しない")
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.indigo.opacity(0.08) : Color.primary.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.indigo.opacity(0.22) : .clear, lineWidth: 1)
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
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

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLogin(_ shouldLaunch: Bool) {
        do {
            if shouldLaunch {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = "自動起動を変更できませんでした: \(error.localizedDescription)"
        }
        refreshLaunchAtLogin()
    }
}

private extension Color {
    init(settingsCalendarHex hex: String) {
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
