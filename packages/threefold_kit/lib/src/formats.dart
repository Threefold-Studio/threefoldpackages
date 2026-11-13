/// US English display formats (SOP R9.9, R10.14). Hand-rolled rather than
/// `intl`, as thedesignward does: one locale, no locale data to initialise,
/// and no version fights with flutter_localizations.
///
/// Every function takes wall clock fields or a [CalendarDate] that the caller
/// already projected into the right zone (`PlaceTime.toWall` for a place's
/// event, the device zone for a personal record). Nothing here reads the
/// clock: "today" is always a parameter, as ThrottleEDGE's formatters take
/// `now`.
library;

import 'calendar_date.dart';

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

/// "November", for a month number 1 to 12 (clamped).
String monthName(int month) => _months[(month - 1).clamp(0, 11)];

/// "Nov", for a month number 1 to 12 (clamped).
String monthShortName(int month) => _monthsShort[(month - 1).clamp(0, 11)];

/// "Thursday", for `DateTime.weekday` 1 (Monday) to 7 (Sunday).
String weekdayName(int weekday) => _weekdays[(weekday - 1).clamp(0, 6)];

/// "Thu".
String weekdayShortName(int weekday) => weekdayName(weekday).substring(0, 3);

/// "November 12, 2026".
String formatLongDate(CalendarDate d) =>
    '${monthName(d.month)} ${d.day}, ${d.year}';

/// "Nov 12" in [today]'s year, "Nov 12, 2027" otherwise.
String formatShortDate(CalendarDate d, {required CalendarDate today}) {
  final base = '${monthShortName(d.month)} ${d.day}';
  return d.year == today.year ? base : '$base, ${d.year}';
}

/// "Thursday, November 12".
String formatWeekdayDate(CalendarDate d) =>
    '${weekdayName(d.weekday)}, ${monthName(d.month)} ${d.day}';

/// "Nov 12 to Nov 14"; one date when both ends are the same day.
String formatDateRange(CalendarDate start, CalendarDate end,
    {required CalendarDate today}) {
  final a = formatShortDate(start, today: today);
  if (start == end) return a;
  return '$a to ${formatShortDate(end, today: today)}';
}

/// "Today", "Tomorrow", "Yesterday", then the short date.
String formatRelativeDay(CalendarDate d, {required CalendarDate today}) {
  switch (today.daysUntil(d)) {
    case 0:
      return 'Today';
    case 1:
      return 'Tomorrow';
    case -1:
      return 'Yesterday';
  }
  return formatShortDate(d, today: today);
}

/// "6:30 PM": space, capitals, no leading zero (R9.9). Reads the fields of
/// a wall clock.
String formatTime(DateTime wall) =>
    formatClockMinutes(wall.hour * 60 + wall.minute);

/// "6:30 to 7:30 PM" in the same half of the day, "11:30 AM to 12:30 PM"
/// across noon, and the start alone when the end equals the start (the
/// "no end given" sentinel, R9.7). Ranges say "to", never a dash (R10.10).
String formatTimeRange(DateTime startWall, DateTime endWall) {
  if (endWall == startWall) return formatTime(startWall);
  final sameHalf = (startWall.hour < 12) == (endWall.hour < 12);
  final start = sameHalf
      ? _hourMinute(startWall.hour * 60 + startWall.minute)
      : formatTime(startWall);
  return '$start to ${formatTime(endWall)}';
}

/// "November 12, 2026 at 6:30 PM".
String formatDateTimeLong(DateTime wall) =>
    '${formatLongDate(CalendarDate.fromDateTime(wall))} at ${formatTime(wall)}';

/// Minutes past midnight as "2:30 PM". Wraps, so 1500 is "1:00 AM".
String formatClockMinutes(int minutes) {
  final wrapped = _wrap(minutes);
  return '${_hourMinute(wrapped)} ${wrapped < 720 ? 'AM' : 'PM'}';
}

String _hourMinute(int minutes) {
  final wrapped = _wrap(minutes);
  final h24 = wrapped ~/ 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:${(wrapped % 60).toString().padLeft(2, '0')}';
}

int _wrap(int minutes) => ((minutes % 1440) + 1440) % 1440;

final RegExp _clock = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AP])\.?\s*M?\.?$');
final RegExp _clock24 = RegExp(r'^(\d{1,2})(?::(\d{2}))?$');

/// Free text clock time to minutes past midnight, or null (thedesignward
/// `parseClockMinutes`, anchored at both ends). Accepts "2:00 PM", "2 pm",
/// "2:00p.m.", "14:00". A bare "2" is read as 2 AM rather than guessed at.
int? parseClockMinutes(String? raw) {
  final text = (raw ?? '').trim().toUpperCase();
  if (text.isEmpty) return null;
  final m12 = _clock.firstMatch(text);
  if (m12 != null) {
    var hour = int.parse(m12.group(1)!);
    final minute = int.parse(m12.group(2) ?? '0');
    if (hour < 1 || hour > 12 || minute > 59) return null;
    if (hour == 12) hour = 0;
    if (m12.group(3) == 'P') hour += 12;
    return hour * 60 + minute;
  }
  final m24 = _clock24.firstMatch(text);
  if (m24 == null) return null;
  final hour = int.parse(m24.group(1)!);
  final minute = int.parse(m24.group(2) ?? '0');
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// Elapsed time in words for a "last updated" line: "just now",
/// "5 min ago", "3 hr ago", "2 days ago". Instants, no zone (nsepto
/// `cacheAge`), with `now` passed in.
String formatAge(DateTime instant, {required DateTime now}) {
  final diff = now.toUtc().difference(instant.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  final days = diff.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

/// Countdown parts from [now] to [target], instant to instant (R9.10).
class Countdown {
  Countdown(DateTime target, {required DateTime now})
      : remaining = _nonNegative(target.toUtc().difference(now.toUtc()));

  final Duration remaining;

  static Duration _nonNegative(Duration d) => d.isNegative ? Duration.zero : d;

  bool get expired => remaining == Duration.zero;
  int get days => remaining.inDays;
  int get hours => remaining.inHours % 24;
  int get minutes => remaining.inMinutes % 60;
  int get seconds => remaining.inSeconds % 60;
}

/// "16 days to go", "1 day to go", "Today" (or null once it has passed),
/// counted in calendar days (R9.10 with R9.4).
String? formatDaysToGo(CalendarDate target, {required CalendarDate today}) {
  final n = today.daysUntil(target);
  if (n < 0) return null;
  if (n == 0) return 'Today';
  return '$n ${n == 1 ? 'day' : 'days'} to go';
}
