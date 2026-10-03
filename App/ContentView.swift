import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.scenePhase) private var scenePhase
    @State private var showHistory = false
    @State private var showSettings = false

    var body: some View {
        let snap = engine.snap
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TodayHeader(snap: snap, showHistory: $showHistory, showSettings: $showSettings)
                Spacer(minLength: 8)
                TimerDial(snap: snap)
                Controls(snap: snap)
                    .padding(.top, 24)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: snap.run)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: snap.phase)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { engine.refresh() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().presentationDragIndicator(.visible).followsNight()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView().presentationDragIndicator(.visible).followsNight()
        }
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            IconRenderer.renderIfRequested()
            if args.contains("-showHistory") { showHistory = true }
            if args.contains("-showSettings") { showSettings = true }
            if args.contains("-autoStart"), engine.snap.run == .idle { engine.startFocus() }
        }
        #endif
    }
}

// MARK: Header

private struct TodayHeader: View {
    let snap: TimerSnapshot
    @Binding var showHistory: Bool
    @Binding var showSettings: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            let tally = snap.tally(on: context.date)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text("Purrmodoro")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.caramel)
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.caramel.opacity(0.7))
                            .rotationEffect(.degrees(18))
                            .offset(y: -6)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    Spacer()
                    HStack(spacing: 10) {
                        circleButton("gearshape.fill", label: "Settings") { showSettings = true }
                        circleButton("book.closed.fill", label: "Focus notebook") { showHistory = true }
                    }
                }
                PawRow(progress: snap.pawProgress(on: context.date), note: summary(tally))
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.caramel)
                .frame(width: 48, height: 48)
                .background(Theme.card, in: Circle())
        }
        .buttonStyle(SquishStyle())
        .accessibilityLabel(label)
    }

    private func summary(_ tally: (seconds: Int, sessions: Int)) -> String {
        tally.seconds > 0 ? "\(Format.duration(tally.seconds)) today" : "Nothing yet today"
    }
}

/// One paw slot per session until the long break: filled paws are done, outlines are to go.
/// Paws toward the long break, then today's focus time, all on one line.
private struct PawRow: View {
    let progress: (filled: Int, total: Int)
    let note: String

    var body: some View {
        let filled = min(progress.filled, progress.total)
        let left = progress.total - filled
        HStack(spacing: 4) {
            ForEach(0..<progress.total, id: \.self) { i in
                ZStack {
                    Image(systemName: "pawprint")
                        .foregroundStyle(Theme.inkSoft.opacity(0.35))
                        .opacity(i < filled ? 0 : 1)
                    if i < filled {
                        // New paws "stamp" in: drop from big to size with a little bounce.
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(Theme.caramel)
                            .transition(.asymmetric(insertion: .scale(scale: 2.6).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                }
            }
            Text(left == 0 ? "long break next" : note)
                .font(.rounded(.footnote, weight: .semibold))
                .foregroundStyle(left == 0 ? Theme.sage : Theme.inkSoft)
                .padding(.leading, 6)
                .contentTransition(.numericText())
        }
        .font(.system(size: 15))
        .animation(.spring(response: 0.35, dampingFraction: 0.45), value: filled)
        .accessibilityElement()
        .accessibilityLabel(left == 0 ? "Long break next. \(note)" : "\(filled) of \(progress.total) sessions until a long break. \(note)")
    }
}

// MARK: Dial

private struct TimerDial: View {
    @Environment(TimerEngine.self) private var engine
    let snap: TimerSnapshot

    /// Degrees wound so far (0...360) while her finger is on the dial.
    @State private var wound: Double?
    @State private var lastAngle: Double = 0
    @State private var lookAt: CGPoint = .zero

    private var woundMinutes: Int? { wound.map { max(1, Int(($0 / 6).rounded())) } }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = woundMinutes.map { Double($0) * 60 } ?? snap.remaining(at: context.date)
            let progress = wound.map { $0 / 360 } ?? snap.progress(at: context.date)
            VStack(spacing: 16) {
                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height)
                    ZStack {
                        // Her little room, seen through the timer ring.
                        KittyView(mood: snap.mood,
                                  scene: true,
                                  interactive: snap.mood != .focus,
                                  onReact: PetFeedback.play,
                                  lookAt: lookAt)
                            .padding(36)
                            .clipShape(Circle().inset(by: 8))
                        Circle().stroke(Theme.track, lineWidth: 16)
                        ClockMarks(radius: size / 2)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Theme.accent(for: snap.phase), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(wound == nil ? .linear(duration: 1) : nil, value: progress)
                        if let wound {
                            // The little knob she's winding
                            Circle()
                                .fill(Theme.caramel)
                                .overlay(Image(systemName: "pawprint.fill").font(.system(size: 11)).foregroundStyle(.white))
                                .frame(width: 26, height: 26)
                                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                .offset(x: sin(wound * .pi / 180) * size / 2, y: -cos(wound * .pi / 180) * size / 2)
                        }
                    }
                    .frame(width: size, height: size)
                    .contentShape(Circle())
                    .gesture(windGesture(size: size))
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: 300, maxHeight: 300)
                .aspectRatio(1, contentMode: .fit)
                #if DEBUG
                .task {
                    // Freeze mid-wind for screenshots.
                    if ProcessInfo.processInfo.arguments.contains("-demoWind") {
                        wound = 132
                        lookAt = CGPoint(x: sin(132 * .pi / 180), y: -cos(132 * .pi / 180))
                    }
                }
                #endif

                VStack(spacing: 4) {
                    Text(snap.run == .finished && wound == nil ? "Done!" : Format.clock(remaining))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(countsDown: wound == nil))
                        .animation(.snappy, value: remaining)
                    let line = wound == nil ? status(at: context.date) : "Let go to set"
                    Text(line)
                        .font(.rounded(.title3, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .id(line)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                        .animation(.easeInOut(duration: 0.5), value: line)
                }
            }
        }
    }

