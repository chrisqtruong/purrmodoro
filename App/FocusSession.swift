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
        for offset in 1..<112 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekend = cal.isDateInWeekend(day)
            guard Int.random(in: 0..<10) < (weekend ? 3 : 8) else { continue }
            for i in 0..<Int.random(in: 1...(weekend ? 3 : 7)) {
                let start = day.addingTimeInterval(9 * 3600 + Double(i) * 35 * 60)
                let full = Int.random(in: 0..<5) > 0
                context.insert(FocusSession(start: start,
                                            seconds: full ? [25, 25, 45][Int.random(in: 0..<3)] * 60 : Int.random(in: 5...20) * 60,
                                            deep: full && Bool.random(),
                                            completed: full))
            }
        }
        try? context.save()
    }
}
#endif
