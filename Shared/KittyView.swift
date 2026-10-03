import SwiftUI

enum KittyMood { case idle, focus, rest, happy }

/// What the kitty does when she's petted in a particular spot.
enum KittyReaction: Equatable {
    case earLeft, earRight, headPat, boop, purr, bellyRub, tail, pawLeft, pawRight

    var duration: Double {
        switch self {
        case .earLeft, .earRight: return 0.6
        case .boop: return 0.8
        case .headPat: return 1.2
        case .purr: return 1.8
        case .bellyRub: return 0.9
        case .tail, .pawLeft, .pawRight: return 1.0
        }
    }

    /// Which part of the kitty a point in her 200×200 space lands on.
    /// `onDesk` moves her paws up onto the desk, like in the main-screen scene.
    static func at(_ p: CGPoint, onDesk: Bool) -> KittyReaction? {
        let (x, y) = (p.x, p.y)
        let paws: ClosedRange<CGFloat> = onDesk ? 146...180 : 166...200
        if y < 52 && x >= 40 && x < 84 { return .earLeft }
        if y < 52 && x > 116 && x <= 160 { return .earRight }
        if (78...122).contains(x) && (92...122).contains(y) { return .boop }
        if (38...162).contains(x) && (20...134).contains(y) { return .headPat }
        if paws.contains(y) && (56...100).contains(x) { return .pawLeft }
        if paws.contains(y) && (100...140).contains(x) { return .pawRight }
        if x > 140 && (95...(onDesk ? 160 : 196)).contains(y) { return .tail }
        // The belly usually gets a happy wiggle; a purr is a rare treat.
        if (56...144).contains(x) && (134...(onDesk ? 160 : 196)).contains(y) {
            return Double.random(in: 0..<1) < 0.1 ? .purr : .bellyRub
        }
        return nil
    }
}

/// The little brown kitty. Drawn with shapes in a 200×200 space so it scales cleanly
/// and renders in widgets and Live Activities, where it holds a still pose.
struct KittyView: View {
    var mood: KittyMood
    var animated = true
    var headOnly = false
    /// Draws her at her desk with a window behind. Day or night follows the real clock.
    var scene = false
    /// Lets her be petted. `onReact` fires so the app can add sounds and haptics.
    var interactive = false
    var onReact: ((KittyReaction) -> Void)? = nil
    /// Where she's looking, as a direction from her face (-1...1 each way). Zero = straight ahead.
    var lookAt: CGPoint = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reaction: KittyReaction?
    @State private var reactionStart = Date.distantPast
    @State private var calmUntil = Date.distantPast

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    KittyFigure(mood: mood, t: t, headOnly: headOnly, scene: scene, reaction: reaction,
                                reactionElapsed: context.date.timeIntervalSince(reactionStart), lookAt: lookAt)
                }
            } else {
                KittyFigure(mood: mood, t: nil, headOnly: headOnly, scene: scene)
            }
        }
        .overlay {
            if interactive {
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { location in
                            pet(at: location, in: geo.size)
                        }
                }
            }
        }
    }

    private func pet(at location: CGPoint, in size: CGSize) {
        let side = min(size.width, size.height)
        let s = side / 200
        let point = CGPoint(x: (location.x - (size.width - side) / 2) / s,
                            y: (location.y - (size.height - side) / 2) / s)
        // Let each reaction finish (plus a short breather) before she responds again.
        guard Date.now >= calmUntil, let hit = KittyReaction.at(point, onDesk: scene) else { return }
        reaction = hit
        reactionStart = .now
        calmUntil = .now.addingTimeInterval(hit.duration + 0.4)
        onReact?(hit)
    }
}

private enum EyeStyle { case open, closed, happy, squeeze }

/// How the kitty is posed at a moment in time.
private struct Pose {
    var t: Double
    var breathe: CGFloat = 0
    var tail: CGFloat = 0
    var blink = false
    var leftEar: CGFloat = 0
    var rightEar: CGFloat = 0
    var headTilt: CGFloat = 0
    var headSquash: CGFloat = 1
    var bodyTilt: CGFloat = 0
    var look = CGPoint.zero
    var bounce: CGFloat = 0
    var jitter: CGFloat = 0
    var eyes: EyeStyle = .open
    var mouthOpen = false
    var pawLeft: CGFloat = 0
    var pawRight: CGFloat = 0
    var pawWave: CGFloat = 0
    /// 0...1 progress of a single heart floating up after a pet, if any.
    var floatHeart: Double?
    /// 0...1 progress of a floating "purr", if any.
    var purrText: Double?

