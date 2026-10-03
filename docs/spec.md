# Pomodoro App Spec (v1)

A tiny, cozy focus timer for Sarah, built as a surprise gift. Native iOS (SwiftUI). No accounts, no internet, no clutter.

## The problem
Sarah works across lots of different tasks. She wants a simple rhythm (focus, break, focus) and a gentle way to see how much focused time she's put in. Existing apps are either bland or overloaded.

## Who / device
- Sarah, iPhone 17 (has Dynamic Island), latest iOS
- Free Apple developer account for now: installed by cable, reinstalled every 7 days

## Principles
1. **Open → tap → focusing.** It should never need setup to use.
2. **Task-agnostic.** No categories, labels, or to-dos.
3. **She's in control.** Nothing starts without a tap.
4. **Lightweight.** No third-party libraries, no backend.
5. **Delight in small doses.** Smooth animations and haptics, never in the way.

## Must-haves
1. **Timer with editable presets.** Three focus chips (short / medium / long, default 15 / 25 / 45) plus a sliders chip that opens "Your focus times". There she taps a preset and spins a wheel to change it. Each has its own range so they always stay in order: **short 1–20 min** (by 1), **medium 20–45 min** (by 5), **long 45 min–3 hr** (by 5). She also sets break lengths (short 1 to 30 min, long 5 to 60 min) and how many sessions come before a long break (2 to 5). The long break's length and "After every N focus sessions" share one card. Numbers can be tapped with − / +, held to repeat, or dragged up and down to scrub.
   - **Wind the clock:** 12 subtle dots make the ring look like a kitchen timer. When nothing's running, she drags clockwise from the top: halfway is 30 min, a full turn is 60. A paw knob and arc follow her finger, with a haptic tick each minute and a soft click every 5. The kitty's eyes and head follow the knob, then glide back to center on release. It's a one-off time and doesn't change the presets. Defaults: 25 min focus, 5 min short break, and a 15 min long break after every 4 sessions.
2. **Focus messages.** Under the timer during focus: "Focusing…" for the first 20 seconds, then a new line every 20 seconds from a list of 30 cozy ones ("Paws on the keyboard", "Whiskers forward", "Pawsitively focused"...). Each session shuffles the order, so nothing repeats until all 30 have shown. In the last minute: "Almost there…". **Breaks** work the same way: "Stretch break" (or "Long break. You earned it") first, then 20 rotating rest nudges ("Sip some water", "Slow blink, like a cat", "Doing nothing is allowed"...), and "Back to it soon…" in the last minute.
3. **Session flow.** When time's up, she gets a notification and a happy kitty animation. The next phase (break or focus) starts only when she taps it.
3. **Pause / resume / stop** at any time.
4. **Lock screen + Dynamic Island.** A live countdown (Live Activity) while a session runs.
5. **Home screen widget.** Shows the kitty, the current state, and today's tally. Tapping it opens the app.
6. **Tracking.**
   - **Today:** a row of paw slots, one per session until the long break (🐾🐾◦◦ "long break in 2"). New paws "stamp" in. Below: "3 sessions · 1h 15m focused", or "No sessions yet". The cycle restarts each day.
   - **Focus notebook** (the notebook button, top right). She can rename it by tapping the title ("Sarah's notebook"), up to 24 characters; clearing it brings back "Focus notebook". Title and Done share one line, same as Settings.
     - This week vs. last week, and a 7-day chart of deep vs. other focus
     - **Last 16 weeks** heatmap: each day is a square, and the darker the caramel, the more focus. Tap a day for its numbers.
     - **All time:** total focus, deep focus, sessions, and best streak, "since" her first day
     - **Month by month:** every month back to her first session, each with a bar; tap one to open its calendar
   - **Two numbers per day:**
     - *Focus time:* all minutes spent in focus mode
     - *Deep focus:* minutes from sessions finished start to end with no pauses (the pure heads-down time)
   - **This week vs. last week:** one line, like "4h 10m, up 35m from last week"
