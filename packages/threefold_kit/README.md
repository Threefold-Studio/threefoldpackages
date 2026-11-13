# threefold_kit

Pure Dart helpers every Threefold Studio app and game shares: one app clock with dev time travel, calendar dates and day keys, place time zones, money in integer cents, US phone numbers, and copy style checks. It implements SOP Sections 5 (R5.7 time travel), 9 (Dates, Times and Time Zones) and 10 (Money, Numbers and Copy Style).

No Flutter import, so it tests with `dart test` and works in Flutter apps, games and command line tools alike. Dependencies: `clock`, `timezone`, `matcher`. Dart SDK 3.3 or later.

## Add it

```yaml
dependencies:
  threefold_kit:
    git:
      url: https://github.com/Threefold-Studio/threefoldpackages.git
      path: packages/threefold_kit
      ref: v0.1.0
```

Always pin a tag, never a branch. Then `flutter pub get` (or `dart pub get`).

```dart
import 'package:threefold_kit/threefold_kit.dart';
```

## The clock (R9.3, R5.7)

Call `AppClock.now()` everywhere instead of `DateTime.now()`. Tests pin it with `package:clock`:

```dart
withClock(Clock.fixed(DateTime(2026, 11, 1, 1, 30)), () {
  expect(AppClock.today(), const CalendarDate(2026, 11, 1));
});
```

Controllers can take `DateTime Function() now = AppClock.now` as a parameter.

Dev time travel adds an offset to the app clock, never the phone clock. It does nothing until the app turns it on behind its own flag:

```dart
// main.dart
if (Env.devTools) DevClock.enableForDev(); // DEV-ONLY: time travel

// Developer screen
DevClock.advanceForDev(const Duration(days: 1)); // DEV-ONLY
DevClock.resetForDev();
Text(DevClock.describe()); // "+1 day"
```

`DevClock.changes` is a stream that fires after every change, so timers can rebuild.

## Calendar dates (R9.1, R9.4)

A due date, an event day or a birthday is a `CalendarDate`, never a midnight instant. All arithmetic uses `DateTime.utc` fields, so daylight saving time cannot shift a count.

```dart
final due = CalendarDate.tryParse(row['due_on'] as String?); // null on junk
const a = CalendarDate(2026, 3, 7);
a.daysUntil(const CalendarDate(2026, 3, 9)); // 2, across spring forward
const CalendarDate(2026, 1, 31).addMonths(1); // 2026-02-28
a.key; // "2026-03-07", the only shape a Postgres date takes
jsonEncode({'due': a}); // {"due":"2026-03-07"}
```

`DateOnly` is the same type under the SOP 9.5 name.

## A place's time zone (R9.5, R9.6)

Times that belong to a school, venue or business show in the place's zone on every phone.

```dart
final school = PlaceTime(row['timezone'] as String); // bad names fall back to America/New_York
final wall = school.toWall(event.startsAt);       // prefill a picker
final saved = school.fromWall(pickedWallClock);   // save: the real UTC instant
school.dayKey(event.endsAt);                      // "2026-11-12" at the school
school.hasPassed(CalendarDate(2026, 11, 12));     // compared as days, not instants
school.abbreviationIfDiffering(event.startsAt);   // "EST" only for a traveller
```

## Display formats (R9.9)

Formatters never read the clock; pass `today`.

```dart
formatLongDate(day);                     // November 12, 2026
formatShortDate(day, today: today);      // Nov 12 (or Nov 12, 2027)
formatWeekdayDate(day);                  // Thursday, November 12
formatRelativeDay(day, today: today);    // Today, Tomorrow, Yesterday, Nov 20
formatTime(wall);                        // 6:30 PM
formatTimeRange(startWall, endWall);     // 6:30 to 7:30 PM (start alone when equal)
formatDateRange(a, b, today: today);     // Nov 12 to Nov 14
formatDaysToGo(day, today: today);       // 16 days to go
parseClockMinutes('2:00 PM');            // 840, null for anything unclear
```

## Money (R10.1 to R10.5)

Integer cents only.

```dart
formatCents(1240);                          // $12.40 (cents shown when not whole)
formatCents(1200);                          // $12
formatCents(1200, mode: CentsMode.always);  // $12.00 for invoices and PDFs
parseCents(r'$1,249.99');                   // 124999
parseCents('1-2');                          // null
parseCents('-5', allowNegative: true);      // -500
grossUpCents(81250, feeBps: 300);           // 83763, pin it to your SQL in a test
```

`parseCents` reads digit by digit and accepts only: an optional leading `-` (when allowed), an optional `$`, digits with correct thousands commas, and an optional dot with up to two digits. Anything else is null.

## Numbers (R10.7)

```dart
formatCount(4398);              // 4,398
plural(2, 'ticket');            // 2 tickets
plural(3, 'child', 'children'); // 3 children
formatPercent(0.034);           // 3.4%
formatBps(290);                 // 2.9%
```

## Phones (R10.8, R10.9)

The same rules as `public.format_phone` and `public.to_e164` in the NSE PTO database.

```dart
formatPhone('+1 302 555 0134');   // (302) 555-0134
formatPhone('+44 20 7946 0958');  // kept exactly as typed
toE164('(302) 555-0134');         // +13025550134
toE164('555-0134');               // null: build no link
telUri('(302) 555-0134');         // tel:+13025550134
phoneProblem('me@example.com');   // Enter a phone number, like (302) 555-0134.
formatPhoneTyping('3025', previous: '302'); // (302) 5
```

## Copy checks (R10.10 to R10.12)

```dart
findDashes('Doors open \u2014 6 PM');                // one emDash issue
isCleanCopy('Fast - free', rules: CopyRules.website); // false on a website
titleCase('send my inquiry');                       // Send My Inquiry
```

In tests:

```dart
import 'package:threefold_kit/copy_matchers.dart';

expect(welcomeSmsBody('Ana'), hasNoDashes);
expect(heroLine, hasNoDashes(rules: CopyRules.website));
```

From the command line or `scripts/verify.sh`, scan the string literals of Dart files (comments are allowed any dash; a line marked `copy-check: ignore` is skipped; directories skip `*_test.dart` and generated files):

```sh
dart run threefold_kit:check_copy lib
dart run threefold_kit:check_copy --website lib/copy
```

It exits 1 when it finds a dash, 0 when clean.

## Golden cases

`test/golden/format_cases.json`, `time_cases.json` and `copy_cases.json` hold every input and expected output the Dart tests check (R9.13, R10.19). A TypeScript twin (`@threefold/time`, `@threefold/format`) should read the same files in its own tests, so the two ports cannot drift apart.

## Development

```sh
dart pub get
dart format .
dart analyze --fatal-infos
dart test
```