    init(mood: KittyMood, t time: Double?, reaction: KittyReaction? = nil, elapsed: Double = 0, lookAt: CGPoint = .zero) {
        let t = time ?? 0.6
        self.t = t
        func wave(_ period: Double) -> CGFloat { CGFloat(sin(t * 2 * .pi / period)) }

        switch mood {
        case .idle:
            breathe = wave(3); tail = wave(2.2) * 16
            look = CGPoint(x: wave(7) * 3, y: 0)
        case .focus:
            breathe = wave(4.5); tail = wave(4) * 7
            look = CGPoint(x: wave(5) * 1.5, y: 6)
        case .rest:
            breathe = wave(5); tail = wave(3) * 10; headTilt = wave(6) * 5
            eyes = .closed
        case .happy:
            breathe = wave(1.2); tail = wave(0.8) * 22
            bounce = -abs(wave(1.6)) * 8
            eyes = .happy; mouthOpen = true
        }

        guard time != nil else {
            breathe = 0; bounce = 0; headTilt = 0
            tail = mood == .happy ? 12 : 6
            return
        }
        blink = (mood == .idle || mood == .focus) && t.truncatingRemainder(dividingBy: 4.3) < 0.13
        rightEar = t.truncatingRemainder(dividingBy: 6.7) < 0.25 ? -10 : 0

        // Watching something (like a finger winding the clock): eyes and head follow it.
        let focusStrength = min(1, hypot(lookAt.x, lookAt.y))
        if focusStrength > 0.01 {
            look = CGPoint(x: look.x * (1 - focusStrength) + lookAt.x * 5.5,
                           y: look.y * (1 - focusStrength) + lookAt.y * 5.5)
            headTilt += lookAt.x * 8
            blink = false
        }

        guard let reaction, elapsed >= 0, elapsed < reaction.duration else { return }
        apply(reaction, e: elapsed)
    }

    private mutating func apply(_ reaction: KittyReaction, e: Double) {
        let u = e / reaction.duration
        let fade = CGFloat(1 - u)
        func osc(_ hz: Double) -> CGFloat { CGFloat(sin(e * 2 * .pi * hz)) }
        blink = false
        bounce += -CGFloat(sin(min(1, e / 0.3) * .pi)) * 5

        switch reaction {
        case .earLeft:
            leftEar = osc(5) * 18 * fade
        case .earRight:
            rightEar = osc(5) * -18 * fade
        case .headPat:
            eyes = .happy; mouthOpen = true
            headTilt += osc(1.6) * 7 * fade
            leftEar = -12 * fade; rightEar = 12 * fade
            floatHeart = u
        case .boop:
            eyes = e < 0.45 ? .squeeze : .happy
            headSquash = 1 - 0.07 * CGFloat(sin(min(1, e / 0.25) * .pi))
            floatHeart = u
        case .purr:
            eyes = .closed; mouthOpen = false
            jitter = osc(22) * 0.9 * fade
            breathe = osc(1.5)
            purrText = u
        case .bellyRub:
            eyes = .happy; mouthOpen = true
            bodyTilt = osc(2.5) * 4 * fade
            headTilt += osc(2.5) * 6 * fade
            floatHeart = u
        case .tail:
            tail += osc(2.5) * 30 * fade
            look = CGPoint(x: 6, y: 2)
        case .pawLeft, .pawRight:
            eyes = .happy; mouthOpen = true
            let lift = CGFloat(sin(u * .pi)) * 20
            pawWave = osc(3) * 16 * fade
            if reaction == .pawLeft { pawLeft = lift } else { pawRight = lift }
        }
    }
}

/// A path drawn in the kitty's 200×200 space, scaled to fit whatever frame it's given.
private struct KPath: Shape {
    var transform: CGAffineTransform = .identity
    let build: @Sendable (inout Path) -> Void

    func path(in rect: CGRect) -> Path {
        var p = Path()
        build(&p)
        let s = min(rect.width, rect.height) / 200
        let fit = CGAffineTransform(translationX: rect.midX - 100 * s, y: rect.midY - 100 * s).scaledBy(x: s, y: s)
        return p.applying(transform.concatenating(fit))
    }
}

private func rotate(_ degrees: CGFloat, around c: CGPoint) -> CGAffineTransform {
    CGAffineTransform(translationX: c.x, y: c.y).rotated(by: degrees * .pi / 180).translatedBy(x: -c.x, y: -c.y)
}

private func scale(_ sx: CGFloat, _ sy: CGFloat, around c: CGPoint) -> CGAffineTransform {
    CGAffineTransform(translationX: c.x, y: c.y).scaledBy(x: sx, y: sy).translatedBy(x: -c.x, y: -c.y)
}

private func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> @Sendable (inout Path) -> Void {
    { $0.addEllipse(in: CGRect(x: x, y: y, width: w, height: h)) }
}