7. **Sounds.** Short, soft, satisfying sounds in an iPhone-like style: little chimes, pops, and ticks. Original sounds made for this app.
   - Start: a soft pop
   - Session done: a gentle two-note chime (also the notification sound)
   - Break over: a softer, lower chime
   - Preset tap: a tiny tick, paired with a haptic
   - Follows the silent switch, so it's quiet when her phone is on silent (haptics still work)
8. **Settings page** (gear, top right): App sounds on/off, Vibration on/off (in-app haptics), and **When time's up**: Marimba (warm little knocks, ~4s), Music box (a tiny tinkly tune, ~4s), Singing bowl (one long, calm hum, ~7s), or Silent. Each has a lower version for when a break ends. Tapping one previews it. At the bottom: "made by C, for S ♡" and the app version. When the phone is locked, the sound plays at the ringer volume and is silent on silent mode; notification vibration follows her iPhone settings (apps can't control either).
9. **Reliable in the background.** The timer is based on an end time, so it stays accurate when the phone is locked or the app is closed.
10. **Data stays on her phone** (SwiftData). It survives the weekly reinstall as long as the app isn't deleted.

## Petting the kitty
When she isn't in focus mode, tapping the kitty gets a reaction: ears flick, head pats bring happy eyes and a heart, a nose boop gets >_<, a tail tap gets a swish, a paw tap gets a wave. The belly gets a happy wiggle, and **1 in 10 times a rare purr** (sound + rumble). She can't be spam-petted: each reaction plays out, plus a short pause, before she responds again. Only the kitty moves; the desk stays put.

## Character: the kitty
An original little **brown kitty**, inspired by the feel of Jiji from *Kiki's Delivery Service* (simple, round, expressive) but our own design.
- **Idle:** sitting, tail swishing, occasional blink
- **Focus:** loafed up, eyes on a tiny book or laptop, calm breathing
- **Break:** stretches, rolls over, plays with yarn
- **Session done:** happy wiggle, small hearts or sparkles
- **Tally:** each finished focus session is a little paw print

## Her little room (main screen)
The timer ring frames a scene of the kitty at her desk. **The room follows the real clock** (like the window), not the phone's dark mode. The whole app goes dark after sunset (same clock), or any time the phone is in dark mode, with no in-app toggle. Night colors are low-glare: deep navy, soft off-white text, muted caramel buttons.
- **Day:** white coat over blue scrubs, stethoscope, "Sarah" embroidered in cursive, a highlighter and pen in the pocket, iced coffee (left), a succulent (right), a sunny window
- **Night:** a dimmer, mellower room; soft pajamas and round glasses; a warm desk lamp (left) glowing over her; a steaming mug of tea (right); moon and stars outside
- **Always:** a HOPKINS pennant on the wall (the word only, not the official logo)
- **The window shows the real time of day**, whatever mode the app is in: stars and moon at night, purple-to-peach at dawn and dusk, blue sky with the sun moving across during the day. Estimated from the clock and date only, with no location needed.
- Widgets and the Dynamic Island show just the kitty in her outfit (too small for the full scene)

## Opening the app
- The system launch screen matches the background (cream or navy), so there's no white flash.
- On a fresh start only: about a second of paw prints sketching themselves in and walking across the screen, then a fade into the app. Tap to skip. Switching back to the app skips it.

## Voice
Plain and short, with the occasional wink ("Snacks later", "Go touch grass"). No motivational-poster lines, no over-explaining, no "at a glance".

## Look & feel
- Warm, soft palette (cream, caramel brown, one accent color)
- Rounded type, chunky buttons, big timer ring
- Springy animations and light haptics when she starts, finishes, or taps a preset
- Supports dark mode

## Not in v1
Task lists, categories, accounts or sync, music or ambient sounds, Apple Watch, App Store release.

## Future ideas (tabled on purpose)
- **Collectibles:** treats, rare kitties, a diary of finds, unlocked by total focus time. Her full history is saved, so these can be awarded retroactively later.
- **Real weather in the window:** needs either her approximate location sent to a free weather service (Open-Meteo), or Apple's weather service with the $99 developer account.
- **Editable name** on the coat, if the app is ever shared beyond Sarah.

## Open questions
- App name?
- Should the kitty have a name?
- Is the widget blocked on a free account? (test during the build)
