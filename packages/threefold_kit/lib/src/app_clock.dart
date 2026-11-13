import 'dart:async';

import 'package:clock/clock.dart';

import 'calendar_date.dart';

/// The app's one clock (SOP R9.3). Everything that needs "now" calls
/// [AppClock.now] (or takes a `DateTime Function() now` defaulting to it),
/// never `DateTime.now()`.
///
/// It reads `package:clock`, so a test pins time with
/// `withClock(Clock.fixed(...), () { ... })`, and it adds the dev time
/// travel offset from [DevClock] (SOP R5.7), which is zero unless the app
/// switched dev tools on.
abstract final class AppClock {
  /// Now on the device, plus any dev time travel offset.
  static DateTime now() => clock.now().add(DevClock.offset);

  /// [now] as UTC, ready to store as an instant (`toIso8601String()` ends
  /// in `Z`).
  static DateTime nowUtc() => now().toUtc();

  /// Today on the device's own calendar. For a place's today (a school, a
  /// venue) use `PlaceTime.today`.
  static CalendarDate today() => CalendarDate.fromDateTime(now());
}

/// DEV-ONLY: time travel for testing hearts, daily rewards, streaks, trials
/// and reminders without touching the phone's clock (SOP R5.7).
///
/// Off until the app calls [enableForDev], which it does only when its own
/// `Env.devTools` flag is true:
///
/// ```dart
/// if (Env.devTools) DevClock.enableForDev(); // DEV-ONLY: time travel
/// ```
///
/// While disabled, [offset] is always zero and [advanceForDev] does nothing,
/// so a store build cannot drift even if a dev button slipped through.
abstract final class DevClock {
  static bool _enabled = false;
  static Duration _offset = Duration.zero;
  static final StreamController<Duration> _changes =
      StreamController<Duration>.broadcast();

  /// DEV-ONLY: switch time travel on. Call once at startup behind the app's
  /// dev tools flag.
  static void enableForDev() => _enabled = true;

  /// True once [enableForDev] has been called.
  static bool get enabled => _enabled;

  /// The offset [AppClock.now] adds; zero while disabled.
  static Duration get offset => _enabled ? _offset : Duration.zero;

  /// Emits the new offset after every change, so a Developer screen or a
  /// timer can rebuild.
  static Stream<Duration> get changes => _changes.stream;

  /// DEV-ONLY: move the app clock by [by] (forward 1 hour, 1 day, ...).
  /// Ignored while disabled.
  static void advanceForDev(Duration by) {
    if (!_enabled) return;
    _offset += by;
    _changes.add(_offset);
  }

  /// DEV-ONLY: back to real time. Always allowed.
  static void resetForDev() {
    _offset = Duration.zero;
    _changes.add(_offset);
  }

  /// Turns time travel off and clears the offset. For tests only.
  static void disableForTesting() {
    _enabled = false;
    _offset = Duration.zero;
  }

  /// "+1 day 2 hr", "-3 hr", or "Real time": the current offset in words,
  /// for the Time travel (Dev) tile.
  static String describe() => describeOffset(offset);
}

/// An offset in words: `Real time`, `+1 day`, `+2 days 3 hr`, `-45 min`.
String describeOffset(Duration d) {
  if (d == Duration.zero) return 'Real time';
  final sign = d.isNegative ? '-' : '+';
  final a = d.abs();
  final days = a.inDays;
  final hours = a.inHours % 24;
  final minutes = a.inMinutes % 60;
  final parts = <String>[
    if (days > 0) '$days ${days == 1 ? 'day' : 'days'}',
    if (hours > 0) '$hours hr',
    if (minutes > 0) '$minutes min',
  ];
  if (parts.isEmpty) return '${sign}0 min';
  return '$sign${parts.join(' ')}';
}
