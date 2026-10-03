import ActivityKit
import AVFoundation
import UIKit
import UserNotifications

// MARK: Sounds

enum Sound: String, CaseIterable {
    case pop, tick, chime, boop, purr
    case chimeLow = "chime-low"
    case alarmMarimba = "alarm-marimba"
    case alarmMusicBox = "alarm-musicbox"
    case alarmBowl = "alarm-bowl"
}

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        // .ambient respects the silent switch and doesn't interrupt her music.
        // Set up off the main thread so it can't stutter the UI at launch.
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        }
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    /// `force` plays even with app sounds off (for previews she asked to hear).
    func play(_ sound: Sound, volume: Float = 1, force: Bool = false) {
        guard force || Preferences.soundsOn, let player = players[sound] else { return }
        // Previews play at full level; everything else follows her volume setting.
        player.volume = volume * Float(force ? 1 : Preferences.soundVolume)
        player.currentTime = 0
        player.play()
    }

    /// Plays one alarm preview, stopping any other that's still ringing.
    func preview(_ sound: Sound?) {
        stopPreviews()
        if let sound { play(sound, force: true) }
    }

    func stopPreviews() {
        for alarm in AlarmSound.allCases {
            guard let sound = alarm.preview, let player = players[sound], player.isPlaying else { continue }
            player.stop()
        }
    }
}

// MARK: Haptics

@MainActor
enum Haptics {
    static func tap() { if Preferences.hapticsOn { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
    static func select() { if Preferences.hapticsOn { UISelectionFeedbackGenerator().selectionChanged() } }
    static func success() { if Preferences.hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) } }

    /// A soft rumble, like a purr against your hand.
    static func purr() {
        guard Preferences.hapticsOn else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        Task {
            for i in 0..<14 {
                generator.impactOccurred(intensity: 0.35 + 0.25 * sin(Double(i) / 13 * .pi))
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }
}

// MARK: Petting

@MainActor
enum PetFeedback {
    static func play(_ reaction: KittyReaction) {
        switch reaction {
        case .earLeft, .earRight:
            SoundPlayer.shared.play(.tick)
            Haptics.select()
        case .headPat, .pawLeft, .pawRight, .bellyRub:
            SoundPlayer.shared.play(.pop)
            Haptics.tap()
        case .boop:
            SoundPlayer.shared.play(.boop)
            Haptics.tap()
        case .purr:
            SoundPlayer.shared.play(.purr)
            Haptics.purr()
        case .tail:
            Haptics.select()
        }
    }
}

// MARK: Notifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// While the app is open, the kitty and in-app chime handle it; no banner needed.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}

enum Notifications {
    private static let id = "phase-end"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(at date: Date, finishing phase: Phase, nextBreakMinutes: Int) {
        let content = UNMutableNotificationContent()
        if phase == .focus {
            content.title = "Focus done 🐾"
            content.body = "\(nextBreakMinutes) minute break. Go stretch."
            content.sound = Preferences.alarm.fileName(breakOver: false).map { UNNotificationSound(named: UNNotificationSoundName($0)) }
        } else {
            content.title = "Break's over"
            content.body = "Back to it whenever you're ready."
            content.sound = Preferences.alarm.fileName(breakOver: true).map { UNNotificationSound(named: UNNotificationSoundName($0)) }
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
}

// MARK: Live Activity (lock screen + Dynamic Island)

@MainActor
enum LiveActivityController {
    static func show(_ state: TimerActivityAttributes.ContentState, stale: Date?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: stale)
        Task {
            if let current = Activity<TimerActivityAttributes>.activities.first {
                await current.update(content)
            } else {
                _ = try? Activity<TimerActivityAttributes>.request(attributes: TimerActivityAttributes(), content: content)
            }
        }
    }

    static func endAll() {
        let activities = Activity<TimerActivityAttributes>.activities
        Task {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
