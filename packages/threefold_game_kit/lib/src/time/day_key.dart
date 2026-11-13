/// Day keys: a local calendar day written as 'yyyy-MM-dd'.
///
/// Daily rewards, streaks and weekly goals reset on the player's local
/// calendar day (SOP R9.12). All day arithmetic here goes through calendar
/// fields on UTC dates, so daylight saving changes can never add or lose a
/// day (SOP R9.4).
library;

/// The day key for the calendar fields of [time]. Pass a local DateTime
/// (for example `clock.now()`) to get the player's local day.
String dayKey(DateTime time) => '${time.year.toString().padLeft(4, '0')}-'
    '${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

/// Parses a day key into a UTC midnight. Returns null for anything that is
/// not a valid 'yyyy-MM-dd' date.
DateTime? tryParseDayKey(String? key) {
  if (key == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final utc = DateTime.utc(y, mo, d);
  // Reject dates that roll over, such as 2026-02-30.
  if (utc.year != y || utc.month != mo || utc.day != d) return null;
  return utc;
}

DateTime _parse(String key) {
  final t = tryParseDayKey(key);
  if (t == null) throw FormatException('Not a day key', key);
  return t;
}

/// Whole calendar days from [a] to [b] (negative when [b] is earlier).
/// Daylight saving cannot change it. Throws [FormatException] on a bad key.
int daysBetween(String a, String b) =>
    // Both are UTC midnights, so the difference is an exact multiple of 24h.
    _parse(b).difference(_parse(a)).inHours ~/ 24;

/// The day key [n] calendar days after [key] ([n] may be negative).
String addDaysToKey(String key, int n) {
  final t = _parse(key);
  return dayKey(DateTime.utc(t.year, t.month, t.day + n));
}

/// The day key of the calendar day before the local day of [time]. Built
/// from fields, never by subtracting 24 hours, so it is right just after a
/// spring forward midnight.
String yesterdayKey(DateTime time) =>
    dayKey(DateTime.utc(time.year, time.month, time.day - 1));

/// The day key of the Monday that starts the week holding [time]'s
/// calendar day (weekly goals reset on Monday, SOP R9.12).
String weekStartKey(DateTime time) {
  final d = DateTime.utc(time.year, time.month, time.day);
  return dayKey(DateTime.utc(d.year, d.month, d.day - (d.weekday - 1)));
}