private func poly(_ points: [CGPoint]) -> @Sendable (inout Path) -> Void {
    { $0.addLines(points); $0.closeSubpath() }
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

struct KittyFigure: View, Animatable {
    var mood: KittyMood
    var t: Double?
    var headOnly = false
    var scene = false
    var reaction: KittyReaction? = nil
    var reactionElapsed: Double = 0
    var lookAt: CGPoint = .zero
    /// Lets her gaze glide smoothly back to center when something stops moving.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(lookAt.x, lookAt.y) }
        set { lookAt = CGPoint(x: newValue.first, y: newValue.second) }
    }

    /// The room follows the real time of day (like the window), not the phone's dark mode.
    private var clock: SkyClock { SkyClock(date: t.map { Date(timeIntervalSinceReferenceDate: $0) } ?? .now) }
    private var night: Bool { clock.daylight < 0.5 }
    /// At her desk, paws and props sit higher up, on the desktop.
    private var deskLift: CGFloat { scene ? -16 : 0 }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let s = side / 200
            let pose = Pose(mood: mood, t: t, reaction: reaction, elapsed: reactionElapsed, lookAt: lookAt)
            ZStack {
                if scene && !headOnly { sceneBack(pose, s) }
                // Only the kitty moves; the desk and what's on it stay put.
                if !headOnly {
                    ZStack { torso(pose, s) }
                        .rotationEffect(.degrees(pose.bodyTilt), anchor: UnitPoint(x: 0.5, y: 0.875))
                        .offset(x: pose.jitter * s, y: pose.bounce * s)
                    if scene { desk(s) }
                    deskProps(pose, s)
                }
                ZStack {
                    if !headOnly { paws(pose, s) }
                    headLayers(pose, s)
                }
                .offset(x: pose.jitter * s, y: pose.bounce * s)
                if scene && !headOnly { sceneFront(pose, s) }
                if !headOnly {
                    if mood == .happy { hearts(pose, s) }
                    extras(pose, s)
                }
            }
            .frame(width: side, height: side)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: Body

    @ViewBuilder
    private func torso(_ p: Pose, _ s: CGFloat) -> some View {
        let breath = scale(1 + p.breathe * 0.015, 1 + p.breathe * 0.025, around: CGPoint(x: 100, y: 192))

        if !scene { KPath(build: ellipse(48, 186, 104, 12)).fill(Color.black.opacity(0.08)) }

        KPath(transform: rotate(p.tail, around: CGPoint(x: 132, y: 180))) { path in
            path.move(to: CGPoint(x: 128, y: 182))
            path.addCurve(to: CGPoint(x: 174, y: 128), control1: CGPoint(x: 172, y: 190), control2: CGPoint(x: 184, y: 156))
            path.addQuadCurve(to: CGPoint(x: 160, y: 108), control: CGPoint(x: 172, y: 104))
        }
        .stroke(Theme.fur, style: StrokeStyle(lineWidth: 11 * s, lineCap: .round, lineJoin: .round))

        KPath(transform: breath, build: ellipse(58, 112, 84, 80)).fill(night ? Theme.pajamas : Theme.coat)
        outfit(breath, s)
    }

    /// Things resting on the desk (or floor) that shouldn't bounce when she does.
    @ViewBuilder
    private func deskProps(_ p: Pose, _ s: CGFloat) -> some View {
        if mood == .focus { book(s) }
        if mood == .rest { yarn(p, s) }
    }

    @ViewBuilder
    private func paws(_ p: Pose, _ s: CGFloat) -> some View {
        let lift = CGAffineTransform(translationX: 0, y: deskLift)
        let sleeve = night ? Theme.pajamas : Theme.coat
        if mood == .focus {
            KPath(transform: lift, build: ellipse(50, 162, 30, 16)).fill(sleeve)
            KPath(transform: lift, build: ellipse(120, 162, 30, 16)).fill(sleeve)
            KPath(transform: lift, build: ellipse(52, 168, 26, 17)).fill(Theme.furLight)
            KPath(transform: lift, build: ellipse(122, 168, 26, 17)).fill(Theme.furLight)
        } else {
            let left = paw(lift: p.pawLeft, wave: p.pawWave, center: CGPoint(x: 83, y: 186)).concatenating(lift)
            let right = paw(lift: p.pawRight, wave: -p.pawWave, center: CGPoint(x: 117, y: 186)).concatenating(lift)
            KPath(transform: left, build: ellipse(68, 172, 30, 16)).fill(sleeve)
            KPath(transform: right, build: ellipse(102, 172, 30, 16)).fill(sleeve)
            KPath(transform: left, build: ellipse(70, 178, 26, 16)).fill(Theme.furLight)
            KPath(transform: right, build: ellipse(104, 178, 26, 16)).fill(Theme.furLight)
        }
    }

    /// White coat with scrubs, stethoscope, and her name by day; polka-dot pajamas by night.
    @ViewBuilder
    private func outfit(_ breath: CGAffineTransform, _ s: CGFloat) -> some View {
        if night {
            KPath(transform: breath) { p in
                for d in [pt(74, 140), pt(90, 150), pt(128, 152), pt(108, 156), pt(80, 124), pt(118, 170), pt(84, 172)] {
                    p.addEllipse(in: CGRect(x: d.x - 2.4, y: d.y - 2.4, width: 4.8, height: 4.8))
                }
            }
            .fill(Theme.pajamaTrim.opacity(0.55))
            KPath(transform: breath, build: poly([pt(90, 116), pt(110, 116), pt(100, 134)])).fill(Theme.fur)
            KPath(transform: breath) { p in
                p.move(to: pt(86, 115)); p.addLine(to: pt(100, 137)); p.addLine(to: pt(114, 115))
            }
            .stroke(Theme.pajamaTrim, style: StrokeStyle(lineWidth: 3 * s, lineCap: .round, lineJoin: .round))
            KPath(transform: breath) { p in
                p.addEllipse(in: CGRect(x: 98, y: 144, width: 4, height: 4))
                p.addEllipse(in: CGRect(x: 98, y: 154, width: 4, height: 4))
            }
            .fill(Theme.pajamaTrim)
            stitchedName(Theme.pajamaTrim, s)
        } else {
            // Scrubs peeking out of the coat's V
            KPath(transform: breath, build: poly([pt(87, 115), pt(113, 115), pt(100, 146)])).fill(Theme.scrubs)
            KPath(transform: breath, build: poly([pt(93, 115), pt(107, 115), pt(100, 129)])).fill(Theme.fur)
            KPath(transform: breath) { p in
                p.move(to: pt(86, 114)); p.addLine(to: pt(98, 154))
                p.move(to: pt(114, 114)); p.addLine(to: pt(102, 154))
            }
            .stroke(Theme.coatShade, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))

            // Stethoscope draped on her left side
            KPath(transform: breath) { p in
                p.move(to: pt(84, 120)); p.addQuadCurve(to: pt(79, 149), control: pt(74, 134))
                p.move(to: pt(91, 122)); p.addQuadCurve(to: pt(89, 141), control: pt(86, 132))
            }
            .stroke(Theme.stethoscope, style: StrokeStyle(lineWidth: 3.2 * s, lineCap: .round))
            KPath(transform: breath) { p in
                p.move(to: pt(89, 141)); p.addLine(to: pt(86, 146))
                p.move(to: pt(89, 141)); p.addLine(to: pt(92, 146))
            }
            .stroke(Theme.silver, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            KPath(transform: breath, build: ellipse(73, 148, 12, 12)).fill(Theme.silver)
            KPath(transform: breath, build: ellipse(76, 151, 6, 6)).fill(Theme.stethoscope.opacity(0.5))

            // Pocket with a highlighter and pen
            KPath(transform: breath) { $0.addRect(CGRect(x: 107, y: 139, width: 4, height: 9)) }.fill(Theme.highlighter)
            KPath(transform: breath) { $0.addRect(CGRect(x: 113, y: 140, width: 3, height: 8)) }.fill(Theme.pen)
            KPath(transform: breath) { $0.addRoundedRect(in: CGRect(x: 105, y: 144, width: 22, height: 15), cornerSize: CGSize(width: 2, height: 2)) }
                .fill(Theme.coat)
            KPath(transform: breath) { $0.addRoundedRect(in: CGRect(x: 105, y: 144, width: 22, height: 15), cornerSize: CGSize(width: 2, height: 2)) }
                .stroke(Theme.coatShade, lineWidth: 1.5 * s)

            stitchedName(Theme.hopkinsBlue, s)
        }
    }

    /// "Sarah" embroidered on her chest: small, tilted to wrap around the curve of her body,
    /// with a faint darker edge like thread, so it reads as stitching rather than a label.
    private func stitchedName(_ thread: Color, _ s: CGFloat) -> some View {
        Text("Sarah")
            .font(.custom("SnellRoundhand-Bold", size: 8.5 * s))
            .foregroundStyle(thread.opacity(0.92))
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0.35 * s, y: 0.35 * s)
            .fixedSize()
            .rotation3DEffect(.degrees(-24), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotationEffect(.degrees(-7))
            .position(x: 121 * s, y: 138 * s)
            .allowsHitTesting(false)
    }

    private func paw(lift: CGFloat, wave: CGFloat, center: CGPoint) -> CGAffineTransform {
        guard lift > 0.01 else { return .identity }
        return rotate(wave, around: center).concatenating(CGAffineTransform(translationX: 0, y: -lift))
    }

    @ViewBuilder
    private func book(_ s: CGFloat) -> some View {
        let lift = CGAffineTransform(translationX: 0, y: deskLift)
        KPath(transform: lift, build: poly([pt(58, 168), pt(100, 175), pt(142, 168), pt(142, 194), pt(100, 200), pt(58, 194)]))
            .fill(Theme.book)
        KPath(transform: lift) { p in
            p.addLines([pt(62, 165), pt(100, 171), pt(100, 195), pt(62, 189)])
            p.closeSubpath()
            p.addLines([pt(138, 165), pt(100, 171), pt(100, 195), pt(138, 189)])
            p.closeSubpath()
        }
        .fill(Theme.page)
        KPath(transform: lift) { p in
            for y in stride(from: 176.0, through: 186, by: 5) {
                p.move(to: pt(80, y)); p.addLine(to: pt(94, y + 2))
                p.move(to: pt(106, y + 2)); p.addLine(to: pt(120, y))
            }
        }
        .stroke(Theme.furDark.opacity(0.2), style: StrokeStyle(lineWidth: 1.5 * s, lineCap: .round))
    }

    @ViewBuilder
    private func yarn(_ p: Pose, _ s: CGFloat) -> some View {
        let lift = CGAffineTransform(translationX: scene ? -22 : 0, y: deskLift)
        let center = CGPoint(x: 168, y: 181)
        KPath(transform: lift) { path in
            path.move(to: pt(155, 186))
            path.addQuadCurve(to: pt(128, 190), control: pt(140, 198))
        }
        .stroke(Theme.blush, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
        KPath(transform: lift, build: ellipse(155, 168, 26, 26)).fill(Theme.blush)
        KPath(transform: rotate(CGFloat(p.t * 40), around: center).concatenating(lift)) { path in
            path.move(to: pt(158, 174)); path.addQuadCurve(to: pt(176, 192), control: pt(174, 174))
            path.move(to: pt(157, 184)); path.addQuadCurve(to: pt(172, 170), control: pt(160, 170))
        }
        .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
    }

    // MARK: Scene

    @ViewBuilder
    private func desk(_ s: CGFloat) -> some View {
        KPath { $0.addRect(CGRect(x: -60, y: 174, width: 320, height: 100)) }
            .fill(night ? Theme.deskFrontNight : Theme.deskFrontDay)
        KPath { $0.addRect(CGRect(x: -60, y: 160, width: 320, height: 14)) }
            .fill(night ? Theme.deskTopNight : Theme.deskTopDay)
        KPath { p in p.move(to: pt(-60, 160.5)); p.addLine(to: pt(260, 160.5)) }
            .stroke(Color.white.opacity(night ? 0.12 : 0.35), lineWidth: 1.5 * s)
    }

    /// Wall, window, pennant, and (at night) the lamp: everything behind her.
    @ViewBuilder
    private func sceneBack(_ p: Pose, _ s: CGFloat) -> some View {
        let frame = night ? Theme.windowFrameNight : Theme.windowFrameDay
        KPath { $0.addRect(CGRect(x: -60, y: -60, width: 320, height: 320)) }
            .fill(night ? Theme.wallNight : Theme.wallDay)

        // Window
        KPath { $0.addRoundedRect(in: CGRect(x: -2, y: 30, width: 50, height: 60), cornerSize: CGSize(width: 6, height: 6)) }.fill(frame)
        // The window shows the real time of day, whatever mode the app is in.
        let clock = self.clock
        let pane = CGRect(x: 3, y: 35, width: 40, height: 50)
        ZStack {
            KPath { $0.addRoundedRect(in: pane, cornerSize: CGSize(width: 3, height: 3)) }
                .fill(LinearGradient(colors: [clock.top, clock.horizon],
                                     startPoint: UnitPoint(x: 0.5, y: pane.minY / 200),
                                     endPoint: UnitPoint(x: 0.5, y: pane.maxY / 200)))
            if clock.daylight < 1 {
                KPath(build: ellipse(24, 40, 13, 13)).fill(Theme.moon.opacity(1 - clock.daylight))
                KPath(build: ellipse(28.5, 37.5, 12, 12)).fill(clock.top)
                ForEach(0..<5, id: \.self) { i in
                    let star = [pt(10, 44), pt(16, 70), pt(36, 62), pt(9, 80), pt(38, 79)][i]
                    KPath(build: ellipse(star.x - 1.3, star.y - 1.3, 2.6, 2.6))
                        .fill(Color.white.opacity((0.55 + 0.45 * sin(p.t * 1.7 + Double(i) * 1.3)) * (1 - clock.daylight)))
                }
            }
            if clock.daylight > 0 {
                let arc = min(1, max(0, clock.sunArc))
                let sun = pt(8 + 30 * arc, 80 - sin(.pi * arc) * 38)
                KPath(build: ellipse(sun.x - 5.5, sun.y - 5.5, 11, 11)).fill(clock.sunColor.opacity(clock.daylight))
                KPath { c in
                    c.addEllipse(in: CGRect(x: 7, y: 60, width: 16, height: 8))
                    c.addEllipse(in: CGRect(x: 13, y: 55, width: 13, height: 11))
                    c.addEllipse(in: CGRect(x: 20, y: 60, width: 14, height: 8))
                }
                .fill(Color.white.opacity(0.9 * clock.daylight))
            }
        }
        .clipShape(KPath { $0.addRoundedRect(in: pane, cornerSize: CGSize(width: 3, height: 3)) })
        KPath { c in
            c.move(to: pt(23, 35)); c.addLine(to: pt(23, 85))
            c.move(to: pt(3, 60)); c.addLine(to: pt(43, 60))
        }
        .stroke(frame, lineWidth: 3 * s)
        KPath { $0.addRoundedRect(in: CGRect(x: -5, y: 88, width: 56, height: 5), cornerSize: CGSize(width: 2, height: 2)) }.fill(frame)

        // Hopkins pennant
        KPath(build: poly([pt(156, 24), pt(156, 48), pt(199, 37)])).fill(Theme.hopkinsBlue)
        KPath(build: ellipse(153.5, 22.5, 5, 5)).fill(Theme.blush)
        Text("HOPKINS")
            .font(.system(size: 6.2 * s, weight: .heavy, design: .rounded))
            .tracking(0.3 * s)
            .foregroundStyle(Color.white)
            .fixedSize()
            .rotationEffect(.degrees(-7))
            .position(x: 173 * s, y: 36.5 * s)

        if night {
            // Desk lamp on the left, glowing warm
            KPath(build: ellipse(12, 154, 32, 8)).fill(Theme.lampMetal)
            KPath { c in c.move(to: pt(28, 157)); c.addLine(to: pt(34, 112)) }
                .stroke(Theme.lampMetal, style: StrokeStyle(lineWidth: 3.5 * s, lineCap: .round))
            KPath(build: ellipse(24, 118, 22, 7)).fill(Theme.glow)
            rounded(KPath(build: poly([pt(28, 102), pt(42, 102), pt(52, 122), pt(18, 122)])), Theme.lampShade, 4 * s)
        }
    }

    /// Things on the desk in front of her, plus the lamp's glow at night.
    @ViewBuilder
    private func sceneFront(_ p: Pose, _ s: CGFloat) -> some View {
        if night {
            // Steaming mug of tea, on the right
            KPath { c in c.addEllipse(in: CGRect(x: 172, y: 147, width: 12, height: 14)) }
                .stroke(Theme.mug, lineWidth: 3.5 * s)
            KPath { $0.addRoundedRect(in: CGRect(x: 150, y: 140, width: 26, height: 28), cornerSize: CGSize(width: 5, height: 5)) }
                .fill(Theme.mug)
            KPath { $0.addRect(CGRect(x: 150, y: 146, width: 26, height: 4)) }.fill(Color.white.opacity(0.3))
            KPath { c in c.move(to: pt(155, 141)); c.addLine(to: pt(146, 152)) }
                .stroke(Color.white.opacity(0.8), lineWidth: 0.8 * s)
            KPath { $0.addRect(CGRect(x: 141, y: 151, width: 7, height: 8)) }.fill(Theme.highlighter.opacity(0.9))
            ForEach(0..<2, id: \.self) { i in
                let phase = (p.t / 2.4 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let x: CGFloat = i == 0 ? 158 : 168
                KPath(transform: CGAffineTransform(translationX: 0, y: -phase * 10)) { c in
                    c.move(to: pt(x, 136))
                    c.addQuadCurve(to: pt(x, 124), control: pt(x - 5, 130))
                    c.addQuadCurve(to: pt(x, 112), control: pt(x + 5, 118))
                }
                .stroke(Color.white.opacity(sin(phase * .pi) * 0.55), style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
            }

            // Evening: dim the whole room, then let the lamp warm it back up.
            Color.clear
                .overlay {
                    Theme.nightShade.opacity(0.42)
                        .frame(width: 200 * s * 1.6, height: 200 * s * 1.6)
                }
                .blendMode(.multiply)
                .allowsHitTesting(false)
            KPath(build: poly([pt(18, 122), pt(50, 122), pt(64, 160), pt(-4, 160)]))
                .fill(Theme.glow.opacity(0.14))
                .blendMode(.screen)
            Color.clear
                .overlay {
                    RadialGradient(colors: [Theme.glow.opacity(0.5), Theme.glow.opacity(0.14), .clear],
                                   center: unit(35, 122, extend: 1.6), startRadius: 0, endRadius: 120 * s)
                        .frame(width: 200 * s * 1.6, height: 200 * s * 1.6)
                }
                .blendMode(.screen)
                .allowsHitTesting(false)
        } else {
            // Iced coffee
            KPath { c in
                c.move(to: pt(38, 131)); c.addLine(to: pt(42, 116)); c.addLine(to: pt(48, 113))
            }
            .stroke(Theme.blush, style: StrokeStyle(lineWidth: 3 * s, lineCap: .round, lineJoin: .round))
            KPath(build: poly([pt(23, 138), pt(45, 138), pt(43, 168), pt(25, 168)])).fill(Theme.coffee)
            KPath(build: poly([pt(23, 138), pt(45, 138), pt(44.5, 144), pt(23.5, 144)])).fill(Theme.coffeeMilk)
            KPath { c in
                c.addRoundedRect(in: CGRect(x: 26, y: 146, width: 7, height: 7), cornerSize: CGSize(width: 1.5, height: 1.5))
                c.addRoundedRect(in: CGRect(x: 34, y: 150, width: 7, height: 7), cornerSize: CGSize(width: 1.5, height: 1.5))
            }
            .fill(Color.white.opacity(0.45))
            KPath(build: poly([pt(21, 131), pt(47, 131), pt(43.5, 170), pt(24.5, 170)])).fill(Color.white.opacity(0.22))
            KPath(build: poly([pt(21, 131), pt(47, 131), pt(43.5, 170), pt(24.5, 170)]))
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5 * s, lineJoin: .round))

            // Little succulent
            ForEach(0..<5, id: \.self) { i in
                let angle = [-60.0, -25, 0, 25, 60][i]
                KPath(transform: rotate(angle, around: pt(177, 152)), build: ellipse(173, 134, 8, 18))
                    .fill(Theme.leaf.mix(with: .black, by: i % 2 == 0 ? 0 : 0.12))
            }
            KPath(build: poly([pt(166, 150), pt(188, 150), pt(185, 172), pt(169, 172)])).fill(Theme.pot)
            KPath { $0.addRect(CGRect(x: 165, y: 149, width: 24, height: 5)) }.fill(Theme.pot.mix(with: .white, by: 0.15))
        }
    }

    /// Where a point in her 200×200 space lands in a frame `extend` times bigger, centered on hers.
    private func unit(_ x: CGFloat, _ y: CGFloat, extend: CGFloat) -> UnitPoint {
        UnitPoint(x: (x / 200 + (extend - 1) / 2) / extend, y: (y / 200 + (extend - 1) / 2) / extend)
    }

    // MARK: Head

    private var headOnlyTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: 28).concatenating(scale(1.5, 1.5, around: CGPoint(x: 100, y: 100)))
    }

    @ViewBuilder
    private func headLayers(_ p: Pose, _ s: CGFloat) -> some View {
        let base = headOnly ? headOnlyTransform : .identity
        let head = scale(1, p.headSquash, around: CGPoint(x: 100, y: 130))
            .concatenating(rotate(p.headTilt, around: CGPoint(x: 100, y: 130)))
            .concatenating(base)
        let k = headOnly ? s * 1.5 : s
        let leftEar = rotate(p.leftEar, around: CGPoint(x: 72, y: 52)).concatenating(head)
        let rightEar = rotate(p.rightEar, around: CGPoint(x: 128, y: 52)).concatenating(head)

        // Ears
        rounded(KPath(transform: leftEar) { $0.addLines([CGPoint(x: 50, y: 64), CGPoint(x: 54, y: 12), CGPoint(x: 94, y: 42)]); $0.closeSubpath() },
                Theme.fur, 8 * k)
        rounded(KPath(transform: rightEar) { $0.addLines([CGPoint(x: 150, y: 64), CGPoint(x: 146, y: 12), CGPoint(x: 106, y: 42)]); $0.closeSubpath() },
                Theme.fur, 8 * k)
        rounded(KPath(transform: leftEar) { $0.addLines([CGPoint(x: 60, y: 54), CGPoint(x: 61, y: 26), CGPoint(x: 83, y: 42)]); $0.closeSubpath() },
                Theme.blush, 4 * k)
        rounded(KPath(transform: rightEar) { $0.addLines([CGPoint(x: 140, y: 54), CGPoint(x: 139, y: 26), CGPoint(x: 117, y: 42)]); $0.closeSubpath() },
                Theme.blush, 4 * k)

        // Head, muzzle, cheeks
        KPath(transform: head, build: ellipse(42, 34, 116, 100)).fill(Theme.fur)
        KPath(transform: head, build: ellipse(80, 96, 40, 26)).fill(Theme.furLight.opacity(0.7))
        KPath(transform: head, build: ellipse(50, 100, 22, 12)).fill(Theme.blush.opacity(0.55))
        KPath(transform: head, build: ellipse(128, 100, 22, 12)).fill(Theme.blush.opacity(0.55))

        eyes(p, head, k)
        if night {
            KPath(transform: head) { c in
                c.addEllipse(in: CGRect(x: 59, y: 69, width: 34, height: 34))
                c.addEllipse(in: CGRect(x: 107, y: 69, width: 34, height: 34))
                c.move(to: pt(93, 85)); c.addQuadCurve(to: pt(107, 85), control: pt(100, 80))
                c.move(to: pt(59, 84)); c.addLine(to: pt(46, 80))
                c.move(to: pt(141, 84)); c.addLine(to: pt(154, 80))
            }
            .stroke(Theme.glasses, style: StrokeStyle(lineWidth: 2.6 * k, lineCap: .round))
        }

        // Nose and mouth
        rounded(KPath(transform: head) { $0.addLines([CGPoint(x: 95, y: 101), CGPoint(x: 105, y: 101), CGPoint(x: 100, y: 107)]); $0.closeSubpath() },
                Theme.blush, 3 * k)
        if p.mouthOpen {
            KPath(transform: head) { path in
                path.move(to: CGPoint(x: 93, y: 110))
                path.addQuadCurve(to: CGPoint(x: 107, y: 110), control: CGPoint(x: 100, y: 124))
                path.closeSubpath()
            }
            .fill(Color(hex: 0xC9606A))
        }
        KPath(transform: head) { path in
            path.move(to: CGPoint(x: 100, y: 107)); path.addQuadCurve(to: CGPoint(x: 91, y: 111), control: CGPoint(x: 97, y: 113))
            path.move(to: CGPoint(x: 100, y: 107)); path.addQuadCurve(to: CGPoint(x: 109, y: 111), control: CGPoint(x: 103, y: 113))
        }
        .stroke(Theme.furDark, style: StrokeStyle(lineWidth: 2.5 * k, lineCap: .round))

        if !headOnly {
            KPath(transform: head) { path in
                path.move(to: CGPoint(x: 60, y: 106)); path.addLine(to: CGPoint(x: 34, y: 101))
                path.move(to: CGPoint(x: 60, y: 111)); path.addLine(to: CGPoint(x: 35, y: 115))
                path.move(to: CGPoint(x: 140, y: 106)); path.addLine(to: CGPoint(x: 166, y: 101))
                path.move(to: CGPoint(x: 140, y: 111)); path.addLine(to: CGPoint(x: 165, y: 115))
            }
            .stroke(Theme.furDark.opacity(0.45), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
        }
    }

    @ViewBuilder
    private func eyes(_ p: Pose, _ head: CGAffineTransform, _ k: CGFloat) -> some View {
        let stroke = StrokeStyle(lineWidth: 3.5 * k, lineCap: .round, lineJoin: .round)
        ForEach([CGFloat(76), CGFloat(124)], id: \.self) { cx in
            switch p.eyes {
            case .open:
                let eye = scale(1, p.blink ? 0.1 : 1, around: CGPoint(x: cx, y: 86)).concatenating(head)
                KPath(transform: eye, build: ellipse(cx - 15, 68, 30, 36)).fill(Theme.eyeWhite)
                KPath(transform: eye, build: ellipse(cx - 7 + p.look.x, 74 + p.look.y, 14, 24)).fill(Theme.furDark)
                KPath(transform: eye, build: ellipse(cx - 4 + p.look.x, 78 + p.look.y, 5, 5)).fill(Color.white)
            case .closed:
                KPath(transform: head) { path in
                    path.move(to: CGPoint(x: cx - 11, y: 84))
                    path.addQuadCurve(to: CGPoint(x: cx + 11, y: 84), control: CGPoint(x: cx, y: 95))
                }
                .stroke(Theme.furDark, style: stroke)
            case .happy:
                KPath(transform: head) { path in
                    path.move(to: CGPoint(x: cx - 11, y: 90))
                    path.addQuadCurve(to: CGPoint(x: cx + 11, y: 90), control: CGPoint(x: cx, y: 74))
                }
                .stroke(Theme.furDark, style: stroke)
            case .squeeze:
                // > <
                let dir: CGFloat = cx < 100 ? 1 : -1
                KPath(transform: head) { path in
                    path.move(to: CGPoint(x: cx - 9 * dir, y: 78))
                    path.addLine(to: CGPoint(x: cx + 9 * dir, y: 86))
                    path.addLine(to: CGPoint(x: cx - 9 * dir, y: 94))
                }
                .stroke(Theme.furDark, style: stroke)
            }
        }
    }

    private func rounded(_ shape: KPath, _ color: Color, _ corner: CGFloat) -> some View {
        ZStack {
            shape.fill(color)
            shape.stroke(color, style: StrokeStyle(lineWidth: corner, lineJoin: .round))
        }
    }

    // MARK: Hearts & extras

    @ViewBuilder
    private func hearts(_ p: Pose, _ s: CGFloat) -> some View {
        let xs: [Double] = [28, 172, 150]
        ForEach(0..<3, id: \.self) { i in
            let phase = (p.t / 1.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            Image(systemName: "heart.fill")
                .font(.system(size: 18 * s))
                .foregroundStyle(Theme.blush)
                .opacity(1 - phase)
                .position(x: (xs[i] + sin(phase * 6) * 6) * s, y: (80 - phase * 60) * s)
        }
    }

    @ViewBuilder
    private func extras(_ p: Pose, _ s: CGFloat) -> some View {
        if let u = p.floatHeart {
            Image(systemName: "heart.fill")
                .font(.system(size: 22 * s))
                .foregroundStyle(Theme.blush)
                .scaleEffect(0.6 + min(1, u * 4) * 0.4)
                .opacity(1 - u)
                .position(x: (148 + sin(u * 8) * 4) * s, y: (40 - u * 36) * s)
        }
        if let u = p.purrText {
            Text("purr")
                .font(.system(size: 15 * s, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.caramel)
                .rotationEffect(.degrees(-8))
                .opacity(u < 0.15 ? u / 0.15 : 1 - u)
                .position(x: (160 + sin(u * 10) * 3) * s, y: (140 - u * 40) * s)
        }
    }
}

#Preview {
    HStack {
        KittyView(mood: .idle, interactive: true)
        KittyView(mood: .focus)
    }
    HStack {
        KittyView(mood: .rest, interactive: true)
        KittyView(mood: .happy, interactive: true)
    }
}
