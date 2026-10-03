# Purrmodoro: "Ring even on silent" (AlarmKit) plan

## Goal
When a session or break ends, it can ring like the Clock app's timer: through silent mode and Focus, with the lock screen switching to "done" right away and a Stop button. It's off unless she turns it on.

## How AlarmKit works (from Apple's docs and WWDC25)
- Requires **iOS 26+**. Both iPhone 17s qualify. Older iOS keeps today's notification behavior.
- She approves it **once per app** (a system prompt, like notifications). The app has to explain why in its settings file.
- **Breaks through silent mode and Focus**, and shows on the lock screen, Dynamic Island, StandBy, and Apple Watch.
- A countdown timer **must** use its own Live Activity. That replaces our current lock screen countdown when the setting is on. We can still draw our kitty design inside it.
- Pause, resume, and stop are built in. The ringing screen is drawn by iOS: a title ("Focus done 🐾"), a Stop button, and an optional second button.
- Sound: a custom file from the app. Our marimba, music box, and bowl sounds work.

## What she'd see
1. **Settings → When time's up**, a new toggle: **"Ring even on silent"** (off by default). Turning it on asks for permission once.
2. During a session: the same lock screen countdown with the kitty and ⏸ / ✕, now run by iOS's alarm system.
3. At zero: **it rings immediately**, even on silent, and the lock screen shows "Focus done 🐾" with **Stop** and **Start break**.
4. Breaks end the same way ("Break's over" with Stop and **Start focus**).
5. With the toggle off, everything works exactly as it does today.

## Build steps
1. **Setting + permission:** the toggle, the permission prompt, and a friendly message if she declines.
2. **Alarm scheduling in the timer:** start, pause, resume, and stop drive AlarmKit instead of (not alongside) the regular notification, so it never rings twice.
3. **New lock screen countdown:** rebuild our kitty lock screen view on AlarmKit's Live Activity, including the paused pose and the ⏸ / ▶ / ✕ buttons.
4. **Ringing screen:** title, Stop, and a second button that starts the break or next focus (reusing the lock screen button code).
5. **Keep the app in sync:** if she pauses or stops from the lock screen or Apple Watch, the app reflects it the next time it opens, and completed time still counts.
6. **Test on a real phone:** silent on, Focus on, locked, pause/resume from the lock screen, and a session that ends while the app is closed.

## Effort
About **one focused session** of building, plus real-device testing on Chris's phone. The Live Activity rebuild is the biggest piece.

## Risks and unknowns (verify first)
- **Free developer account:** AlarmKit seems to need only a permission description, not a paid feature. If the free account blocks it, this waits for the $99 program.
- **Volume:** alarms likely ring at the ringer volume like Clock alarms. Our sounds are already soft, but test at full ringer volume.
- **It overrides Focus.** Good for a timer, but she should know it will ring during a Focus she set for work or sleep. That's why it's an opt-in toggle, with a clear subtitle.
- **Two lock screen designs** (AlarmKit on / off) mean more to maintain. If she loves it, we could make AlarmKit the only path later.

## Open questions for Chris
- On the ringing screen, should the second button be **"Start break"** (one tap into the break), or just **Stop**?
- Should the toggle cover **both** focus and break endings, or just focus?
- Subtitle wording for the toggle, e.g. "Rings through silent mode and Focus"?
