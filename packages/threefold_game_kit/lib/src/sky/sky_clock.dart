/// Time of day for painted scenes, from the real sunrise and sunset where
/// the player is. Pure math, no location permission: the place comes from
/// the phone's time zone name. Taken from the games' shared sky clock (the
/// same file), made into an instance with the time passed in.
library;

import 'dart:math' as math;

import 'tz_places.dart';

/// Which scene to show. Games with three pictures map [sunrise] and
/// [sunset] to their dusk picture (see [isTwilight]).
enum SkyPhase {
  sunrise,
  day,
  sunset,
  night;

  bool get isTwilight => this == sunrise || this == sunset;
}

/// Sunrise and sunset for one calendar day, as UTC instants.
class SunTimes {
  const SunTimes(this.rise, this.set)
      : alwaysUp = false,
        alwaysDown = false;
  const SunTimes.polarDay()
      : rise = null,
        set = null,
        alwaysUp = true,
        alwaysDown = false;
  const SunTimes.polarNight()
      : rise = null,
        set = null,
        alwaysUp = false,
        alwaysDown = true;

  final DateTime? rise;
  final DateTime? set;

  /// The sun does not set that day (midnight sun).
  final bool alwaysUp;

  /// The sun does not rise that day (polar night).
  final bool alwaysDown;
}

class SkyClock {
  /// [timeZone] is the phone's zone name, for example 'America/New_York'
  /// (from `flutter_timezone` at startup). [place] overrides the lookup.
  const SkyClock({
    this.timeZone,
    this.place,
    this.window = const Duration(minutes: 45),
    this.places = kTimeZonePlaces,
  });

  final String? timeZone;
  final (double, double)? place;

  /// The sunrise and sunset scenes last this long either side of the
  /// actual sunrise and sunset.
  final Duration window;
  final Map<String, (double, double)> places;

  /// The latitude and longitude in use, or null for the fixed schedule.
  (double, double)? get location =>
      place ?? (timeZone == null ? null : places[timeZone]);

  /// The phase at the instant [time]. Works the same for a local or a UTC
  /// DateTime: the sun times of the UTC day before, of and after [time] are
  /// all checked, so a place far from UTC is never read on the wrong day.
  /// Only the fixed fallback (no known place) reads [time]'s hour, so pass a
  /// local DateTime (for example `GameClock.now()`).
  SkyPhase phaseAt(DateTime time) {
    final loc = location;
    if (loc == null) return fixedPhase(time.hour);
    final t = time.toUtc();
    final days = [
      for (final d in [-1, 0, 1])
        sunTimes(t.year, t.month, t.day + d, loc.$1, loc.$2),
    ];
    final today = days[1];
    if (today.alwaysUp) return SkyPhase.day;
    if (today.alwaysDown) return SkyPhase.night;
    bool near(DateTime? x) =>
        x != null && t.isAfter(x.subtract(window)) && t.isBefore(x.add(window));
    if (days.any((s) => near(s.rise))) return SkyPhase.sunrise;
    if (days.any((s) => near(s.set))) return SkyPhase.sunset;
    final up = days.any((s) =>
        s.alwaysUp ||
        (s.rise != null && t.isAfter(s.rise!) && t.isBefore(s.set!)));
    return up ? SkyPhase.day : SkyPhase.night;
  }

  /// The fallback with no known place: 5 to 7 sunrise, 7 to 17 day, 17 to
  /// 20 sunset, 20 to 5 night.
  static SkyPhase fixedPhase(int hour) {
    if (hour >= 5 && hour < 7) return SkyPhase.sunrise;
    if (hour >= 7 && hour < 17) return SkyPhase.day;
    if (hour >= 17 && hour < 20) return SkyPhase.sunset;
    return SkyPhase.night;
  }

  /// Sunrise and sunset on a calendar day at [lat], [lon] (NOAA
  /// approximation, within a few minutes), as UTC instants.
  static SunTimes sunTimes(
      int year, int month, int day, double lat, double lon) {
    // Day of year from UTC dates, so daylight saving cannot shift it. The
    // date is normalised first, so day 0 or day 32 roll over correctly.
    final date = DateTime.utc(year, month, day);
    final n = date.difference(DateTime.utc(date.year)).inHours ~/ 24 + 1;
    final g = 2 * math.pi / 365 * (n - 1);
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(g) -
            0.032077 * math.sin(g) -
            0.014615 * math.cos(2 * g) -
            0.040849 * math.sin(2 * g));
    final decl = 0.006918 -
        0.399912 * math.cos(g) +
        0.070257 * math.sin(g) -
        0.006758 * math.cos(2 * g) +
        0.000907 * math.sin(2 * g) -
        0.002697 * math.cos(3 * g) +
        0.00148 * math.sin(3 * g);
    final latR = lat * math.pi / 180;
    final cosH =
        math.cos(90.833 * math.pi / 180) / (math.cos(latR) * math.cos(decl)) -
            math.tan(latR) * math.tan(decl);
    if (cosH < -1) return const SunTimes.polarDay();
    if (cosH > 1) return const SunTimes.polarNight();
    final ha = math.acos(cosH) * 180 / math.pi;
    final riseUtcMin = 720 - 4 * (lon + ha) - eqTime;
    final setUtcMin = 720 - 4 * (lon - ha) - eqTime;
    DateTime at(double minutes) =>
        date.add(Duration(seconds: (minutes * 60).round()));
    return SunTimes(at(riseUtcMin), at(setUtcMin));
  }
}
