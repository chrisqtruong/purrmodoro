import Foundation
import Observation
import SwiftData
import WidgetKit

/// The timer's brain. Counts down to an end date (rather than ticking a counter),
/// so it stays accurate while the phone is locked or the app is closed.
@MainActor
@Observable
final class TimerEngine {
    private(set) var snap: TimerSnapshot

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var ticker: Task<Void, Never>?

    /// The running app's timer, so lock screen buttons can reach it.
    static weak var shared: TimerEngine?

    init(context: ModelContext) {
        self.context = context
        self.snap = SharedStore.load()
        refresh()
        Self.shared = self
    }

    /// For a lock screen button tap when the app isn't otherwise running.
    static func standalone() -> TimerEngine {
        let container = try! ModelContainer(for: FocusSession.self, DayNote.self)
        return TimerEngine(context: container.mainContext)
    }

    // MARK: Actions

    func choosePreset(_ minutes: Int) {
        guard snap.run == .idle, snap.focusMinutes != minutes else { return }
        snap.focusMinutes = minutes
        SoundPlayer.shared.play(.tick)
        Haptics.select()
        save()
    }

    /// Saves her presets and break lengths, and selects the preset she was just editing.
    func setTimes(presets: [Int], selected: Int, shortBreak: Int, longBreak: Int, longBreakEvery: Int) {
        guard snap.run == .idle else { return }
        snap.presets = presets
        snap.focusMinutes = selected
        snap.shortBreakMinutes = shortBreak
        snap.longBreakMinutes = longBreak
        snap.longBreakEvery = longBreakEvery
        Haptics.success()
        save()
    }

    /// A one-off focus length from winding the clock (doesn't change her presets).
    func setWoundTime(_ minutes: Int) {
        guard snap.run == .idle else { return }
        snap.focusMinutes = minutes
        SoundPlayer.shared.play(.pop)
        Haptics.success()
        save()
    }

    func startFocus() {
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-noPermissionPrompt") { Notifications.requestPermission() }
        #else
        Notifications.requestPermission()
        #endif
        snap.phase = .focus
        snap.sessionStart = .now
        snap.wasPaused = false
        begin(remaining: snap.duration)
    }

    func startBreak() {
        snap.phase = snap.nextBreak
        begin(remaining: snap.duration)
    }

    func skipBreak() { reset() }

    func finishForNow() { reset() }

    func pause() {
        guard case .running(let end) = snap.run else { return }
        snap.run = .paused(remaining: max(1, end.timeIntervalSinceNow))
        if snap.phase == .focus { snap.wasPaused = true }
        stopTicker()
        Notifications.cancel()
        LiveActivityController.show(activityState, stale: nil)
        Haptics.tap()
        save()
    }

    func resume() {
        guard case .paused(let remaining) = snap.run else { return }
        begin(remaining: remaining)
    }

    /// Stops early. Partial focus still counts toward her time if it lasted a minute or more.
    func stop() {
        if snap.phase == .focus, let start = snap.sessionStart {
            let elapsed = snap.duration - snap.remaining(at: .now)
            if elapsed >= 60 { record(start: start, seconds: Int(elapsed), deep: false, completed: false) }
        }
        reset()
    }

    /// Catches up after the app was in the background.
    func refresh(now: Date = .now) {
        guard case .running(let end) = snap.run else { return }
        if now >= end {
            complete(endedAt: end, live: now.timeIntervalSince(end) < 2)
        } else {
            startTicker()
        }
    }

    // MARK: Internals

    private func begin(remaining: TimeInterval) {
        let end = Date.now.addingTimeInterval(remaining)
        snap.run = .running(end: end)
        snap.phaseStart = end.addingTimeInterval(-snap.duration)
        let upcoming = snap.completedInCycle + 1 >= snap.longBreakEvery
            ? snap.longBreakMinutes : snap.shortBreakMinutes
        Notifications.schedule(at: end, finishing: snap.phase, nextBreakMinutes: upcoming)
        LiveActivityController.show(activityState, stale: end)
        SoundPlayer.shared.play(.pop)
        Haptics.tap()
        startTicker()
        save()
    }

    private func complete(endedAt end: Date, live: Bool) {
        stopTicker()
        if snap.phase == .focus {
            record(start: snap.sessionStart ?? end.addingTimeInterval(-snap.duration),
                   seconds: Int(snap.duration), deep: !snap.wasPaused, completed: true)
            snap.completedInCycle += 1
        } else if snap.phase == .longBreak {
            snap.completedInCycle = 0
        }
        snap.run = .finished
        snap.sessionStart = nil
        LiveActivityController.endAll()
        if live {
            SoundPlayer.shared.play(snap.phase == .focus ? .chime : .chimeLow)
            Haptics.success()
        }
        save()
    }

    private func reset() {
        // Ending a long break early, or skipping one she'd earned, starts a fresh set of paws.
        let skippedLong = snap.run == .finished && snap.phase == .focus && snap.nextBreak == .longBreak
        if snap.phase == .longBreak || skippedLong { snap.completedInCycle = 0 }
        snap.phase = .focus
        snap.run = .idle
        snap.sessionStart = nil
        snap.phaseStart = nil
        stopTicker()
        Notifications.cancel()
        LiveActivityController.endAll()
        Haptics.tap()
        save()
    }

    private func record(start: Date, seconds: Int, deep: Bool, completed: Bool) {
        context.insert(FocusSession(start: start, seconds: seconds, deep: deep, completed: completed))
        try? context.save()
        let today = TimerSnapshot.dayKey(.now)
        if snap.tallyDay != today {
            snap.tallyDay = today
            snap.tallySeconds = 0
            snap.tallySessions = 0
            snap.completedInCycle = 0
        }
        snap.tallySeconds += seconds
        if completed { snap.tallySessions += 1 }
    }

    private var activityState: TimerActivityAttributes.ContentState {
        var end = Date.now
        var paused: TimeInterval?
        switch snap.run {
        case .running(let e): end = e
        case .paused(let r): paused = r; end = .now.addingTimeInterval(r)
        default: break
        }
        return .init(phase: snap.phase, minutes: snap.minutes(of: snap.phase),
                     start: end.addingTimeInterval(-snap.duration), end: end, pausedRemaining: paused)
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                if case .running(let end) = self.snap.run, Date.now >= end {
                    self.complete(endedAt: end, live: true)
                    return
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func save() {
        SharedStore.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
