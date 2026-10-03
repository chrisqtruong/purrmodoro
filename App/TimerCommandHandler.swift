import SwiftData

/// Carries out lock screen button taps (pause, resume, end) on the real timer.
enum TimerCommandHandler {
    @MainActor
    static func run(_ command: TimerCommand) async {
        let engine = TimerEngine.shared ?? TimerEngine.standalone()
        engine.refresh()
        switch command {
        case .pause: engine.pause()
        case .resume: engine.resume()
        case .stop: engine.stop()
        }
    }
}
