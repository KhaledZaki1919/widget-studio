# Capabilities

Generated from `capabilities.json` by `scripts/capabilities-table.mjs`. Do not edit by hand.

## Time and date

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{time.hh}}` | Hour | Yes | Yes |  |  |  |
| `{{time.h}}` | Hour (12h, no zero) | Yes | Yes |  |  |  |
| `{{time.mm}}` | Minutes | Yes | Yes |  |  |  |
| `{{time.ampm}}` | AM/PM | Yes | Yes |  |  |  |
| `{{date.d}}` | Day of month | Yes | Yes |  |  |  |
| `{{date.dd}}` | Day, two digits | Yes | Yes |  |  |  |
| `{{date.EEEE}}` | Weekday | Yes | Yes |  |  |  |
| `{{date.EEE}}` | Weekday, short | Yes | Yes |  |  |  |
| `{{date.MMM}}` | Month, short | Yes | Yes |  |  |  |
| `{{date.MMMM}}` | Month | Yes | Yes |  |  |  |
| `{{date.M}}` | Month number | Yes | Yes |  |  |  |
| `{{date.yyyy}}` | Year | Yes | Yes |  |  |  |
| `{{date.hijri}}` | Hijri date | Yes | Yes |  |  |  |
| `{{tz.offset}}` | Time zone offset | Yes | Yes |  |  |  |
| `{{tz.<timezoneField>.time}}` | Time in a city | Yes | Yes |  |  |  |
| `{{days.<dateField>}}` | Days left | Yes | Yes |  |  |  |
| `{{year.progress}}` | Year progress | Yes | Yes |  |  |  |
| `{{month.progress}}` | Month progress | Yes | Yes |  |  |  |
| `{{week.progress}}` | Week progress | Yes | Yes |  |  |  |
| `{{day.progress}}` | Day progress | Yes | Yes |  |  |  |
| `{{year.day}}` | Day of the year | Yes | Yes |  |  |  |
| `{{year.daysLeft}}` | Days left in the year | Yes | Yes |  |  |  |
| `{{month.daysLeft}}` | Days left in the month | Yes | Yes |  |  |  |
| `{{week.daysLeft}}` | Days left in the week | Yes | Yes |  |  |  |
| `{{time.isDay}}` | Daytime | Yes | Yes |  |  |  |

## Weather

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{weather.temp}}` | Temperature | Yes | Yes |  |  |  |
| `{{weather.hi}}` | Today's high | Yes | Yes |  |  |  |
| `{{weather.lo}}` | Today's low | Yes | Yes |  |  |  |
| `{{weather.feels}}` | Feels like | Yes | Yes |  |  |  |
| `{{weather.humidity}}` | Humidity | Yes | Yes |  |  |  |
| `{{weather.wind}}` | Wind | Yes | Yes |  |  |  |
| `{{weather.sunrise}}` | Sunrise | Yes | Yes |  |  |  |
| `{{weather.sunset}}` | Sunset | Yes | Yes |  |  |  |
| `{{weather.cond}}` | Condition | Yes | Yes |  |  |  |
| `{{weather.symbol}}` | Condition icon | Yes | Yes |  |  |  |
| `{{weather.city}}` | City | Yes | Yes |  |  |  |
| `{{weather.kind}}` | Condition kind | Yes | Yes |  |  |  |
| `{{forecast.1.day}}` | Forecast day 1 | Yes | Yes |  |  |  |
| `{{forecast.1.symbol}}` | Forecast icon 1 | Yes | Yes |  |  |  |
| `{{forecast.1.hi}}` | Forecast high 1 | Yes | Yes |  |  |  |
| `{{forecast.1.lo}}` | Forecast low 1 | Yes | Yes |  |  |  |
| `{{forecast.2.day}}` | Forecast day 2 | Yes | Yes |  |  |  |
| `{{forecast.2.symbol}}` | Forecast icon 2 | Yes | Yes |  |  |  |
| `{{forecast.2.hi}}` | Forecast high 2 | Yes | Yes |  |  |  |
| `{{forecast.2.lo}}` | Forecast low 2 | Yes | Yes |  |  |  |
| `{{forecast.3.day}}` | Forecast day 3 | Yes | Yes |  |  |  |
| `{{forecast.3.symbol}}` | Forecast icon 3 | Yes | Yes |  |  |  |
| `{{forecast.3.hi}}` | Forecast high 3 | Yes | Yes |  |  |  |
| `{{forecast.3.lo}}` | Forecast low 3 | Yes | Yes |  |  |  |
| `{{forecast.4.day}}` | Forecast day 4 | Yes | Yes |  |  |  |
| `{{forecast.4.symbol}}` | Forecast icon 4 | Yes | Yes |  |  |  |
| `{{forecast.4.hi}}` | Forecast high 4 | Yes | Yes |  |  |  |
| `{{forecast.4.lo}}` | Forecast low 4 | Yes | Yes |  |  |  |
| `{{forecast.5.day}}` | Forecast day 5 | Yes | Yes |  |  |  |
| `{{forecast.5.symbol}}` | Forecast icon 5 | Yes | Yes |  |  |  |
| `{{forecast.5.hi}}` | Forecast high 5 | Yes | Yes |  |  |  |
| `{{forecast.5.lo}}` | Forecast low 5 | Yes | Yes |  |  |  |
| `{{forecast.6.day}}` | Forecast day 6 | Yes | Yes |  |  |  |
| `{{forecast.6.symbol}}` | Forecast icon 6 | Yes | Yes |  |  |  |
| `{{forecast.6.hi}}` | Forecast high 6 | Yes | Yes |  |  |  |
| `{{forecast.6.lo}}` | Forecast low 6 | Yes | Yes |  |  |  |

