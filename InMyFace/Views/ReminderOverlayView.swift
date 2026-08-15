import SwiftUI

/// The full-screen presentation used by every reminder window.
///
/// The view intentionally owns no scheduling or window-management state. That keeps each
/// display in sync while `OverlayController` remains the single source of truth for actions.
@MainActor
struct ReminderOverlayView: View {
    let event: CalendarEventItem
    let snoozeMinutes: Int
    let theme: NotificationTheme
    let onJoin: (URL) -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    @State private var glowIsExpanded = false

    private var accent: Color {
        switch theme {
        case .auroraGlass:
            Color(calendarHex: event.calendarColorHex)
        case .smartGlass:
            Color(red: 0.38, green: 0.96, blue: 0.91)
        case .aiConcierge:
            Color(red: 0.23, green: 0.76, blue: 1)
        }
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

    @ViewBuilder
    private var background: some View {
        switch theme {
        case .auroraGlass:
            auroraBackground
        case .smartGlass:
            smartGlassBackground
        case .aiConcierge:
            aiConciergeBackground
        }
    }

    private var auroraBackground: some View {
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

    private var smartGlassBackground: some View {
        ZStack {
            Color.black.opacity(0.12)

            LinearGradient(
                colors: [accent.opacity(0.045), .clear, Color.black.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Path { path in
                    let inset: CGFloat = 34
                    let length: CGFloat = 82
                    path.move(to: CGPoint(x: inset, y: inset + length))
                    path.addLine(to: CGPoint(x: inset, y: inset))
                    path.addLine(to: CGPoint(x: inset + length, y: inset))
                    path.move(to: CGPoint(x: proxy.size.width - inset - length, y: inset))
                    path.addLine(to: CGPoint(x: proxy.size.width - inset, y: inset))
                    path.addLine(to: CGPoint(x: proxy.size.width - inset, y: inset + length))
                    path.move(to: CGPoint(x: inset, y: proxy.size.height - inset - length))
                    path.addLine(to: CGPoint(x: inset, y: proxy.size.height - inset))
                    path.addLine(to: CGPoint(x: inset + length, y: proxy.size.height - inset))
                    path.move(to: CGPoint(x: proxy.size.width - inset - length, y: proxy.size.height - inset))
                    path.addLine(to: CGPoint(x: proxy.size.width - inset, y: proxy.size.height - inset))
                    path.addLine(to: CGPoint(x: proxy.size.width - inset, y: proxy.size.height - inset - length))
                }
                .stroke(accent.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            }
        }
        .accessibilityHidden(true)
    }

    private var aiConciergeBackground: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.015, green: 0.035, blue: 0.055).opacity(0.97), location: 0),
                    .init(color: Color(red: 0.012, green: 0.018, blue: 0.035).opacity(0.96), location: 0.62),
                    .init(color: .black.opacity(0.98), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GridPattern(spacing: 48)
                .stroke(accent.opacity(0.055), lineWidth: 0.7)

            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 580, height: 580)
                .blur(radius: 135)
                .offset(x: -420, y: -300)

            LinearGradient(
                colors: [.clear, accent.opacity(0.12), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .offset(y: -170)
        }
        .accessibilityHidden(true)
    }

    private func content(scale: CGFloat) -> some View {
        VStack(spacing: 28 * scale) {
            VStack(spacing: 20 * scale) {
                interfaceHeader(scale: scale)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    clockAndCountdown(now: context.date, scale: scale)
                }
            }
            .padding(.horizontal, theme == .smartGlass ? 24 * scale : 0)
            .padding(.vertical, theme == .smartGlass ? 20 * scale : 0)
            .background {
                if theme == .smartGlass {
                    let shape = RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    shape
                        .fill(.ultraThinMaterial.opacity(0.78))
                        .overlay { shape.fill(Color.black.opacity(0.24)) }
                        .overlay { shape.stroke(accent.opacity(0.28), lineWidth: 0.8) }
                        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
                }
            }

            eventCard(scale: scale)
                .opacity(isPresented ? 1 : 0)
                .scaleEffect(isPresented ? 1 : 0.96)
                .offset(y: isPresented ? 0 : 18)
        }
    }

    @ViewBuilder
    private func interfaceHeader(scale: CGFloat) -> some View {
        switch theme {
        case .auroraGlass:
            EmptyView()
        case .smartGlass:
            HStack(spacing: 10 * scale) {
                Image(systemName: "viewfinder")
                Text("CALENDAR FOCUS")
                    .tracking(2.4 * scale)
                Spacer()
                Text("LIVE")
                Circle().fill(accent).frame(width: 5 * scale, height: 5 * scale)
            }
            .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
            .foregroundStyle(accent.opacity(0.78))
            .padding(.horizontal, 2)
        case .aiConcierge:
            HStack(spacing: 12 * scale) {
                Image(systemName: "waveform.path.ecg")
                Text("SCHEDULE INTELLIGENCE")
                    .tracking(2.8 * scale)
                Rectangle().fill(accent.opacity(0.35)).frame(height: 1)
                Text("PRIORITY BRIEFING")
                    .foregroundStyle(.white.opacity(0.46))
            }
            .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
            .foregroundStyle(accent)
        }
    }

    private func clockAndCountdown(now: Date, scale: CGFloat) -> some View {
        let countdown = CountdownDisplay(now: now, startDate: event.startDate, endDate: event.endDate)

        return VStack(spacing: 14 * scale) {
            Text(now, format: .dateTime.hour().minute())
                .font(clockFont(scale: scale))
                .monospacedDigit()
                .tracking(theme == .aiConcierge ? 4 * scale : -4 * scale)
                .foregroundStyle(.white)
                .shadow(color: accent.opacity(0.22), radius: 30, y: 8)
                .accessibilityLabel("Current time")

            HStack(spacing: 12 * scale) {
                Circle()
                    .fill(accent)
                    .frame(width: 9 * scale, height: 9 * scale)
                    .shadow(color: accent.opacity(0.9), radius: 8)

                Text(countdown.label.uppercased())
                    .font(.system(
                        size: 14 * scale,
                        weight: .semibold,
                        design: theme == .auroraGlass ? .rounded : .monospaced
                    ))
                    .tracking(2.4 * scale)
                    .foregroundStyle(.white.opacity(0.62))

                Text(countdown.value)
                    .font(.system(
                        size: 30 * scale,
                        weight: .semibold,
                        design: theme == .auroraGlass ? .rounded : .monospaced
                    ))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 11 * scale)
            .background(countdownBackground)
            .overlay {
                countdownBorder
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(countdown.label), \(countdown.accessibilityValue)")
        }
    }

    private func clockFont(scale: CGFloat) -> Font {
        switch theme {
        case .auroraGlass:
            .system(size: 112 * scale, weight: .thin, design: .rounded)
        case .smartGlass:
            .system(size: 104 * scale, weight: .ultraLight, design: .monospaced)
        case .aiConcierge:
            .system(size: 96 * scale, weight: .light, design: .monospaced)
        }
    }

    @ViewBuilder
    private var countdownBackground: some View {
        switch theme {
        case .auroraGlass:
            Capsule().fill(.white.opacity(0.07))
        case .smartGlass:
            RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.18))
        case .aiConcierge:
            RoundedRectangle(cornerRadius: 3).fill(accent.opacity(0.075))
        }
    }

