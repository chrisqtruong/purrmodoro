#if DEBUG
import SwiftUI

/// App icon concepts, drawn with the real kitty. Launch with `-renderIcons` to export
/// 1024×1024 PNGs (and a comparison sheet) into the app's Documents folder.
enum IconConcept: String, CaseIterable {
    case face = "A"
    case ring = "B"
    case peek = "C"
    case peekDark = "C-dark"
    case peekTinted = "C-tinted"
}

/// A late-night moment, so the kitty wears her night glasses in the dark icon.
private let nightTime = Calendar.current.startOfDay(for: .now).addingTimeInterval(23 * 3600).timeIntervalSinceReferenceDate

struct AppIconView: View {
    let concept: IconConcept

    var body: some View {
        ZStack {
            switch concept {
            case .face:
                Color(hex: 0xFFF6EA)
                KittyFigure(mood: .idle, t: nil, headOnly: true)
                    .padding(80)
            case .ring:
                Color(hex: 0xFFF6EA)
                Circle()
                    .stroke(Color(hex: 0xF2E3D0), lineWidth: 72)
                    .padding(120)
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(Theme.caramel, style: StrokeStyle(lineWidth: 72, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(120)
                KittyFigure(mood: .idle, t: nil, headOnly: true)
                    .padding(215)
            case .peek:
                LinearGradient(colors: [Color(hex: 0xF3CFA6), Color(hex: 0xE3A873)], startPoint: .top, endPoint: .bottom)
                KittyFigure(mood: .idle, t: nil, headOnly: true)
                    .frame(width: 1040, height: 1040)
                    .offset(y: 150)
            case .peekDark:
                LinearGradient(colors: [Color(hex: 0x2E2A52), Color(hex: 0x17162A)], startPoint: .top, endPoint: .bottom)
                ForEach(0..<7, id: \.self) { i in
                    let star = [(170.0, 120.0, 9.0), (330, 70, 6), (420, 250, 5), (700, 90, 10), (860, 170, 6), (250, 230, 5), (620, 230, 5)][i]
                    Circle().fill(Color.white.opacity(0.75))
                        .frame(width: star.2 * 2, height: star.2 * 2)
                        .position(x: star.0, y: star.1)
                }
                Circle().fill(Theme.moon).frame(width: 96, height: 96).position(x: 512, y: 185)
                Circle().fill(Color(hex: 0x2A2650)).frame(width: 86, height: 86).position(x: 540, y: 168)
                KittyFigure(mood: .idle, t: nightTime, headOnly: true)
                    .frame(width: 1040, height: 1040)
                    .offset(y: 150)
            case .peekTinted:
                Color.black
                KittyFigure(mood: .idle, t: nightTime, headOnly: true)
                    .frame(width: 1040, height: 1040)
                    .offset(y: 150)
                    .grayscale(1)
                    .brightness(0.15)
            }
        }
        .frame(width: 1024, height: 1024)
        .clipped()
    }
}

private struct IconSheet: View {
    var body: some View {
        VStack(spacing: 36) {
            HStack(spacing: 56) {
                ForEach(IconConcept.allCases, id: \.self) { concept in
                    VStack(spacing: 16) {
                        icon(concept, size: 300)
                        Text(concept.rawValue)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x4A3222))
                    }
                }
            }
            // How they look at real home-screen size, next to each other on a wallpaper.
            HStack(spacing: 72) {
                ForEach(IconConcept.allCases, id: \.self) { concept in
                    VStack(spacing: 8) {
                        icon(concept, size: 64)
                        Text(concept.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: 0x5B4636), Color(hex: 0x2D2A33)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .padding(56)
        .background(Color.white)
    }

    private func icon(_ concept: IconConcept, size: CGFloat) -> some View {
        AppIconView(concept: concept)
            .scaleEffect(size / 1024)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: size * 0.03, y: size * 0.015)
    }
}

@MainActor
enum IconRenderer {
    static func renderIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-renderIcons") else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for concept in IconConcept.allCases {
            let renderer = ImageRenderer(content: AppIconView(concept: concept))
            renderer.scale = 1
            renderer.isOpaque = true
            try? renderer.uiImage?.pngData()?.write(to: dir.appendingPathComponent("icon-\(concept.rawValue).png"))
        }
        let sheet = ImageRenderer(content: IconSheet())
        sheet.scale = 2
        try? sheet.uiImage?.pngData()?.write(to: dir.appendingPathComponent("icon-sheet.png"))

        // Petting reactions, frozen partway through, to check the poses.
        let reactions: [(KittyReaction, String, Double)] = [
            (.earLeft, "ear", 0.05), (.headPat, "head pat", 0.3), (.boop, "boop", 0.2),
            (.purr, "purr", 0.5), (.tail, "tail", 0.1), (.pawRight, "paw", 0.5),
        ]
        let poses = ImageRenderer(content:
            HStack(spacing: 12) {
                ForEach(reactions, id: \.1) { reaction, name, elapsed in
                    VStack {
                        KittyFigure(mood: .idle, t: 100, reaction: reaction, reactionElapsed: elapsed)
                            .frame(width: 180, height: 180)
                        Text(name).font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                }
            }
            .padding(20)
            .background(Color(hex: 0xFFF6EA))
        )
        poses.scale = 2
        try? poses.uiImage?.pngData()?.write(to: dir.appendingPathComponent("reactions.png"))

        // Every mood at her desk, day and night.
        let moods: [(KittyMood, String)] = [(.idle, "idle"), (.focus, "focus"), (.rest, "break"), (.happy, "done")]
        let scenes = ImageRenderer(content:
            VStack(spacing: 12) {
                ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                    HStack(spacing: 12) {
                        ForEach(moods, id: \.1) { mood, name in
                            VStack {
                                KittyFigure(mood: mood,
                                            t: Calendar.current.startOfDay(for: .now)
                                                .addingTimeInterval(scheme == .dark ? 22 * 3600 : 13 * 3600)
                                                .timeIntervalSinceReferenceDate,
                                            scene: true)
                                    .padding(24)
                                    .frame(width: 230, height: 230)
                                    .clipShape(Circle())
                                Text(name).font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(scheme == .dark ? Color.white : Color.black)
                            }
                        }
                    }
                    .padding(16)
                    .background(scheme == .dark ? Color(hex: 0x1B1A2E) : Color(hex: 0xFFF6EA))
                    .environment(\.colorScheme, scheme)
                }
            }
        )
        scenes.scale = 2
        try? scenes.uiImage?.pngData()?.write(to: dir.appendingPathComponent("scenes.png"))

        // The window through a day (today's date, local clock).
        let hours: [Double] = [6.3, 7.2, 8, 13, 18.6, 19.1, 19.8, 23]
        let today = Calendar.current.startOfDay(for: .now)
        let sky = ImageRenderer(content:
            HStack(spacing: 10) {
                ForEach(hours, id: \.self) { hour in
                    let date = today.addingTimeInterval(hour * 3600)
                    VStack {
                        KittyFigure(mood: .idle, t: date.timeIntervalSinceReferenceDate, scene: true)
                            .padding(20)
                            .frame(width: 170, height: 170)
                            .clipShape(Circle())
                        Text(date, format: .dateTime.hour().minute())
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
            }
            .padding(16)
            .background(Color(hex: 0xFFF6EA))
        )
        sky.scale = 2
        try? sky.uiImage?.pngData()?.write(to: dir.appendingPathComponent("sky.png"))
    }
}
#endif
