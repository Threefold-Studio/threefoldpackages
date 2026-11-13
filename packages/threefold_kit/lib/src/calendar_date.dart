/// A calendar date with no time and no zone: an event day, a due date, a
/// birthday (SOP R9.1).
///
/// It is never a midnight instant. "August 16" is August 16 wherever the
/// phone is, so nothing here reads or applies a time zone. All arithmetic
/// goes through `DateTime.utc(y, m, d)`, which has no daylight saving time,
/// so a day count across a DST change cannot come up one short (SOP R9.4).
///
/// Borrowed from: thedesignward `dates.dart` ("a calendar date is never an
/// instant", null-safe parsing), nsepto `DateX` (fields, never `Duration`),
/// homecadence `addMonths` (month-end clamping) and the SOP 9.5 `DateOnly`.
class CalendarDate implements Comparable<CalendarDate> {
  /// Exact fields. Use [CalendarDate.normalized] when the fields may roll
  /// over (day 32, month 13), and [isValid] to check typed input.
  const CalendarDate(this.year, this.month, this.day);

  /// Fields that may overflow, rolled into a real date:
  /// `CalendarDate.normalized(2026, 1, 32)` is February 1, 2026.
  factory CalendarDate.normalized(int year, int month, int day) =>
      CalendarDate._fromUtc(DateTime.utc(year, month, day));

  /// The calendar fields of a wall-clock DateTime, ignoring its time and
  /// whatever zone it claims. For an instant at a place, use
  /// `PlaceTime.dayOf`.
  factory CalendarDate.fromDateTime(DateTime wall) =>
      CalendarDate(wall.year, wall.month, wall.day);

  factory CalendarDate._fromUtc(DateTime utc) =>
      CalendarDate(utc.year, utc.month, utc.day);

  final int year;
  final int month;
  final int day;

  static final RegExp _keyShape = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses a `yyyy-MM-dd` day key or Postgres `date`. Returns null rather
  /// than throwing or guessing: blank, another shape, or a day that does not
  /// exist (2026-02-30) all give null.
  static CalendarDate? tryParse(String? text) {
    if (text == null) return null;
    final m = _keyShape.firstMatch(text.trim());
    if (m == null) return null;
    final date = CalendarDate(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    return date.isValid ? date : null;
  }

  /// Like [tryParse], but throws [FormatException] for bad input.
  static CalendarDate parse(String text) =>
      tryParse(text) ?? (throw FormatException('Not a yyyy-MM-dd date', text));

  /// True when the fields name a real day (no February 30, no month 13).
  bool get isValid =>
      month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(year, month);

  DateTime get _utc => DateTime.utc(year, month, day);

  /// 1 is Monday, 7 is Sunday, as `DateTime.weekday`.
  int get weekday => _utc.weekday;

  /// `yyyy-MM-dd`: the one shape a Postgres `date`, a JSON field or a day key
  /// takes. Lexicographic order is chronological.
  String get key => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  /// Whole calendar days from this date to [other]; negative when [other] is
  /// earlier. DST cannot change it.
  int daysUntil(CalendarDate other) =>
      other._utc.difference(_utc).inMilliseconds ~/ Duration.millisecondsPerDay;

  /// [n] calendar days later (or earlier when negative).
  CalendarDate addDays(int n) =>
      CalendarDate._fromUtc(DateTime.utc(year, month, day + n));

  /// [n] months later, clamped to the last day of a shorter month:
  /// January 31 plus one month is February 28 (or 29).
  CalendarDate addMonths(int n) {
    final first = DateTime.utc(year, month + n, 1);
    final last = daysInMonth(first.year, first.month);
    return CalendarDate(first.year, first.month, day > last ? last : day);
  }

  /// [n] years later; February 29 lands on February 28 in a common year.
  CalendarDate addYears(int n) => addMonths(12 * n);

  /// The first day of the week holding this date. US calendars start on
  /// Sunday (the default); pass `DateTime.monday` for a Monday week, as the
  /// games' weekly goals use (SOP R9.12).
  CalendarDate startOfWeek({int firstDay = DateTime.sunday}) {
    final back = (weekday - firstDay) % 7;
    return addDays(-back);
  }

  /// The first day of this month.
  CalendarDate get startOfMonth => CalendarDate(year, month, 1);

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  /// Midnight UTC on this date. Only for libraries that insist on a DateTime
  /// (and for arithmetic); never store or display it as an instant.
  DateTime toUtcDateTime() => _utc;

  /// A plain local DateTime at midnight with these fields, to seed a date
  /// picker. The picker's answer comes back through [CalendarDate.fromDateTime].
  DateTime toPickerDateTime() => DateTime(year, month, day);

  /// The day key, so a CalendarDate can go straight into `jsonEncode`.
  String toJson() => key;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => key;
}

/// The SOP 9.5 name for the same type.
typedef DateOnly = CalendarDate;

/// Whole calendar days from [a] to [b] (negative when [b] is earlier).
int daysBetween(CalendarDate a, CalendarDate b) => a.daysUntil(b);

/// Days in [month] of [year], leap years included.
int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// The calendar day after a `yyyy-MM-dd` key; the twin of nseptoweb's
/// `nextDayKey`. Returns null for a key that does not parse.
String? nextDayKey(String key) => CalendarDate.tryParse(key)?.addDays(1).key;

String _pad(int v, int width) {
  final s = v.abs().toString().padLeft(width, '0');
  return v < 0 ? '-$s' : s;
}
