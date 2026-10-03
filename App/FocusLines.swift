import Foundation

/// Little encouragements under the timer while she focuses, changing every 20 seconds.
/// Each session shuffles them, so nothing repeats until she's seen them all.
enum FocusLines {
    static let all = [
        "Paws on the keyboard",
        "Deep in thought",
        "One thing at a time",
        "Quiet as a cat nap",
        "Steady and cozy",
        "Tiny steps count",
        "In the zone",
        "Whiskers forward",
        "Head down, paws busy",
        "Zero distractions (almost)",
        "Brain purring nicely",
        "Staying on the page",
        "Brain on, phone off",
        "Soft focus, big progress",
        "Nose in the book",
        "Ears perked, mind clear",
        "Just this, right now",
        "Page by page",
        "Pawsitively focused",
        "Stretching the brain",
        "Chipping away",
        "Calm and curious",
        "Tail still, brain busy",
        "Kitty's got your back",
        "One more paragraph",
        "Head down, heart light",
        "Tail curled, mind busy",
        "Snacks later",
        "Sharp as a claw",
        "Cozy and capable",
    ]

    /// Gentle nudges to actually rest during breaks.
    static let breaks = [
        "Stretch those paws",
        "Sip some water",
        "Rest your eyes",
        "Roll your shoulders",
        "Look out the window",
        "Deep breath in… and out",
        "Wiggle your toes",
        "Snack time, maybe?",
        "Unclench your jaw",
        "Stand up and stretch",
        "Slow blink, like a cat",
        "Tea break?",
        "Let your mind wander",
        "Shake it out",
        "Kitty approves this break",
        "Refill your cup",
        "A little walk, perhaps",
        "Doing nothing is allowed",
        "Go touch grass",
        "Loosen up those whiskers",
    ]

    static let secondsEach: TimeInterval = 20

    static func breakLine(elapsed: TimeInterval, remaining: TimeInterval, long: Bool, seed: Date?) -> String {
        if remaining < 60 { return "Back to it soon…" }
        let step = Int(elapsed / secondsEach)
        guard step > 0 else { return long ? "Long break. You earned it" : "Stretch break" }
        let order = shuffled(breaks, seed: UInt64(max(0, (seed ?? .now).timeIntervalSince1970)))
        return order[(step - 1) % order.count]
    }

    static func line(elapsed: TimeInterval, remaining: TimeInterval, session: Date?) -> String {
        if remaining < 60 { return "Almost there…" }
        let step = Int(elapsed / secondsEach)
        guard step > 0 else { return "Focusing…" }
        let order = shuffled(all, seed: UInt64(max(0, (session ?? .now).timeIntervalSince1970)))
        return order[(step - 1) % order.count]
    }

    /// A shuffle that's the same every time for a given session.
    private static func shuffled(_ source: [String], seed: UInt64) -> [String] {
        var state = seed &* 6364136223846793005 &+ 1442695040888963407
        var lines = source
        for i in stride(from: lines.count - 1, to: 0, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            lines.swapAt(i, Int((state >> 33) % UInt64(i + 1)))
        }
        return lines
    }
}
