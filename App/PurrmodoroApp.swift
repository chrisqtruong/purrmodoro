import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct PurrmodoroApp: App {
    private let container: ModelContainer
    @State private var engine: TimerEngine

    init() {
        let container = try! ModelContainer(for: FocusSession.self, DayNote.self)
        #if DEBUG
        DemoData.seedIfRequested(container.mainContext)
        #endif
        self.container = container
        _engine = State(initialValue: TimerEngine(context: container.mainContext))
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        Self.useRoundedNavigationTitles()
    }

    /// Big sheet titles ("Settings", "Focus notebook") in the same rounded type as the rest of the app.
    private static func useRoundedNavigationTitles() {
        func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        }
        let bar = UINavigationBar.appearance()
        let ink = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xE6DDD1) : UIColor(hex: 0x4A3222) }
        bar.largeTitleTextAttributes = [.font: rounded(34, .bold), .foregroundColor: ink]
        bar.titleTextAttributes = [.font: rounded(17, .semibold), .foregroundColor: ink]
    }

    /// Only on a fresh start; switching back to the app skips it.
    @State private var showSplash = !ProcessInfo.processInfo.arguments.contains("-noSplash")

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(engine)
                    .modelContainer(container)
                if showSplash {
                    SplashView { showSplash = false }
                }
            }
            .followsNight()
        }
    }
}

/// Dark after sunset (same clock as the kitty's room), or whenever the phone is in dark mode.
struct FollowsNight: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.everyMinute) { context in
            content.preferredColorScheme(SkyClock.isNight(at: context.date) ? .dark : nil)
        }
    }
}

extension View {
    func followsNight() -> some View { modifier(FollowsNight()) }
}
