import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_clock.dart';
import 'calendar_date.dart';

/// Converts between a place's wall clock and UTC instants (SOP R9.5, R9.6).
///
/// A place's event (a school, a venue, a business) shows in the place's
/// zone on every phone, wherever the reader is. A picker returns plain wall
/// clock fields; [fromWall] turns them into the real instant on save and
/// [toWall] turns an instant back into fields to prefill, so a load and save
/// with no edits never moves a value.
///
/// Borrowed from nsepto `SchoolTime` and `DateX`: the fallback zone instead
/// of a crash, plain DateTime wall clocks rather than `TZDateTime` (which
/// compares as an instant), and day keys for "is it over?".
class PlaceTime {
  /// [zoneName] is an IANA name such as `America/New_York`. An unknown or
  /// blank name falls back to [fallback] rather than throwing, because a
  /// screen that will not open is worse than one an hour off.
  PlaceTime(String zoneName, {String fallback = defaultZone})
      : _loc = _resolve(zoneName, fallback),
        requestedZone = zoneName;

  /// The seed zone before a tenant row loads. Never the device zone (R9.5).
  static const String defaultZone = 'America/New_York';

  final tz.Location _loc;

  /// The name the app asked for, which may differ from [zoneName] when it
  /// fell back.
  final String requestedZone;

  static bool _ready = false;

  /// Loads the time zone database. Called for you; safe to call again.
  static void initialize() {
    if (_ready) return;
    tz_data.initializeTimeZones();
    _ready = true;
  }

  static tz.Location _resolve(String name, String fallback) {
    initialize();
    try {
      return tz.getLocation(name.trim());
    } catch (_) {
      return tz.getLocation(fallback);
    }
  }

  /// The zone actually in use.
  String get zoneName => _loc.name;

  /// True when [requestedZone] was not usable and the fallback is in use.
  bool get usedFallback => requestedZone.trim() != _loc.name;

  /// An instant as plain wall clock fields at the place, for display, pickers
  /// and guards. The fields ride in a `DateTime.utc` only because UTC has no
  /// daylight saving gap, so the device's own zone can never shift them (a
  /// phone in New York cannot hold a local 2:30 AM on March 8). Read the
  /// fields; never treat the result as an instant or call `toLocal` on it.
  DateTime toWall(DateTime instant) {
    final z = tz.TZDateTime.from(instant.toUtc(), _loc);
    return DateTime.utc(z.year, z.month, z.day, z.hour, z.minute, z.second);
  }

  /// Wall clock fields typed at the place, as the real UTC instant. Reads
  /// only year to second and ignores the zone [wall] claims. A time skipped
  /// by spring forward (2:30 AM on March 8, 2026) moves to the first real
  /// moment after the gap, as the timezone package does.
  DateTime fromWall(DateTime wall) => tz.TZDateTime(
        _loc,
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
        wall.second,
      ).toUtc();

  /// A calendar date plus minutes past midnight at the place (free text
  /// times from a form, R9.1), as the real UTC instant.
  DateTime fromDateAndMinutes(CalendarDate date, int minutesPastMidnight) =>
      fromWall(DateTime.utc(
          date.year, date.month, date.day, 0, minutesPastMidnight));

  /// The place's calendar day for an instant.
  CalendarDate dayOf(DateTime instant) =>
      CalendarDate.fromDateTime(toWall(instant));

  /// The place's day key (`yyyy-MM-dd`) for an instant; the twin of
  /// nseptoweb's `dayKey(instant, zone)` and of
  /// `(instant at time zone zone)::date` in SQL.
  String dayKey(DateTime instant) => dayOf(instant).key;

  /// Now as the place's wall clock.
  DateTime now({DateTime Function() clockNow = AppClock.now}) =>
      toWall(clockNow());

  /// The place's today.
  CalendarDate today({DateTime Function() clockNow = AppClock.now}) =>
      dayOf(clockNow());

  /// True once [day] is behind the place's today. Days, never instants: a
  /// 7:30 PM event is still current at 8 PM.
  bool hasPassed(CalendarDate day,
          {DateTime Function() clockNow = AppClock.now}) =>
      day.isBefore(today(clockNow: clockNow));

  /// Midnight at the start of [day] at the place, as a UTC instant: the
  /// cutoff for "what is coming up" (never `now`, or today's all-day closure
  /// vanishes at 12:01 AM).
  DateTime startOfDayUtc(CalendarDate day) =>
      fromWall(DateTime.utc(day.year, day.month, day.day));

  /// The short zone label at [instant] ("EST", "EDT").
  String abbreviation(DateTime instant) =>
      tz.TZDateTime.from(instant.toUtc(), _loc).timeZoneName;

  /// The short zone label, but only when the place's offset differs from
  /// [deviceOffset] (the phone's, by default), so a reader at home sees
  /// nothing extra and a traveller sees which clock a time is on.
  String? abbreviationIfDiffering(DateTime instant, {Duration? deviceOffset}) {
    final z = tz.TZDateTime.from(instant.toUtc(), _loc);
    final device = deviceOffset ?? instant.toLocal().timeZoneOffset;
    return z.timeZoneOffset == device ? null : z.timeZoneName;
  }
}