    /// Drag around the ring, clockwise from the top: halfway is 30 minutes, a full turn is 60.
    /// Only when nothing's running. A plain tap still pets the kitty.
    private func windGesture(size: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard snap.run == .idle else { return }
                let dx = value.location.x - size / 2
                let dy = value.location.y - size / 2
                var angle = atan2(dx, -dy) * 180 / .pi
                if angle < 0 { angle += 360 }
                let before = woundMinutes
                if let current = wound {
                    var delta = angle - lastAngle
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    wound = min(360, max(0, current + delta))
                } else {
                    // Starting near the top (just left of it) counts as zero.
                    wound = angle < 330 ? angle : 0
                }
                lastAngle = angle
                lookAt = CGPoint(x: sin(angle * .pi / 180), y: -cos(angle * .pi / 180))
                if let now = woundMinutes, now != before {
                    Haptics.select()
                    if now % 5 == 0 { SoundPlayer.shared.play(.tick, volume: 0.3) }
                }
            }
            .onEnded { _ in
                guard wound != nil else { return }
                if let minutes = woundMinutes { engine.setWoundTime(minutes) }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    wound = nil
                    lookAt = .zero
                }
            }
    }

    private func status(at date: Date) -> String {
        switch (snap.run, snap.phase) {
        case (.idle, _): return "Ready when you are"
        case (.paused, _): return "Paused"
        case (.running(let end), .focus):
            return FocusLines.line(elapsed: date.timeIntervalSince(snap.phaseStart ?? date),
                                   remaining: end.timeIntervalSince(date),
                                   session: snap.sessionStart)
        case (.running(let end), _):
            return FocusLines.breakLine(elapsed: date.timeIntervalSince(snap.phaseStart ?? date),
                                        remaining: end.timeIntervalSince(date),
                                        long: snap.phase == .longBreak,
                                        seed: snap.phaseStart)
        case (.finished, .focus): return "Done! Break time"
        case (.finished, _): return "Break's over. Back at it?"
        }
    }
}

/// Twelve tiny dots around the ring, like a kitchen timer's face. A quiet hint it can be wound.
private struct ClockMarks: View {
    let radius: CGFloat

    var body: some View {
        ForEach(0..<12, id: \.self) { i in
            let angle = Double(i) * 30 * .pi / 180
            Circle()
                .fill(Theme.inkSoft.opacity(i == 0 ? 0.45 : 0.25))
                .frame(width: i == 0 ? 5 : 3.5, height: i == 0 ? 5 : 3.5)
                .offset(x: sin(angle) * radius, y: -cos(angle) * radius)
        }
        .allowsHitTesting(false)
    }
}

// MARK: Controls

