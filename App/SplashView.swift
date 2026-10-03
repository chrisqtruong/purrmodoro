import SwiftUI

/// A one-second hello when the app starts fresh: little paw prints sketch themselves in,
/// walking across the screen, then everything fades into the app. Tap to skip.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var leaving = false

    private let steps = 4

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = reduceMotion ? 10 : context.date.timeIntervalSince(start)
            ZStack {
                Theme.background.ignoresSafeArea()
                ForEach(0..<steps, id: \.self) { i in
                    let begin = Double(i) * 0.18
                    let sketch = clamp((elapsed - begin) / 0.35)
                    let fill = clamp((elapsed - begin - 0.3) / 0.2)
                    ZStack {
                        PawShape().fill(Theme.caramel.opacity(0.9 * fill))
                        PawShape()
                            .trim(from: 0, to: sketch)
                            .stroke(Theme.caramel, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(47))
                    .offset(position(i))
                }
                Text("Purrmodoro")
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .opacity(clamp((elapsed - 0.75) / 0.3))
                    .offset(y: 110)
            }
        }
        .opacity(leaving ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1250))
            finish()
        }
        .accessibilityHidden(true)
    }

    /// Steps walk from lower-left to upper-right, alternating left and right paws.
    private func position(_ i: Int) -> CGSize {
        let t = Double(i) / Double(steps - 1)
        let along = CGPoint(x: -70 + 120 * t, y: 60 - 110 * t)
        let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
        return CGSize(width: along.x + 0.676 * 13 * side, height: along.y + 0.737 * 13 * side)
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    private func finish() {
        guard !leaving else { return }
        withAnimation(.easeOut(duration: 0.35)) { leaving = true }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            onFinish()
        }
    }
}

/// A paw print: one big pad and four toe beans, pointing up.
struct PawShape: Shape {
    func path(in rect: CGRect) -> Path {
        func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height,
                   width: w * rect.width, height: h * rect.height)
        }
        var p = Path()
        p.addEllipse(in: oval(0.22, 0.46, 0.56, 0.48))
        p.addEllipse(in: oval(0.02, 0.26, 0.2, 0.26))
        p.addEllipse(in: oval(0.25, 0.04, 0.2, 0.28))
        p.addEllipse(in: oval(0.55, 0.04, 0.2, 0.28))
        p.addEllipse(in: oval(0.78, 0.26, 0.2, 0.26))
        return p
    }
}