    @ViewBuilder
    private var countdownBorder: some View {
        switch theme {
        case .auroraGlass:
            Capsule().stroke(.white.opacity(0.11), lineWidth: 1)
        case .smartGlass:
            RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.27), lineWidth: 0.8)
        case .aiConcierge:
            RoundedRectangle(cornerRadius: 3).stroke(accent.opacity(0.33), lineWidth: 1)
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
                .font(.system(
                    size: theme == .aiConcierge ? 39 * scale : 43 * scale,
                    weight: theme == .smartGlass ? .medium : .bold,
                    design: theme == .aiConcierge ? .default : .rounded
                ))
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
            eventCardBackground(scale: scale)
        }
    }

    @ViewBuilder
    private func eventCardBackground(scale: CGFloat) -> some View {
        switch theme {
        case .auroraGlass:
            let shape = RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            colors: [accent.opacity(0.10), .white.opacity(0.025), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .overlay {
                    shape.stroke(
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
        case .smartGlass:
            let shape = RoundedRectangle(cornerRadius: 13 * scale, style: .continuous)
            shape
                .fill(.ultraThinMaterial.opacity(0.52))
                .overlay { shape.fill(Color.black.opacity(0.10)) }
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.52), .white.opacity(0.13), accent.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                }
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        case .aiConcierge:
            let shape = RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
            shape
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.025, green: 0.09, blue: 0.13).opacity(0.94), .black.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.clear, accent, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 1)
                        .padding(.horizontal, 18 * scale)
                }
                .overlay { shape.stroke(accent.opacity(0.24), lineWidth: 1) }
                .shadow(color: accent.opacity(0.11), radius: 34)
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
                        RoundedRectangle(cornerRadius: actionCornerRadius(scale), style: .continuous)
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
                        RoundedRectangle(cornerRadius: actionCornerRadius(scale), style: .continuous)
                            .fill(.white.opacity(0.09))
                            .overlay {
                                RoundedRectangle(cornerRadius: actionCornerRadius(scale), style: .continuous)
                                    .stroke(secondaryActionBorder, lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .help("Remind me again in \(snoozeMinutes) minutes")

            Button(action: onDismiss) {
                actionLabel("Dismiss", systemImage: "xmark", scale: scale)
                    .foregroundStyle(.white.opacity(0.72))
                    .background {
                        RoundedRectangle(cornerRadius: actionCornerRadius(scale), style: .continuous)
                            .fill(.white.opacity(0.055))
                            .overlay {
                                RoundedRectangle(cornerRadius: actionCornerRadius(scale), style: .continuous)
                                    .stroke(secondaryActionBorder.opacity(0.78), lineWidth: 1)
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
            .font(.system(
                size: 16 * scale,
                weight: .semibold,
                design: theme == .auroraGlass ? .rounded : .monospaced
            ))
            .lineLimit(1)
            .padding(.horizontal, 21 * scale)
            .frame(minHeight: 54 * scale)
            .contentShape(Rectangle())
    }

    private func actionCornerRadius(_ scale: CGFloat) -> CGFloat {
        switch theme {
        case .auroraGlass: 15 * scale
        case .smartGlass: 7 * scale
        case .aiConcierge: 3 * scale
        }
    }

    private var secondaryActionBorder: Color {
        theme == .auroraGlass ? .white.opacity(0.10) : accent.opacity(0.24)
    }

    private var timeRange: String {
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

private struct GridPattern: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
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
