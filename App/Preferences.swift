import Foundation

/// The sound that plays when a session ends while her phone is locked (a notification).
/// iOS plays it at the ringer volume and keeps it quiet on silent, so these are made soft.
enum AlarmSound: String, CaseIterable, Identifiable {
    case marimba, musicBox, bowl, silent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marimba: return "Marimba"
        case .musicBox: return "Music box"
        case .bowl: return "Singing bowl"
        case .silent: return "Silent"
        }
    }

    var detail: String {
        switch self {
        case .marimba: return "Warm little knocks"
        case .musicBox: return "A tiny tinkly tune"
        case .bowl: return "One long, calm hum"
        case .silent: return "Banner only"
        }
    }

    var icon: String {
        switch self {
        case .marimba: return "music.note"
        case .musicBox: return "sparkles"
        case .bowl: return "bell.fill"
        case .silent: return "bell.slash.fill"
        }
    }

    /// Bundled file for the notification. Breaks ending get a lower version.
    func fileName(breakOver: Bool) -> String? {
        switch self {
        case .marimba: return breakOver ? "alarm-marimba-low.wav" : "alarm-marimba.wav"
        case .musicBox: return breakOver ? "alarm-musicbox-low.wav" : "alarm-musicbox.wav"
        case .bowl: return breakOver ? "alarm-bowl-low.wav" : "alarm-bowl.wav"
        case .silent: return nil
        }
    }

    var preview: Sound? {
        switch self {
        case .marimba: return .alarmMarimba
        case .musicBox: return .alarmMusicBox
        case .bowl: return .alarmBowl
        case .silent: return nil
        }
    }
}

/// Her settings, kept on the phone.
enum Preferences {
    static let soundsKey = "soundsOn"
    static let hapticsKey = "hapticsOn"
    static let alarmKey = "alarmSound"
    static let volumeKey = "soundVolume"
    static let defaultVolume = 0.7

    static var soundsOn: Bool { UserDefaults.standard.object(forKey: soundsKey) as? Bool ?? true }
    static var hapticsOn: Bool { UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true }
    /// 0...1, how loud the app's own sounds play.
    static var soundVolume: Double { UserDefaults.standard.object(forKey: volumeKey) as? Double ?? defaultVolume }
    static var alarm: AlarmSound {
        AlarmSound(rawValue: UserDefaults.standard.string(forKey: alarmKey) ?? "") ?? .marimba
    }
}