## Battery

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{battery.level}}` | Battery level | Yes | Yes |  |  |  |
| `{{battery.charging}}` | Charging | Yes | Yes |  |  |  |
| `{{battery.symbol}}` | Battery icon | Yes | Yes |  |  |  |
| `{{battery.devices}}` | Earbuds and watch battery | No | No |  |  | iOS: No public API. Android: Needs a privileged permission. |

## Location

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{location.lat}}` | Latitude | Yes | Yes | Location | Location |  |
| `{{location.lon}}` | Longitude | Yes | Yes | Location | Location |  |
| `{{location.alt}}` | Altitude | Yes | Yes | Location | Location |  |
| `{{location.city}}` | Current place | Yes | Yes | Location | Location |  |

## Prayer and Qibla

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{prayer.next.name}}` | Next prayer | Yes | Yes | Location | Location |  |
| `{{prayer.next.time}}` | Next prayer time | Yes | Yes | Location | Location |  |
| `{{prayer.next.key}}` | Next prayer key | Yes | Yes | Location | Location |  |
| `{{prayer.fajr}}` | Fajr | Yes | Yes | Location | Location |  |
| `{{prayer.dhuhr}}` | Dhuhr | Yes | Yes | Location | Location |  |
| `{{prayer.asr}}` | Asr | Yes | Yes | Location | Location |  |
| `{{prayer.maghrib}}` | Maghrib | Yes | Yes | Location | Location |  |
| `{{prayer.isha}}` | Isha | Yes | Yes | Location | Location |  |
| `{{qibla.bearing}}` | Qibla direction | Yes | Yes | Location | Location |  |

## Steps and sleep

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{steps.today}}` | Steps today | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{steps.progress}}` | Step goal progress | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{steps.streak}}` | Step streak | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{steps.month}}` | Steps this month | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{steps.monthGrid}}` | Steps month grid | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{sleep.lastNight}}` | Sleep last night | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{sleep.bedtime}}` | Bedtime | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{sleep.wake}}` | Wake time | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |
| `{{sleep.week}}` | Sleep this week | Yes | Yes | Health (steps and sleep) | Health (steps and sleep) |  |

## Counters and timers

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{counter.value}}` | Counter | Yes | Yes |  |  |  |
| `{{counter.progress}}` | Counter progress | Yes | Yes |  |  |  |
| `{{counter.dhikr}}` | Current dhikr | Yes | Yes |  |  |  |
| `{{stopwatch.running}}` | Stopwatch running | Yes | Yes |  |  |  |
| `{{stopwatch.start}}` | Stopwatch start | Yes | Yes |  |  |  |
| `{{focus.today}}` | Focus today | Yes | Yes |  |  |  |
| `{{focus.week}}` | Focus this week | Yes | Yes |  |  |  |
| `{{timer.running}}` | Timer running | Yes | Yes |  |  |  |
| `{{timer.end}}` | Timer end | Yes | Yes |  |  |  |
| `{{timer.remaining}}` | Timer left | Yes | Yes |  |  |  |
| `{{timer.progress}}` | Timer progress | Yes | Yes |  |  |  |
| `counter.increment` | Counter +1 | Yes | Yes |  |  |  |
| `counter.reset` | Reset counter | Yes | Yes |  |  |  |
| `counter.next` | Next dhikr | Yes | Yes |  |  |  |
| `stopwatch.toggle` | Start/stop stopwatch | Yes | Yes |  |  |  |
| `timer.toggle` | Start/pause timer | Yes | Yes |  |  |  |
| `timer.add` | Add time to timer | Yes | Yes |  |  |  |
| `timer.reset` | Reset timer | Yes | Yes |  |  |  |

