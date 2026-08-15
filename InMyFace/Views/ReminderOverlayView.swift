import SwiftUI

/// The full-screen presentation used by every reminder window.
///
/// The view intentionally owns no scheduling or window-management state. That keeps each
/// display in sync while `OverlayController` remains the single source of truth for actions.
@MainActor
struct ReminderOverlayView: View {
    let event: CalendarEventItem
    let snoozeMinutes: Int
    let onJoin: (URL) -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    @State private var glowIsExpanded = false

    private var accent: Color {
        Color(calendarHex: event.calendarColorHex)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentScale = min(max(proxy.size.width / 1_440, 0.78), 1.12)

            ZStack {
                background

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 38)

                        content(scale: contentScale)
                            .frame(maxWidth: 1_040)
                            .padding(.horizontal, max(32, proxy.size.width * 0.045))

                        Spacer(minLength: 38)
                    }
                    .frame(minHeight: proxy.size.height)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            if reduceMotion {
                isPresented = true
                glowIsExpanded = true
            } else {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                    isPresented = true
                }
                glowIsExpanded = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.025, green: 0.035, blue: 0.07), location: 0),
                    .init(color: Color(red: 0.045, green: 0.035, blue: 0.085), location: 0.52),
                    .init(color: Color(red: 0.015, green: 0.02, blue: 0.045), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.3))
                .frame(width: 720, height: 720)
                .blur(radius: 120)
                .offset(x: -310, y: -260)
                .scaleEffect(reduceMotion ? 1 : (glowIsExpanded ? 1.08 : 0.9))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 5.2).repeatForever(autoreverses: true),
                    value: glowIsExpanded
                )

            Circle()
                .fill(Color.indigo.opacity(0.2))
                .frame(width: 640, height: 640)
                .blur(radius: 130)
                .offset(x: 390, y: 290)
                .scaleEffect(reduceMotion ? 1 : (glowIsExpanded ? 0.92 : 1.08))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 6.4).repeatForever(autoreverses: true),
                    value: glowIsExpanded
                )

            LinearGradient(
                colors: [.white.opacity(0.045), .clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    private func content(scale: CGFloat) -> some View {
        VStack(spacing: 28 * scale) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                clockAndCountdown(now: context.date, scale: scale)
            }

            eventCard(scale: scale)
                .opacity(isPresented ? 1 : 0)
                .scaleEffect(isPresented ? 1 : 0.96)
                .offset(y: isPresented ? 0 : 18)
        }
    }

    private func clockAndCountdown(now: Date, scale: CGFloat) -> some View {
        let countdown = CountdownDisplay(now: now, startDate: event.startDate, endDate: event.endDate)

        return VStack(spacing: 14 * scale) {
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 112 * scale, weight: .thin, design: .rounded))
                .monospacedDigit()
                .tracking(-4 * scale)
                .foregroundStyle(.white)
                .shadow(color: accent.opacity(0.22), radius: 30, y: 8)
                .accessibilityLabel("Current time")

            HStack(spacing: 12 * scale) {
                Circle()
                    .fill(accent)
                    .frame(width: 9 * scale, height: 9 * scale)
                    .shadow(color: accent.opacity(0.9), radius: 8)

                Text(countdown.label.uppercased())
                    .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                    .tracking(2.4 * scale)
                    .foregroundStyle(.white.opacity(0.62))

                Text(countdown.value)
                    .font(.system(size: 30 * scale, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 11 * scale)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.11), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(countdown.label), \(countdown.accessibilityValue)")
        }
    }

    private func eventCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 25 * scale) {
            HStack(spacing: 10 * scale) {
                Circle()
                    .fill(accent)
                    .frame(width: 10 * scale, height: 10 * scale)
                    .shadow(color: accent.opacity(0.8), radius: 7)

                Text(event.calendarTitle)
                    .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 16)

                Label(timeRange, systemImage: "clock")
                    .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .labelStyle(.titleAndIcon)
            }

            Text(event.title)
                .font(.system(size: 43 * scale, weight: .bold, design: .rounded))
                .tracking(-0.9 * scale)
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .accessibilityAddTraits(.isHeader)

            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)

            actionButtons(scale: scale)

            HStack(spacing: 8 * scale) {
                Spacer()
                Text("esc")
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.horizontal, 8 * scale)
                    .padding(.vertical, 4 * scale)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6 * scale))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6 * scale)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
                Text("キーで閉じる")
                    .font(.system(size: 12 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(32 * scale)
        .background {
            RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.10), .white.opacity(0.025), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), accent.opacity(0.18), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.45), radius: 42, y: 20)
                .shadow(color: accent.opacity(0.10), radius: 52)
        }
    }

    private func actionButtons(scale: CGFloat) -> some View {
        HStack(spacing: 13 * scale) {
            Button {
                if let meetingURL = event.meetingURL {
                    onJoin(meetingURL)
                }
            } label: {
                actionLabel("Join meeting", systemImage: "video.fill", scale: scale)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(event.meetingURL == nil ? .white.opacity(0.38) : .white)
                    .background {
                        RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: event.meetingURL == nil
                                        ? [.white.opacity(0.08), .white.opacity(0.06)]
                                        : [accent, accent.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(
                        color: event.meetingURL == nil ? .clear : accent.opacity(0.32),
                        radius: 18,
                        y: 8
                    )
            }
            .buttonStyle(.plain)
            .disabled(event.meetingURL == nil)
            .keyboardShortcut(.defaultAction)
            .help(event.meetingURL == nil ? "No meeting link was found in this event" : "Open meeting link")

            Button(action: onSnooze) {
                actionLabel("Snooze \(snoozeMinutes) min", systemImage: "moon.zzz.fill", scale: scale)
                    .foregroundStyle(.white.opacity(0.9))
                    .background {
                        RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                            .fill(.white.opacity(0.09))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                                    .stroke(.white.opacity(0.10), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .help("Remind me again in \(snoozeMinutes) minutes")

            Button(action: onDismiss) {
                actionLabel("Dismiss", systemImage: "xmark", scale: scale)
                    .foregroundStyle(.white.opacity(0.72))
                    .background {
                        RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                            .fill(.white.opacity(0.055))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Dismiss reminder (Esc)")
        }
    }

    private func actionLabel(_ title: String, systemImage: String, scale: CGFloat) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 21 * scale)
            .frame(minHeight: 54 * scale)
            .contentShape(Rectangle())
    }

    private var timeRange: String {
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

private struct CountdownDisplay {
    let label: String
    let value: String
    let accessibilityValue: String

    init(now: Date, startDate: Date, endDate: Date) {
        let interval: TimeInterval

        if now < startDate {
            label = "Starts in"
            interval = startDate.timeIntervalSince(now)
            value = Self.formatted(interval)
            accessibilityValue = Self.accessibilityFormatted(interval)
        } else if now < endDate {
            label = "Started"
            interval = now.timeIntervalSince(startDate)
            value = "+" + Self.formatted(interval)
            accessibilityValue = Self.accessibilityFormatted(interval) + " ago"
        } else {
            label = "Ended"
            interval = now.timeIntervalSince(endDate)
            value = "+" + Self.formatted(interval)
            accessibilityValue = Self.accessibilityFormatted(interval) + " ago"
        }
    }

    private static func formatted(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private static func accessibilityFormatted(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        var parts: [String] = []

        if hours > 0 { parts.append("\(hours) hours") }
        if minutes > 0 { parts.append("\(minutes) minutes") }
        if remainder > 0 || parts.isEmpty { parts.append("\(remainder) seconds") }
        return parts.joined(separator: ", ")
    }
}

private extension Color {
    init(calendarHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let expanded: String

        if cleaned.count == 3 {
            expanded = cleaned.map { "\($0)\($0)" }.joined()
        } else {
            expanded = cleaned
        }

        guard let rawValue = UInt64(expanded, radix: 16), expanded.count == 6 || expanded.count == 8 else {
            self = Color(red: 0.43, green: 0.48, blue: 1)
            return
        }

        let red: Double
        let green: Double
        let blue: Double

        if expanded.count == 8 {
            red = Double((rawValue >> 24) & 0xFF) / 255
            green = Double((rawValue >> 16) & 0xFF) / 255
            blue = Double((rawValue >> 8) & 0xFF) / 255
        } else {
            red = Double((rawValue >> 16) & 0xFF) / 255
            green = Double((rawValue >> 8) & 0xFF) / 255
            blue = Double(rawValue & 0xFF) / 255
        }

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
