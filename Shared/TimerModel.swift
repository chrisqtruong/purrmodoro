import ActivityKit
import Foundation

enum Phase: String, Codable, Hashable {
    case focus, shortBreak, longBreak

    var isBreak: Bool { self != .focus }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

enum RunState: Codable, Equatable {
    case idle
    case running(end: Date)
    case paused(remaining: TimeInterval)
    case finished

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

/// Everything the app and widgets need to know about the timer, saved to the shared App Group.
struct TimerSnapshot: Codable, Equatable {
    static let defaultPresets = [15, 25, 45]
    /// Short, medium, and long each get their own range (and step), touching only at the edges,
    /// so they always stay in order.
    static let presetRanges: [(range: ClosedRange<Int>, step: Int)] = [(1...20, 1), (20...45, 5), (45...180, 5)]

    static func fitPreset(_ minutes: Int, slot: Int) -> Int {
        let (range, step) = presetRanges[slot]
        let snapped = Int((Double(minutes) / Double(step)).rounded()) * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }
    static let longBreakRange = 2...5

    var phase: Phase = .focus
    var run: RunState = .idle
    var focusMinutes = 25
    /// Her three go-to focus lengths, shown as chips. Editable in "Your times".
    var presets = TimerSnapshot.defaultPresets
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    /// A long break comes after this many focus sessions (instead of a short one).
    var longBreakEvery = 4
    /// When the current countdown would have started if never paused. Drives rings and live timers.
    var phaseStart: Date?
    /// When the current focus session first began, for history.
    var sessionStart: Date?
    var wasPaused = false
    var completedInCycle = 0
    // Today's tally, mirrored here so the widget can show it without the database.
    var tallyDay = ""
    var tallySeconds = 0
    var tallySessions = 0

    #if DEBUG
    /// Launch with `-fastTimer` to make each "minute" last one second while testing.
    private static let secondsPerMinute: Double = ProcessInfo.processInfo.arguments.contains("-fastTimer") ? 1 : 60
    #else
    private static let secondsPerMinute: Double = 60
    #endif

    func duration(of phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return Double(focusMinutes) * Self.secondsPerMinute
        case .shortBreak: return Double(shortBreakMinutes) * Self.secondsPerMinute
        case .longBreak: return Double(longBreakMinutes) * Self.secondsPerMinute
        }
    }

    func minutes(of phase: Phase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    var duration: TimeInterval { duration(of: phase) }

    func remaining(at now: Date) -> TimeInterval {
        switch run {
        case .idle: return duration
        case .running(let end): return max(0, end.timeIntervalSince(now))
        case .paused(let remaining): return remaining
        case .finished: return 0
        }
    }

    func progress(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }

    /// `completedInCycle` counts focus sessions since the last long break (it resets after one),
    /// so changing "long break every" never reshuffles the paws she's already earned.
    var nextBreak: Phase {
        completedInCycle >= longBreakEvery ? .longBreak : .shortBreak
    }

    /// Paw slots toward the next long break, for today: (filled, total).
    func pawProgress(on date: Date) -> (filled: Int, total: Int) {
        guard tallyDay == Self.dayKey(date) else { return (0, longBreakEvery) }
        return (min(completedInCycle, longBreakEvery), longBreakEvery)
    }

    func tally(on date: Date) -> (seconds: Int, sessions: Int) {
        tallyDay == Self.dayKey(date) ? (tallySeconds, tallySessions) : (0, 0)
    }

    /// The snapshot as it would look at `date`, treating an elapsed countdown as finished.
    func resolved(at date: Date) -> TimerSnapshot {
        var copy = self
        if case .running(let end) = run, end <= date { copy.run = .finished }
        return copy
    }

    var mood: KittyMood {
        switch run {
        case .idle: return .idle
        case .finished: return .happy
        case .paused: return .idle
        case .running: return phase == .focus ? .focus : .rest
        }
    }

    init() {}

    /// Tolerant decoding: fields added in later versions fall back to defaults
    /// instead of wiping her saved timer after an update.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TimerSnapshot()
        phase = try c.decodeIfPresent(Phase.self, forKey: .phase) ?? d.phase
        run = try c.decodeIfPresent(RunState.self, forKey: .run) ?? d.run
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        presets = try c.decodeIfPresent([Int].self, forKey: .presets) ?? d.presets
        if presets.count != 3 { presets = d.presets }
        presets = presets.enumerated().map { Self.fitPreset($0.element, slot: $0.offset) }
        if focusMinutes < 1 { focusMinutes = d.focusMinutes }
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        phaseStart = try c.decodeIfPresent(Date.self, forKey: .phaseStart)
        sessionStart = try c.decodeIfPresent(Date.self, forKey: .sessionStart)
        wasPaused = try c.decodeIfPresent(Bool.self, forKey: .wasPaused) ?? d.wasPaused
        completedInCycle = try c.decodeIfPresent(Int.self, forKey: .completedInCycle) ?? d.completedInCycle
        longBreakEvery = min(Self.longBreakRange.upperBound, max(Self.longBreakRange.lowerBound,
            try c.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? d.longBreakEvery))
        tallyDay = try c.decodeIfPresent(String.self, forKey: .tallyDay) ?? d.tallyDay
        tallySeconds = try c.decodeIfPresent(Int.self, forKey: .tallySeconds) ?? d.tallySeconds
        tallySessions = try c.decodeIfPresent(Int.self, forKey: .tallySessions) ?? d.tallySessions
    }

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

enum SharedStore {
    static let appGroup = "group.com.christruong.purrmodoro"
    private static let key = "timerSnapshot"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func load() -> TimerSnapshot {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(TimerSnapshot.self, from: data)
        else { return TimerSnapshot() }
        return snap
    }

    static func save(_ snap: TimerSnapshot) {
        if let data = try? JSONEncoder().encode(snap) { defaults.set(data, forKey: key) }
    }
}

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: Phase
        /// The session length as she set it, for "25-minute session".
        var minutes: Int
        var start: Date
        var end: Date
        var pausedRemaining: TimeInterval?
    }
}

enum Format {
    /// 1499.2 -> "25:00"
    static func clock(_ interval: TimeInterval) -> String {
        let s = Int(interval.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// 6000 -> "1h 40m"
    static func duration(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
    }
}