## Calendar

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{calendar.next.title}}` | Next event | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.next.time}}` | Next event time | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.next.location}}` | Next event place | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.count}}` | Events today | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.1.title}}` | Event 1 | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.1.time}}` | Event 1 time | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.2.title}}` | Event 2 | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.2.time}}` | Event 2 time | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.3.title}}` | Event 3 | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.3.time}}` | Event 3 time | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.4.title}}` | Event 4 | Yes | Yes | Calendar | Calendar |  |
| `{{calendar.4.time}}` | Event 4 time | Yes | Yes | Calendar | Calendar |  |

## Reminders

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{reminders.count}}` | Open reminders | Yes | No | Reminders | Reminders | Android: Android has no shared reminders store. |
| `{{reminders.1.title}}` | Reminder 1 | Yes | No | Reminders | Reminders |  |
| `{{reminders.2.title}}` | Reminder 2 | Yes | No | Reminders | Reminders |  |
| `{{reminders.3.title}}` | Reminder 3 | Yes | No | Reminders | Reminders |  |
| `{{reminders.4.title}}` | Reminder 4 | Yes | No | Reminders | Reminders |  |

## Tasks

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{tasks.list}}` | Open tasks | Yes | Yes | Reminders |  |  |
| `{{tasks.today.count}}` | Tasks today | Yes | Yes | Reminders |  |  |
| `{{tasks.open.count}}` | Open task count | Yes | Yes | Reminders |  |  |
| `{{tasks.done.count}}` | Tasks done today | Yes | Yes | Reminders |  |  |
| `{{tasks.progress}}` | Task progress | Yes | Yes | Reminders |  |  |
| `{{tasks.next.title}}` | Next task | Yes | Yes | Reminders |  |  |
| `{{tasks.next.due}}` | Next task due | Yes | Yes | Reminders |  |  |
| `{{tasks.next.id}}` | Next task id | Yes | Yes | Reminders |  |  |
| `{{tasks.1.title}}` | Task 1 | Yes | Yes | Reminders |  |  |
| `{{tasks.1.due}}` | Task 1 due | Yes | Yes | Reminders |  |  |
| `{{tasks.1.done}}` | Task 1 done | Yes | Yes | Reminders |  |  |
| `{{tasks.1.id}}` | Task 1 id | Yes | Yes | Reminders |  |  |
| `{{tasks.2.title}}` | Task 2 | Yes | Yes | Reminders |  |  |
| `{{tasks.2.due}}` | Task 2 due | Yes | Yes | Reminders |  |  |
| `{{tasks.2.done}}` | Task 2 done | Yes | Yes | Reminders |  |  |
| `{{tasks.2.id}}` | Task 2 id | Yes | Yes | Reminders |  |  |
| `{{tasks.3.title}}` | Task 3 | Yes | Yes | Reminders |  |  |
| `{{tasks.3.due}}` | Task 3 due | Yes | Yes | Reminders |  |  |
| `{{tasks.3.done}}` | Task 3 done | Yes | Yes | Reminders |  |  |
| `{{tasks.3.id}}` | Task 3 id | Yes | Yes | Reminders |  |  |
| `{{tasks.4.title}}` | Task 4 | Yes | Yes | Reminders |  |  |
| `{{tasks.4.due}}` | Task 4 due | Yes | Yes | Reminders |  |  |
| `{{tasks.4.done}}` | Task 4 done | Yes | Yes | Reminders |  |  |
| `{{tasks.4.id}}` | Task 4 id | Yes | Yes | Reminders |  |  |
| `{{tasks.5.title}}` | Task 5 | Yes | Yes | Reminders |  |  |
| `{{tasks.5.due}}` | Task 5 due | Yes | Yes | Reminders |  |  |
| `{{tasks.5.done}}` | Task 5 done | Yes | Yes | Reminders |  |  |
| `{{tasks.5.id}}` | Task 5 id | Yes | Yes | Reminders |  |  |
| `{{tasks.6.title}}` | Task 6 | Yes | Yes | Reminders |  |  |
| `{{tasks.6.due}}` | Task 6 due | Yes | Yes | Reminders |  |  |
| `{{tasks.6.done}}` | Task 6 done | Yes | Yes | Reminders |  |  |
| `{{tasks.6.id}}` | Task 6 id | Yes | Yes | Reminders |  |  |
| `task.toggle` | Complete task | Yes | Yes | Reminders |  |  |
| `task.add` | Add a task | Yes | Yes |  |  |  |

## Now playing

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{media.title}}` | Song title | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only: iOS has no API for other players' now playing. |
| `{{media.artist}}` | Artist | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.album}}` | Album | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.app}}` | Player app | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Always Music. |
| `{{media.playing}}` | Is playing | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.symbol}}` | Play/pause icon | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.elapsed}}` | Elapsed | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.duration}}` | Track length | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.remaining}}` | Time left | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.progress}}` | Track progress | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `{{media.artwork}}` | Album art | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music only. |
| `media.playPause` | Play/pause | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music in the widget; with arg "shortcut" any player through a Shortcut. |
| `media.next` | Next track | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music in the widget; with arg "shortcut" any player through a Shortcut. |
| `media.previous` | Previous track | Yes | Yes | Apple Music | Notification access (now playing from any player) | iOS: Apple Music in the widget; with arg "shortcut" any player through a Shortcut. |
| `media.open` | Open the player | Yes | Yes |  |  |  |

## Volume and brightness

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{volume.level}}` | Media volume | Yes | Yes |  |  |  |
| `{{volume.ring}}` | Ringer volume | No | Yes |  |  | iOS: iOS has no API for the ringer volume. |
| `{{volume.muted}}` | Muted | Yes | Yes |  |  |  |
| `{{volume.symbol}}` | Volume icon | Yes | Yes |  |  |  |
| `{{brightness.level}}` | Brightness | No | Yes |  |  | iOS: A widget can't read the brightness. |
| `volume.up` | Volume up | Shortcut | Yes | A Shortcut you create once |  |  |
| `volume.down` | Volume down | Shortcut | Yes | A Shortcut you create once |  |  |
| `volume.mute` | Mute | Shortcut | Yes | A Shortcut you create once |  |  |
| `volume.ringUp` | Ringer up | No | Yes |  |  |  |
| `volume.ringDown` | Ringer down | No | Yes |  |  |  |
| `brightness.up` | Brightness up | Shortcut | Yes | A Shortcut you create once | Modify system settings |  |
| `brightness.down` | Brightness down | Shortcut | Yes | A Shortcut you create once | Modify system settings |  |

