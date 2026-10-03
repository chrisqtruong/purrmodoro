import Foundation
import SwiftData

/// One stretch of focus time. Kept on the phone only.
@Model
final class FocusSession {
    var start: Date
    var seconds: Int
    /// Finished start to end without pausing.
    var deep: Bool
    /// Ran the full length (as opposed to stopped early).
    var completed: Bool

    init(start: Date, seconds: Int, deep: Bool, completed: Bool) {
        self.start = start
        self.seconds = seconds
        self.deep = deep
        self.completed = completed
    }
}

/// A short note she leaves on a day ("wrote my case report").
@Model
final class DayNote {
    var day: Date
    var text: String

    init(day: Date, text: String) {
        self.day = day
        self.text = text
    }
}

#if DEBUG
/// Fills history with sample data when launched with `-seedDemo`, so the heatmap can be previewed.
enum DemoData {
    static func seedIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo"),
              (try? context.fetchCount(FetchDescriptor<FocusSession>())) == 0
        else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // Sessions start in the morning, afternoon, or evening, mostly mornings.
        let blocks: [Double] = [8.5, 9, 9.5, 10, 13.5, 14, 15, 19, 20.5]
        for offset in 0..<112 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekend = cal.isDateInWeekend(day)
            guard offset < 3 || Int.random(in: 0..<10) < (weekend ? 3 : 8) else { continue }
            var clock = blocks.randomElement()!
            for _ in 0..<Int.random(in: 1...(weekend ? 3 : 6)) {
                let start = day.addingTimeInterval(clock * 3600)
                guard start < .now else { break }
                let full = Int.random(in: 0..<5) > 0
                let minutes = full ? [25, 25, 45][Int.random(in: 0..<3)] : Int.random(in: 5...20)
                context.insert(FocusSession(start: start, seconds: minutes * 60,
                                            deep: full && Bool.random(), completed: full))
                clock += Double(minutes + 10) / 60
            }
        }
        let notes = [(1, "Finished my case report"), (4, "Long clinic day, squeezed in two sessions"),
                     (8, "Board review: cardiology"), (15, "Wrote the grant draft")]
        for (offset, text) in notes {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) { context.insert(DayNote(day: day, text: text)) }
        }
        try? context.save()
    }
}
#endif
