import SwiftUI

/// Everything that isn't timer lengths: sound, vibration, and the time's-up sound.
struct SettingsView: View {
    @AppStorage(Preferences.soundsKey) private var soundsOn = true
    @AppStorage(Preferences.hapticsKey) private var hapticsOn = true
    @AppStorage(Preferences.alarmKey) private var alarmRaw = AlarmSound.marimba.rawValue
    @AppStorage(Preferences.volumeKey) private var volume = Preferences.defaultVolume
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SheetHeader(done: { dismiss() }) { Text("Settings").sheetTitle() }
                    Group {
                        SectionTitle("Sound & feel")
                        VStack(spacing: 10) {
                            VStack(spacing: 0) {
                                ToggleRow(icon: "speaker.wave.2.fill", title: "App sounds",
                                          subtitle: "Pops, ticks, and purrs", isOn: $soundsOn, card: false)
                                VolumeBar(value: $volume, enabled: soundsOn)
                            }
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            ToggleRow(icon: "hand.tap.fill", title: "Vibration",
                                      subtitle: "Little taps as you use the app", isOn: $hapticsOn)
                        }
                    }

                    Group {
                        SectionTitle("When time's up")
                        VStack(spacing: 10) {
                            ForEach(AlarmSound.allCases) { alarm in
                                AlarmRow(alarm: alarm, selected: (AlarmSound(rawValue: alarmRaw) ?? .marimba) == alarm) {
                                    alarmRaw = alarm.rawValue
                                    Haptics.select()
                                    SoundPlayer.shared.preview(alarm.preview)
                                }
                            }
                        }
                        Text("Uses your ringer volume. Quiet on silent.")
                            .font(.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)

                AboutFooter()
                    .padding(.top, 12)
                    .padding(.bottom, 28)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear { SoundPlayer.shared.stopPreviews() }
        }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.rounded(.headline, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 4)
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var card = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Theme.sage)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(Theme.caramel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(card ? Theme.card : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// App sound volume, 0–100% in notches of 10. The handle is a paw print.
private struct VolumeBar: View {
    @Binding var value: Double
    let enabled: Bool
    @State private var dragging = false

    private let steps = 10
    private let thumb: CGFloat = 30

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 26)
            GeometryReader { geo in
                let track = geo.size.width - thumb
                let x = thumb / 2 + track * value
                let mid = geo.size.height / 2
                ZStack {
                    Capsule().fill(Theme.track)
                        .frame(width: track, height: 6)
                        .position(x: geo.size.width / 2, y: mid)
                    Capsule().fill(Theme.caramel)
                        .frame(width: max(6, track * value), height: 6)
                        .position(x: thumb / 2 + track * value / 2, y: mid)
                    ForEach(0...steps, id: \.self) { i in
                        let notch = Double(i) / Double(steps)
                        Circle()
                            .fill(notch <= value ? Color.white.opacity(0.55) : Theme.inkSoft.opacity(0.35))
                            .frame(width: 4, height: 4)
                            .position(x: thumb / 2 + track * notch, y: mid)
                    }
                    Circle()
                        .fill(Theme.caramel)
                        .overlay(Image(systemName: "pawprint.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                        .frame(width: thumb, height: thumb)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .scaleEffect(dragging ? 1.15 : 1)
                        .position(x: x, y: mid)
                }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            dragging = true
                            let raw = (drag.location.x - thumb / 2) / track
                            let snapped = min(1, max(0, (raw * Double(steps)).rounded() / Double(steps)))
                            if snapped != value {
                                value = snapped
                                Haptics.select()
                            }
                        }
                        .onEnded { _ in
                            dragging = false
                            SoundPlayer.shared.play(.pop)
                        }
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
                .animation(.snappy, value: value)
            }
            .frame(height: thumb)
            Text("\(Int((value * 100).rounded()))%")
                .font(.rounded(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
                .contentTransition(.numericText())
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .opacity(enabled ? 1 : 0.4)
        .allowsHitTesting(enabled)
        .accessibilityElement()
        .accessibilityLabel("App sound volume")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            value = min(1, max(0, value + (direction == .increment ? 0.1 : -0.1)))
        }
    }
}

private struct AlarmRow: View {
    let alarm: AlarmSound
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 12) {
                Image(systemName: alarm.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.sage)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alarm.title)
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(alarm.detail)
                        .font(.rounded(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.caramel : Theme.inkSoft.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A little signature at the bottom of Settings.
private struct AboutFooter: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("made by C for S ♡")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(version)
                .font(.rounded(.caption))
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