## System switches

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{compass.north}}` | North arrow angle | No | Yes |  |  | iOS: A widget can't read the compass; a tap opens the live compass. Android: Read when the widget redraws (once a minute); a tap opens the live compass. |
| `{{compass.heading}}` | Compass heading | No | Yes |  |  | iOS: A widget can't read the compass; a tap opens the live compass. Android: Read when the widget redraws (once a minute); a tap opens the live compass. |
| `{{system.wifi}}` | Wi-Fi is on | Yes | Yes |  |  | iOS: 1 only while connected to Wi-Fi. |
| `{{system.bluetooth}}` | Bluetooth is on | No | Yes |  |  | iOS: A widget can't read it; the switch keeps its off look. |
| `{{system.airplane}}` | Airplane mode is on | No | Yes |  |  | iOS: A widget can't read it; the switch keeps its off look. |
| `{{system.mobileData}}` | Mobile data is on | Yes | Yes |  |  | iOS: 1 only while using cellular. |
| `{{system.darkMode}}` | Dark mode is on | Yes | Yes |  |  |  |
| `{{system.lowPower}}` | Low power mode is on | Yes | Yes |  |  |  |
| `{{system.silent}}` | Silent is on | No | Yes |  |  | iOS: A widget can't read it; the switch keeps its off look. |
| `{{system.rotationLock}}` | Rotation is locked | No | Yes |  |  | iOS: A widget can't read it; the switch keeps its off look. |
| `{{system.dnd}}` | Do Not Disturb is on | No | Yes |  |  | iOS: A widget can't read it; the switch keeps its off look. |
| `{{system.torch}}` | Torch is on | No | Yes |  |  | iOS: A widget can't read it; the switch keeps its off look. |
| `system.toggle.torch` | Torch | Shortcut | Yes | A Shortcut you create once |  |  |
| `system.toggle.wifi` | Wi-Fi | Shortcut | System panel | A Shortcut you create once |  |  |
| `system.toggle.bluetooth` | Bluetooth | Shortcut | System panel | A Shortcut you create once |  |  |
| `system.toggle.airplane` | Airplane mode | Shortcut | System panel | A Shortcut you create once |  |  |
| `system.toggle.mobileData` | Mobile data | Shortcut | System panel | A Shortcut you create once |  |  |
| `system.toggle.darkMode` | Dark mode | Shortcut | System panel | A Shortcut you create once |  |  |
| `system.toggle.lowPower` | Low power mode | Shortcut | System panel | A Shortcut you create once |  |  |
| `system.toggle.silent` | Silent | Shortcut | Yes | A Shortcut you create once | Do Not Disturb access |  |
| `system.toggle.rotation` | Auto-rotate | Shortcut | Yes | A Shortcut you create once | Modify system settings |  |
| `system.toggle.dnd` | Do Not Disturb | Shortcut | Yes | A Shortcut you create once | Do Not Disturb access |  |

## Your own values

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `{{field.<key>}}` | Your text | Yes | Yes |  |  |  |

## Open

| Id | What | iOS | Android | iOS needs | Android needs | Notes |
|---|---|---|---|---|---|---|
| `open.app` | Open Widget Studio | Yes | Yes |  |  |  |
| `open.url` | Open a link | Yes | Yes |  |  |  |
| `open.deeplink` | Open an app link | Yes | Yes |  |  |  |
| `app.launch` | Open an installed app | No | Yes |  |  | iOS: Use Open an app link instead. |
| `call.dial` | Call a number | Yes | Yes |  |  |  |
| `message.open` | Message a number | Yes | Yes |  |  |  |
| `shortcut.run` | Run a Shortcut | Shortcut | System panel | A Shortcut you create once |  | Android: Common names (Wi-Fi, Torch…) map to Android; others show a hint. |
| `camera.open` | Open the camera | Shortcut | Yes | A Shortcut you create once |  |  |
| `qr.scan` | Scan a QR code | Shortcut | Yes | A Shortcut you create once |  |  |
| `calendar.open` | Open the calendar | Yes | Yes |  |  |  |
| `reminders.open` | Open Reminders | Yes | No |  |  |  |
| `compass.open` | Open the live compass | Yes | Yes |  |  |  |
| `weather.open` | Open the weather | Yes | System panel |  |  | Android: Opens the web forecast for your place. |
