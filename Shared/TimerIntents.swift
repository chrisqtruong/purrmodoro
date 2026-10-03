import AppIntents

/// What the lock screen buttons ask the timer to do.
enum TimerCommand: Sendable {
    case pause, resume, stop
}

// Buttons on the Live Activity. iOS runs these inside the app (even when it's closed),
// where `TimerCommandHandler` does the work. The widget extension has a stub of it.

struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause timer"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await TimerCommandHandler.run(.pause)
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume timer"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await TimerCommandHandler.run(.resume)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End session"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        await TimerCommandHandler.run(.stop)
        return .result()
    }
}
