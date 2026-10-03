import SwiftUI

/// What the sky outside the kitty's window looks like right now, estimated from the clock
/// and the date alone. No location needed: sunrise and sunset are approximated for a
/// mid-latitude city (around Baltimore), shifting with the seasons and daylight saving.
struct SkyClock {
    /// 0 = full night, 1 = full day. Ramps over about an hour around sunrise and sunset.
    let daylight: Double
    /// 0...1, how sunrise/sunset-colored the light is.
    let warmth: Double
    /// 0 at sunrise, 1 at sunset: where the sun is along its arc.
    let sunArc: Double

    static func isNight(at date: Date) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-forceDay") { return false }
        #endif
        return SkyClock(date: date).daylight < 0.5
    }

    init(date: Date, calendar: Calendar = .current) {
        #if DEBUG
        let date = ProcessInfo.processInfo.arguments.contains("-forceDay")
            ? calendar.startOfDay(for: date).addingTimeInterval(13 * 3600) : date
        #endif
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 172)
        let dayLength = 12 + 2.9 * sin(2 * .pi * (dayOfYear - 80) / 365)
        let solarNoon = 12.1 + (calendar.timeZone.isDaylightSavingTime(for: date) ? 1 : 0)
        let sunrise = solarNoon - dayLength / 2
        let sunset = solarNoon + dayLength / 2

        let c = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

        daylight = min(clamp(hour - (sunrise - 0.5)), clamp((sunset + 0.5) - hour))
        warmth = clamp(1 - min(abs(hour - sunrise), abs(hour - sunset)) / 1.2)
        sunArc = (hour - sunrise) / (sunset - sunrise)
    }

    /// The upper sky: night → purple twilight → day blue.
    var top: Color {
        daylight < 0.4
            ? Theme.skyNight.mix(with: Theme.skyTwilight, by: daylight / 0.4)
            : Theme.skyTwilight.mix(with: Theme.skyDay, by: (daylight - 0.4) / 0.6)
    }

    /// Near the horizon, glowing gold around sunrise and sunset.
    var horizon: Color { top.mix(with: Theme.skyGolden, by: warmth * 0.9) }

    var sunColor: Color { Theme.sun.mix(with: Theme.sunLow, by: warmth * 0.8) }
}
