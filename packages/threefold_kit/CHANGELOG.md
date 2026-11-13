# Changelog

## 0.1.0

First release (SOP Appendix C, Sections 5, 9 and 10).

- `AppClock` (one injectable clock on `package:clock`) and `DevClock` (dev time travel offset, off until enabled).
- `CalendarDate` (alias `DateOnly`): calendar dates with DST-safe day counts, `addDays`, `addMonths` with month-end clamping, day keys and strict `yyyy-MM-dd` parsing.
- `PlaceTime`: a place's IANA zone, wall clock to UTC and back, day keys, today, `hasPassed`, zone labels, with a fallback zone instead of a crash.
- US display formats: long, short, weekday and relative dates, times, time and date ranges with "to", countdowns, free text clock times.
- Money in integer cents: `formatCents` (cents shown whenever not whole), strict `parseCents`, `grossUpCents`, `bpsOf`.
- Numbers: `formatCount`, `plural`, `formatPercent`, `formatBps`.
- Phones: `formatPhone`, `toE164`, `telUri`, `phoneProblem`, `formatPhoneTyping`, matching the nsepto SQL rules.
- Copy checks: `findDashes`, `isCleanCopy`, `titleCase`, a Dart string literal scanner, the `hasNoDashes` test matcher and the `check_copy` command.
- Shared golden case files in `test/golden/` for a TypeScript twin.
