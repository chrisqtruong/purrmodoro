/// The widget extension only draws the buttons; iOS runs their actions inside the app.
enum TimerCommandHandler {
    static func run(_ command: TimerCommand) async {}
}
