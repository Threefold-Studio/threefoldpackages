import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:threefold_kit/threefold_kit.dart';

void main() {
  tearDown(DevClock.disableForTesting);

  group('AppClock', () {
    test('reads package:clock, so tests can pin it', () {
      withClock(Clock.fixed(DateTime(2026, 11, 1, 1, 30)), () {
        expect(AppClock.now(), DateTime(2026, 11, 1, 1, 30));
        expect(AppClock.today(), const CalendarDate(2026, 11, 1));
        expect(AppClock.nowUtc().isUtc, isTrue);
      });
    });

    test('nowUtc stores with a Z', () {
      withClock(Clock.fixed(DateTime.utc(2026, 11, 12, 23, 30)), () {
        expect(AppClock.nowUtc().toIso8601String(), endsWith('Z'));
      });
    });
  });

  group('DevClock', () {
    final fixed = DateTime.utc(2026, 11, 12, 9);

    test('does nothing until enabled', () {
      withClock(Clock.fixed(fixed), () {
        DevClock.advanceForDev(const Duration(days: 1));
        expect(DevClock.enabled, isFalse);
        expect(DevClock.offset, Duration.zero);
        expect(AppClock.now(), fixed);
      });
    });

    test('moves AppClock when enabled, and resets', () {
      withClock(Clock.fixed(fixed), () {
        DevClock.enableForDev();
        DevClock.advanceForDev(const Duration(hours: 1));
        DevClock.advanceForDev(const Duration(days: 1));
        expect(AppClock.now(), fixed.add(const Duration(days: 1, hours: 1)));
        expect(DevClock.describe(), '+1 day 1 hr');
        DevClock.resetForDev();
        expect(AppClock.now(), fixed);
        expect(DevClock.describe(), 'Real time');
      });
    });

    test('announces every change', () async {
      DevClock.enableForDev();
      final seen = <Duration>[];
      final sub = DevClock.changes.listen(seen.add);
      DevClock.advanceForDev(const Duration(hours: 2));
      DevClock.resetForDev();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [const Duration(hours: 2), Duration.zero]);
    });

    test('disabling clears the offset', () {
      DevClock.enableForDev();
      DevClock.advanceForDev(const Duration(days: 3));
      DevClock.disableForTesting();
      expect(DevClock.offset, Duration.zero);
    });

    test('describeOffset', () {
      expect(describeOffset(Duration.zero), 'Real time');
      expect(describeOffset(const Duration(days: 2, hours: 3)), '+2 days 3 hr');
      expect(describeOffset(const Duration(minutes: -45)), '-45 min');
      expect(describeOffset(const Duration(seconds: 20)), '+0 min');
    });
  });

  group('CalendarDate', () {
    test('day count survives spring forward and fall back (R9.14)', () {
      expect(
          const CalendarDate(2026, 3, 7)
              .daysUntil(const CalendarDate(2026, 3, 9)),
          2);
      expect(
          const CalendarDate(2026, 10, 31)
              .daysUntil(const CalendarDate(2026, 11, 2)),
          2);
    });

    test('normalized rolls fields over', () {
      expect(
          CalendarDate.normalized(2026, 1, 32), const CalendarDate(2026, 2, 1));
      expect(
          CalendarDate.normalized(2026, 13, 1), const CalendarDate(2027, 1, 1));
      expect(
          CalendarDate.normalized(2026, 3, 0), const CalendarDate(2026, 2, 28));
    });

    test('isValid', () {
      expect(const CalendarDate(2028, 2, 29).isValid, isTrue);
      expect(const CalendarDate(2026, 2, 29).isValid, isFalse);
      expect(const CalendarDate(2026, 4, 31).isValid, isFalse);
    });

    test('parse throws on junk, tryParse returns null', () {
      expect(() => CalendarDate.parse('soon'), throwsFormatException);
      expect(CalendarDate.tryParse('soon'), isNull);
    });

    test('equality, hashing and ordering', () {
      const a = CalendarDate(2026, 11, 12);
      expect(a, CalendarDate.fromDateTime(DateTime(2026, 11, 12, 23, 59)));
      expect(<CalendarDate>{a, CalendarDate.normalized(2026, 11, 12)},
          hasLength(1));
      expect(a.hashCode, CalendarDate.normalized(2026, 11, 12).hashCode);
      final list = [
        const CalendarDate(2027, 1, 1),
        const CalendarDate(2026, 12, 31),
        const CalendarDate(2026, 2, 1),
      ]..sort();
      expect(
          list.map((d) => d.key), ['2026-02-01', '2026-12-31', '2027-01-01']);
      expect(a.isBefore(const CalendarDate(2026, 11, 13)), isTrue);
      expect(a.isAfter(const CalendarDate(2026, 11, 13)), isFalse);
    });

    test('JSON is the day key', () {
      expect(jsonEncode({'due': const CalendarDate(2026, 8, 6)}),
          '{"due":"2026-08-06"}');
      expect(const CalendarDate(2026, 8, 6).toString(), '2026-08-06');
    });

    test('addYears clamps Feb 29', () {
      expect(const CalendarDate(2028, 2, 29).addYears(1),
          const CalendarDate(2029, 2, 28));
      expect(const CalendarDate(2028, 2, 29).addYears(4),
          const CalendarDate(2032, 2, 29));
    });

    test('startOfWeek, Sunday or Monday first', () {
      const thu = CalendarDate(2026, 11, 12);
      expect(thu.startOfWeek(), const CalendarDate(2026, 11, 8));
      expect(thu.startOfWeek(firstDay: DateTime.monday),
          const CalendarDate(2026, 11, 9));
      const sun = CalendarDate(2026, 11, 15);
      expect(sun.startOfWeek(), sun);
      expect(sun.startOfWeek(firstDay: DateTime.monday),
          const CalendarDate(2026, 11, 9));
      // A week strip across spring forward has no hour drift.
      expect(const CalendarDate(2026, 3, 11).startOfWeek(),
          const CalendarDate(2026, 3, 8));
    });

    test('startOfMonth, toUtcDateTime and toPickerDateTime', () {
      const d = CalendarDate(2026, 11, 12);
      expect(d.startOfMonth, const CalendarDate(2026, 11, 1));
      expect(d.toUtcDateTime(), DateTime.utc(2026, 11, 12));
      expect(d.toPickerDateTime(), DateTime(2026, 11, 12));
    });

    test('daysInMonth and nextDayKey', () {
      expect(daysInMonth(2028, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2026, 12), 31);
      expect(nextDayKey('2026-03-08'), '2026-03-09');
      expect(nextDayKey('2026-12-31'), '2027-01-01');
      expect(nextDayKey('nope'), isNull);
    });

    test('DateOnly is the same type', () {
      const DateOnly d = CalendarDate(2026, 1, 1);
      expect(d, isA<CalendarDate>());
    });
  });

  group('PlaceTime', () {
    final ny = PlaceTime('America/New_York');

    test('a bad zone falls back instead of crashing', () {
      final p = PlaceTime('Mars/Olympus');
      expect(p.zoneName, PlaceTime.defaultZone);
      expect(p.usedFallback, isTrue);
      expect(ny.usedFallback, isFalse);
      expect(
          PlaceTime('', fallback: 'America/Denver').zoneName, 'America/Denver');
    });

    test('load and save with no edits never moves the value (R9.6)', () {
      for (final iso in [
        '2026-03-08T06:59:00Z',
        '2026-03-08T07:00:00Z',
        '2026-11-01T05:30:00Z',
        '2026-11-01T07:00:00Z',
        '2026-11-12T23:30:00Z',
      ]) {
        final instant = DateTime.parse(iso);
        final once = ny.fromWall(ny.toWall(instant));
        // 1:30 AM on Nov 1 happens twice; the first reading (EDT) wins, and
        // saving that wall clock again is stable.
        expect(ny.fromWall(ny.toWall(once)), once, reason: iso);
        if (iso != '2026-11-01T05:30:00Z') expect(once, instant, reason: iso);
      }
    });

    test('a time skipped by spring forward lands after the gap', () {
      final out = ny.fromWall(DateTime(2026, 3, 8, 2, 30));
      expect(ny.toWall(out).hour, 3);
    });

    test('wall fields ignore the zone the picker claims', () {
      expect(ny.fromWall(DateTime.utc(2026, 11, 12, 18, 30)),
          ny.fromWall(DateTime(2026, 11, 12, 18, 30)));
    });

    test('fromDateAndMinutes', () {
      expect(
          ny.fromDateAndMinutes(const CalendarDate(2026, 11, 12), 18 * 60 + 30),
          DateTime.utc(2026, 11, 12, 23, 30));
    });

    test('today, now and hasPassed use the injected clock', () {
      // 11:30 PM in New York on Nov 12 is already Nov 13 in UTC.
      DateTime late() => DateTime.utc(2026, 11, 13, 4, 30);
      expect(ny.today(clockNow: late), const CalendarDate(2026, 11, 12));
      expect(ny.now(clockNow: late), DateTime(2026, 11, 12, 23, 30));
      expect(ny.hasPassed(const CalendarDate(2026, 11, 12), clockNow: late),
          isFalse);
      expect(ny.hasPassed(const CalendarDate(2026, 11, 11), clockNow: late),
          isTrue);
    });

    test('today defaults to AppClock, dev offset included', () {
      withClock(Clock.fixed(DateTime.utc(2026, 11, 12, 15)), () {
        expect(ny.today(), const CalendarDate(2026, 11, 12));
        DevClock.enableForDev();
        DevClock.advanceForDev(const Duration(days: 1));
        expect(ny.today(), const CalendarDate(2026, 11, 13));
      });
    });

    test('dayOf and startOfDayUtc', () {
      expect(ny.dayOf(DateTime.utc(2026, 11, 13, 3)),
          const CalendarDate(2026, 11, 12));
      expect(ny.startOfDayUtc(const CalendarDate(2026, 11, 12)),
          DateTime.utc(2026, 11, 12, 5));
      expect(ny.startOfDayUtc(const CalendarDate(2026, 7, 4)),
          DateTime.utc(2026, 7, 4, 4));
    });

    test('abbreviations', () {
      final winter = DateTime.utc(2026, 11, 12, 12);
      final summer = DateTime.utc(2026, 7, 4, 12);
      expect(ny.abbreviation(winter), 'EST');
      expect(ny.abbreviation(summer), 'EDT');
      expect(
          ny.abbreviationIfDiffering(winter,
              deviceOffset: const Duration(hours: -5)),
          isNull);
      expect(
          ny.abbreviationIfDiffering(winter,
              deviceOffset: const Duration(hours: -7)),
          'EST');
    });
  });

  group('formats', () {
    test('month and weekday names', () {
      expect(monthName(11), 'November');
      expect(monthName(99), 'December');
      expect(monthShortName(1), 'Jan');
      expect(weekdayName(DateTime.thursday), 'Thursday');
      expect(weekdayShortName(DateTime.sunday), 'Sun');
    });

    test('formatDateTimeLong', () {
      expect(formatDateTimeLong(DateTime(2026, 9, 6, 9)),
          'September 6, 2026 at 9:00 AM');
    });

    test('formatAge', () {
      final now = DateTime.utc(2026, 11, 12, 12);
      expect(formatAge(now.subtract(const Duration(seconds: 30)), now: now),
          'just now');
      expect(formatAge(now.subtract(const Duration(minutes: 5)), now: now),
          '5 min ago');
      expect(formatAge(now.subtract(const Duration(hours: 3)), now: now),
          '3 hr ago');
      expect(formatAge(now.subtract(const Duration(days: 1)), now: now),
          '1 day ago');
      expect(formatAge(now.subtract(const Duration(days: 4)), now: now),
          '4 days ago');
    });

    test('Countdown is instant to instant and never negative', () {
      final now = DateTime.utc(2026, 11, 12, 12);
      final c =
          Countdown(DateTime.parse('2026-12-01T00:00:00-05:00'), now: now);
      expect(c.days, 18);
      expect(c.hours, 17);
      expect(c.minutes, 0);
      expect(c.seconds, 0);
      expect(c.expired, isFalse);
      expect(
          Countdown(now.subtract(const Duration(minutes: 1)), now: now).expired,
          isTrue);
    });

    test('formatDaysToGo counts calendar days', () {
      const today = CalendarDate(2026, 3, 7);
      expect(formatDaysToGo(const CalendarDate(2026, 3, 23), today: today),
          '16 days to go');
      expect(formatDaysToGo(const CalendarDate(2026, 3, 8), today: today),
          '1 day to go');
      expect(formatDaysToGo(today, today: today), 'Today');
      expect(
          formatDaysToGo(const CalendarDate(2026, 3, 6), today: today), isNull);
    });

    test('no display format carries a dash', () {
      final d = DateTime(2026, 11, 12, 18, 30);
      final day = CalendarDate.fromDateTime(d);
      for (final s in [
        formatLongDate(day),
        formatWeekdayDate(day),
        formatTimeRange(d, d.add(const Duration(hours: 1))),
        formatDateRange(day, day.addDays(2), today: day),
      ]) {
        expect(isCleanCopy(s, rules: CopyRules.website), isTrue, reason: s);
      }
    });
  });
}
