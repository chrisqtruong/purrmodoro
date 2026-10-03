import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PurrmodoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        KittyWidget()
        FocusLiveActivity()
    }
}

// MARK: - Home & lock screen widget

struct KittyEntry: TimelineEntry {
    let date: Date
    let snap: TimerSnapshot
}

struct KittyProvider: TimelineProvider {
    func placeholder(in context: Context) -> KittyEntry {
        KittyEntry(date: .now, snap: TimerSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (KittyEntry) -> Void) {
        completion(KittyEntry(date: .now, snap: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KittyEntry>) -> Void) {
        let snap = SharedStore.load()
        let now = Date.now
        var entries = [KittyEntry(date: now, snap: snap)]
        // Flip to the "done" look the moment the countdown ends.
        if case .running(let end) = snap.run, end > now {
            entries.append(KittyEntry(date: end, snap: snap))
        }
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }
}

struct KittyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KittyWidget", provider: KittyProvider()) { entry in
            KittyWidgetView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Focus Kitty")
        .description("Your timer and today's focus.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct KittyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KittyEntry

    var body: some View {
        let snap = entry.snap.resolved(at: entry.date)
        let tally = snap.tally(on: entry.date)
        switch family {
        case .accessoryCircular:
            circular(snap, tally)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(headline(snap), systemImage: "pawprint.fill")
                    .font(.rounded(.headline, weight: .bold))
                if snap.run == .idle || snap.run == .finished {
                    Text("\(tally.sessions) sessions · \(Format.duration(tally.seconds))")
                        .font(.rounded(.subheadline))
                } else {
                    TimerText(snap: snap)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 16) {
                KittyView(mood: snap.mood, animated: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline(snap))
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                    TimerText(snap: snap)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    TallyLine(tally: tally)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                KittyView(mood: snap.mood, animated: false)
                    .frame(width: 68, height: 68)
                Spacer(minLength: 0)
                Text(headline(snap))
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                TimerText(snap: snap)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                TallyLine(tally: tally)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func circular(_ snap: TimerSnapshot, _ tally: (seconds: Int, sessions: Int)) -> some View {
        if case .running(let end) = snap.run, let start = snap.phaseStart, start < end {
            ProgressView(timerInterval: start...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: snap.phase == .focus ? "pawprint.fill" : "cup.and.saucer.fill")
            }
            .progressViewStyle(.circular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "pawprint.fill").font(.system(size: 14))
                    Text("\(tally.sessions)").font(.rounded(.title3, weight: .bold))
                }
            }
        }
    }

    private func headline(_ snap: TimerSnapshot) -> String {
        switch (snap.run, snap.phase) {
        case (.idle, _): return "Ready to focus"
        case (.paused, _): return "Paused"
        case (.running, .focus): return "Focusing"
        case (.running, _): return "On a break"
        case (.finished, .focus): return "Break time!"
        case (.finished, _): return "Ready to focus?"
        }
    }
}

private struct TimerText: View {
    let snap: TimerSnapshot

    var body: some View {
        switch snap.run {
        case .running(let end):
            if let start = snap.phaseStart, start < end {
                Text(timerInterval: start...end, countsDown: true).monospacedDigit()
            } else {
                Text(end, style: .timer).monospacedDigit()
            }
        case .paused(let remaining):
            Text(Format.clock(remaining)).monospacedDigit()
        case .idle:
            Text(Format.clock(snap.duration)).monospacedDigit()
        case .finished:
            Text("Done!")
        }
    }
}

private struct TallyLine: View {
    let tally: (seconds: Int, sessions: Int)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "pawprint.fill").foregroundStyle(Theme.caramel)
            Text(tally.seconds > 0 ? "\(tally.sessions) · \(Format.duration(tally.seconds))" : "Nothing yet today")
        }
        .font(.rounded(.caption, weight: .semibold))
        .foregroundStyle(Theme.inkSoft)
    }
}

// MARK: - Live Activity (lock screen + Dynamic Island)

private extension TimerActivityAttributes.ContentState {
    func mood(stale: Bool) -> KittyMood {
        if stale { return .happy }
        if pausedRemaining != nil { return .idle }
        return phase == .focus ? .focus : .rest
    }

    func headline(stale: Bool) -> String {
        if stale { return phase == .focus ? "Focus done!" : "Break's over" }
        if pausedRemaining != nil { return "Paused" }
        return phase == .focus ? "Focusing" : "Stretch break"
    }

    func subtitle(stale: Bool) -> String {
        if stale { return phase == .focus ? "Tap to start your break" : "Tap when you're ready" }
        if pausedRemaining != nil { return "Whenever you're ready" }
        return phase == .focus ? "\(minutes)-minute session" : "\(minutes)-minute break"
    }

    var accent: Color { Theme.accent(for: phase) }
}

private struct ActivityTimerText: View {
    let state: TimerActivityAttributes.ContentState
    let stale: Bool

    var body: some View {
        if stale {
            Text("Done")
        } else if let remaining = state.pausedRemaining {
            Text(Format.clock(remaining)).monospacedDigit()
        } else {
            Text(timerInterval: state.start...state.end, countsDown: true).monospacedDigit()
        }
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            let state = context.state
            let stale = context.isStale
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // When she pauses or resumes, the kitty slides into her new pose.
                    KittyView(mood: state.mood(stale: stale), animated: false)
                        .frame(width: 56, height: 56)
                        .id(state.pausedRemaining == nil ? "going" : "paused")
                        .transition(.push(from: .bottom))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.headline(stale: stale))
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                        ActivityTimerText(state: state, stale: stale)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    if !stale { ActivityControls(state: state) }
                }
                if !stale && state.pausedRemaining == nil {
                    ProgressView(timerInterval: state.start...state.end, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(state.accent)
                }
            }
            .padding(16)
            .activityBackgroundTint(Theme.background)
            .activitySystemActionForegroundColor(Theme.ink)
        } dynamicIsland: { context in
            let state = context.state
            let stale = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    KittyView(mood: state.mood(stale: stale), animated: false)
                        .frame(width: 60, height: 60)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityTimerText(state: state, stale: stale)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(state.accent)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110, alignment: .trailing)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.headline(stale: stale))
                        .font(.rounded(.headline, weight: .bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(state.subtitle(stale: stale))
                            .font(.rounded(.subheadline))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !stale { ActivityControls(state: state) }
                    }
                }
            } compactLeading: {
                KittyView(mood: state.mood(stale: stale), animated: false, headOnly: true)
                    .frame(width: 26, height: 26)
            } compactTrailing: {
                ActivityTimerText(state: state, stale: stale)
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(state.accent)
                    .frame(width: 44)
            } minimal: {
                KittyView(mood: state.mood(stale: stale), animated: false, headOnly: true)
                    .frame(width: 24, height: 24)
            }
            .keylineTint(state.accent)
        }
    }
}

/// Pause / resume and end buttons, like the Clock app's timer.
private struct ActivityControls: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            if state.pausedRemaining != nil {
                Button(intent: ResumeTimerIntent()) { circle("play.fill", filled: true) }
                    .accessibilityLabel("Resume")
            } else {
                Button(intent: PauseTimerIntent()) { circle("pause.fill", filled: true) }
                    .accessibilityLabel("Pause")
            }
            Button(intent: StopTimerIntent()) { circle("xmark", filled: false) }
                .accessibilityLabel("End session")
        }
        .buttonStyle(.plain)
    }

    private func circle(_ symbol: String, filled: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(filled ? Color.white : Theme.ink)
            .frame(width: 44, height: 44)
            .background(Circle().fill(filled ? state.accent : Theme.track))
    }
}