private struct Controls: View {
    @Environment(TimerEngine.self) private var engine
    let snap: TimerSnapshot
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 16) {
            switch snap.run {
            case .idle:
                PresetPicker(snap: snap,
                             choose: { engine.choosePreset($0) },
                             openCustom: { showCustom = true })
                Button { engine.startFocus() } label: {
                    Label("Start focus", systemImage: "play.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.caramel))

            case .running, .paused:
                let paused = snap.run.isPaused
                HStack(spacing: 14) {
                    Button { engine.stop() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(RoundButtonStyle())
                    .accessibilityLabel("Stop")

                    Button { paused ? engine.resume() : engine.pause() } label: {
                        Label(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.accent(for: snap.phase)))
                }

            case .finished:
                if snap.phase == .focus {
                    let minutes = snap.nextBreak == .longBreak ? snap.longBreakMinutes : snap.shortBreakMinutes
                    Button { engine.startBreak() } label: {
                        Label("Start \(minutes)-min break", systemImage: "cup.and.saucer.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.sage))
                    Button("Skip break") { engine.skipBreak() }
                        .buttonStyle(TextLinkStyle())
                } else {
                    Button { engine.startFocus() } label: {
                        Label("Start focus", systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.caramel))
                    Button("Call it a day") { engine.finishForNow() }
                        .buttonStyle(TextLinkStyle())
                }
            }
        }
        .frame(height: 150, alignment: .top)
        .sheet(isPresented: $showCustom) {
            TimesSheet(snap: snap) { presets, selected, short, long, every in
                engine.setTimes(presets: presets, selected: selected, shortBreak: short, longBreak: long, longBreakEvery: every)
                showCustom = false
            }
            .presentationDetents([.height(650)])
            .followsNight()
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
        #if DEBUG
        .task { if ProcessInfo.processInfo.arguments.contains("-showCustom") { showCustom = true } }
        #endif
    }
}

private struct PresetPicker: View {
    let snap: TimerSnapshot
    let choose: (Int) -> Void
    let openCustom: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(snap.presets.indices, id: \.self) { i in
                let minutes = snap.presets[i]
                chip(isOn: minutes == snap.focusMinutes) {
                    Text("\(minutes)")
                } action: {
                    choose(minutes)
                }
                .accessibilityLabel("\(minutes) minutes")
            }

            chip(isOn: false) {
                Image(systemName: "slider.horizontal.3")
            } action: {
                Haptics.tap()
                openCustom()
            }
            .accessibilityLabel("Edit your times")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: snap.focusMinutes)
    }

    private func chip<Label: View>(isOn: Bool, @ViewBuilder label: () -> Label, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label()
                .font(.rounded(.headline, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isOn ? Theme.caramel : Theme.card, in: Capsule())
        }
        .buttonStyle(SquishStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: Your times

private struct TimesSheet: View {
    let onSave: ([Int], Int, Int, Int, Int) -> Void
    @State private var presets: [Int]
    @State private var slot: Int
    @State private var shortBreak: Int
    @State private var longBreak: Int
    @State private var longBreakEvery: Int

    private static let slotNames = ["short", "medium", "long"]

    private static func options(for slot: Int) -> [Int] {
        let (range, step) = TimerSnapshot.presetRanges[slot]
        return Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }

    init(snap: TimerSnapshot, onSave: @escaping ([Int], Int, Int, Int, Int) -> Void) {
        self.onSave = onSave
        let presets = snap.presets.enumerated().map { TimerSnapshot.fitPreset($0.element, slot: $0.offset) }
        _presets = State(initialValue: presets)
        _slot = State(initialValue: presets.firstIndex(of: snap.focusMinutes) ?? 1)
        _shortBreak = State(initialValue: snap.shortBreakMinutes)
        _longBreak = State(initialValue: snap.longBreakMinutes)
        _longBreakEvery = State(initialValue: snap.longBreakEvery)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Kitty and title, centered over the presets.
            HStack(spacing: 10) {
                KittyView(mood: .idle).frame(width: 52, height: 52)
                Text("Your focus times")
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    ForEach(presets.indices, id: \.self) { i in
                        let isOn = i == slot
                        Button {
                            Haptics.select()
                            slot = i
                        } label: {
                            VStack(spacing: 0) {
                                Text("\(presets[i])")
                                    .font(.rounded(.title3, weight: .bold))
                                    .contentTransition(.numericText())
                                Text(Self.slotNames[i])
                                    .font(.rounded(.caption2, weight: .semibold))
                                    .opacity(0.75)
                            }
                            .foregroundStyle(isOn ? Color.white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isOn ? Theme.caramel : Theme.card, in: Capsule())
                        }
                        .buttonStyle(SquishStyle())
                        .accessibilityLabel("Preset \(i + 1), \(presets[i]) minutes")
                    }
                }
                .animation(.snappy, value: presets)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: slot)

                Picker("Focus", selection: $presets[slot]) {
                    ForEach(Self.options(for: slot), id: \.self) { m in
                        Text("\(m) min").font(.rounded(.title2, weight: .semibold)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .id(slot)
                .frame(height: 140)
                .sensoryFeedback(.selection, trigger: presets[slot])

            }

            VStack(spacing: 10) {
                StepperRow(title: "Short break", subtitle: "minutes between sessions",
                           icon: "cup.and.saucer.fill", value: $shortBreak, range: 1...30, step: 1)
                // How long the long break is, and how often it comes: one idea, one card.
                VStack(spacing: 0) {
                    StepperRow(title: "Long break", subtitle: "minutes",
                               icon: "sofa.fill", value: $longBreak, range: 5...60, step: 5, card: false)
                    Divider().overlay(Theme.track).padding(.leading, 52)
                    StepperRow(title: "After every", subtitle: "focus sessions",
                               icon: "pawprint.fill", value: $longBreakEvery, range: TimerSnapshot.longBreakRange, step: 1, card: false)
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Spacer(minLength: 0)

            Button { onSave(presets, presets[slot], shortBreak, longBreak, longBreakEvery) } label: {
                Text("Save")
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.caramel))
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .background(Theme.background)
    }
}

/// A setting row: title with a small explanatory subtitle on the left,
/// − number + on the right. Numbers sit in a fixed column so every row lines up.
private struct StepperRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    /// Draw its own card background (off when grouped with another row).
    var card = true

    @State private var dragStart: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Theme.sage)
                .frame(width: 26)
            // Subtitles wrap rather than cut off, even with large text sizes.
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                RepeatButton(symbol: "minus", enabled: value - step >= range.lowerBound) { nudge(-1) }
                number
                RepeatButton(symbol: "plus", enabled: value + step <= range.upperBound) { nudge(1) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(card ? Theme.card : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy, value: value)
        .sensoryFeedback(.selection, trigger: value)
    }

    /// Drag up or down on the number to scrub through values.
    private var number: some View {
        Text("\(value)")
            .font(.rounded(.title3, weight: .bold))
            .foregroundStyle(dragStart == nil ? Theme.ink : Theme.caramel)
            .monospacedDigit()
            .contentTransition(.numericText())
            .frame(width: 40, height: 44)
            .background(dragStart == nil ? Color.clear : Theme.background,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(dragStart == nil ? 1 : 1.15)
            .contentShape(Rectangle())
            // High priority so dragging the number doesn't also drag the sheet closed.
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = value }
                        let steps = Int((-drag.translation.height / 14).rounded(.towardZero))
                        value = min(range.upperBound, max(range.lowerBound, start + steps * step))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragStart)
            .accessibilityLabel("\(title), \(value) \(subtitle)")
            .accessibilityAdjustableAction { direction in
                nudge(direction == .increment ? 1 : -1)
            }
    }

    private func nudge(_ direction: Int) {
        value = min(range.upperBound, max(range.lowerBound, value + direction * step))
    }
}

/// A round + / − button. Tap for one step; hold to keep going.
private struct RepeatButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    @State private var repeater: Task<Void, Never>?
    @State private var pressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(enabled ? Theme.caramel : Theme.inkSoft.opacity(0.4))
            .frame(width: 34, height: 34)
            .background(Theme.background, in: Circle())
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard enabled, !pressed else { return }
                        pressed = true
                        action()
                        repeater = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            while !Task.isCancelled {
                                action()
                                try? await Task.sleep(for: .milliseconds(90))
                            }
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        repeater?.cancel()
                        repeater = nil
                    }
            )
            .accessibilityHidden(true)
    }
}

// MARK: Button styles

/// Big, cartoony button with a "thick" bottom edge that squishes down when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.rounded(.title3, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Capsule().fill(color))
            .background(Capsule().fill(color.mix(with: .black, by: 0.22)).offset(y: pressed ? 1 : 5))
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 5)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

struct RoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 60, height: 60)
            .background(Circle().fill(Theme.card))
            .background(Circle().fill(Theme.track.mix(with: .black, by: 0.08)).offset(y: pressed ? 1 : 5))
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 5)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct TextLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.body, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .frame(height: 30)
    }
}
