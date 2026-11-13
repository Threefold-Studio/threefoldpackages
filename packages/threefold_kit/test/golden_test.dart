import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:threefold_kit/threefold_kit.dart';

/// Runs every case in test/golden/*.json. A TypeScript twin reads the same
/// files, so the two ports cannot drift apart without a failing test.
Map<String, Object?> _load(String name) =>
    jsonDecode(File('test/golden/$name').readAsStringSync())
        as Map<String, Object?>;

List<Map<String, Object?>> _cases(Map<String, Object?> file, String key) =>
    (file[key]! as List<Object?>).cast<Map<String, Object?>>();

CalendarDate _d(Object? s) => CalendarDate.parse(s! as String);
DateTime _wall(Object? s) => DateTime.parse(s! as String);
String _wallText(DateTime w) =>
    '${CalendarDate.fromDateTime(w).key}T${w.hour.toString().padLeft(2, '0')}'
    ':${w.minute.toString().padLeft(2, '0')}';

void main() {
  group('format_cases.json', () {
    final f = _load('format_cases.json');

    for (final c in _cases(f, 'formatCents')) {
      test('formatCents ${c['in']} ${c['mode']}', () {
        final mode = CentsMode.values.byName(c['mode']! as String);
        expect(formatCents(c['in']! as int, mode: mode), c['out']);
      });
    }
    for (final c in _cases(f, 'parseCents')) {
      test('parseCents "${c['in']}"', () {
        expect(
            parseCents(c['in'] as String?,
                allowNegative: c['allowNegative'] as bool? ?? false),
            c['out']);
      });
    }
    for (final c in _cases(f, 'grossUpCents')) {
      test('grossUpCents ${c['subtotal']} at ${c['feeBps']} bps', () {
        expect(grossUpCents(c['subtotal']! as int, feeBps: c['feeBps']! as int),
            c['out']);
      });
    }
    for (final c in _cases(f, 'formatCount')) {
      test('formatCount ${c['in']}', () {
        expect(formatCount(c['in']! as int), c['out']);
      });
    }
    for (final c in _cases(f, 'formatBps')) {
      test('formatBps ${c['in']}', () {
        expect(formatBps(c['in']! as int), c['out']);
      });
    }
    for (final c in _cases(f, 'formatPhone')) {
      test('formatPhone "${c['in']}"', () {
        expect(formatPhone(c['in'] as String?), c['out']);
      });
    }
    for (final c in _cases(f, 'toE164')) {
      test('toE164 "${c['in']}"', () {
        expect(toE164(c['in'] as String?), c['out']);
      });
    }
    for (final c in _cases(f, 'phoneProblem')) {
      test('phoneProblem "${c['in']}"', () {
        expect(phoneProblem(c['in'] as String?), c['out']);
      });
    }
    for (final c in _cases(f, 'formatPhoneTyping')) {
      test('formatPhoneTyping "${c['in']}" after "${c['previous']}"', () {
        expect(
            formatPhoneTyping(c['in']! as String,
                previous: c['previous']! as String),
            c['out']);
      });
    }
  });

  group('time_cases.json', () {
    final f = _load('time_cases.json');

    for (final c in _cases(f, 'daysBetween')) {
      test('daysBetween ${c['a']} ${c['b']}', () {
        expect(daysBetween(_d(c['a']), _d(c['b'])), c['out']);
      });
    }
    for (final c in _cases(f, 'addDays')) {
      test('addDays ${c['in']} ${c['n']}', () {
        expect(_d(c['in']).addDays(c['n']! as int).key, c['out']);
      });
    }
    for (final c in _cases(f, 'addMonths')) {
      test('addMonths ${c['in']} ${c['n']}', () {
        expect(_d(c['in']).addMonths(c['n']! as int).key, c['out']);
      });
    }
    for (final c in _cases(f, 'parseDate')) {
      test('parseDate "${c['in']}"', () {
        expect(CalendarDate.tryParse(c['in'] as String?)?.key, c['out']);
      });
    }
    for (final c in _cases(f, 'weekday')) {
      test('weekday ${c['in']}', () {
        expect(_d(c['in']).weekday, c['out']);
      });
    }
    for (final c in _cases(f, 'dayKey')) {
      test('dayKey ${c['instant']} ${c['zone']}', () {
        final place = PlaceTime(c['zone']! as String);
        expect(place.dayKey(DateTime.parse(c['instant']! as String)), c['out']);
      });
    }
    for (final c in _cases(f, 'wallToUtc')) {
      test('wallToUtc ${c['wall']} ${c['zone']}', () {
        final place = PlaceTime(c['zone']! as String);
        expect(place.fromWall(_wall(c['wall'])).toIso8601String(), c['out']);
      });
    }
    for (final c in _cases(f, 'utcToWall')) {
      test('utcToWall ${c['instant']} ${c['zone']}', () {
        final place = PlaceTime(c['zone']! as String);
        final wall = place.toWall(DateTime.parse(c['instant']! as String));
        expect(_wallText(wall), c['out']);
      });
    }
    for (final c in _cases(f, 'formatLongDate')) {
      test('formatLongDate ${c['in']}', () {
        expect(formatLongDate(_d(c['in'])), c['out']);
      });
    }
    for (final c in _cases(f, 'formatShortDate')) {
      test('formatShortDate ${c['in']}', () {
        expect(formatShortDate(_d(c['in']), today: _d(c['today'])), c['out']);
      });
    }
    for (final c in _cases(f, 'formatWeekdayDate')) {
      test('formatWeekdayDate ${c['in']}', () {
        expect(formatWeekdayDate(_d(c['in'])), c['out']);
      });
    }
    for (final c in _cases(f, 'formatRelativeDay')) {
      test('formatRelativeDay ${c['in']}', () {
        expect(formatRelativeDay(_d(c['in']), today: _d(c['today'])), c['out']);
      });
    }
    for (final c in _cases(f, 'formatDateRange')) {
      test('formatDateRange ${c['start']} ${c['end']}', () {
        expect(
            formatDateRange(_d(c['start']), _d(c['end']),
                today: _d(c['today'])),
            c['out']);
      });
    }
    for (final c in _cases(f, 'formatTime')) {
      test('formatTime ${c['wall']}', () {
        expect(formatTime(_wall(c['wall'])), c['out']);
      });
    }
    for (final c in _cases(f, 'formatTimeRange')) {
      test('formatTimeRange ${c['start']} ${c['end']}', () {
        expect(formatTimeRange(_wall(c['start']), _wall(c['end'])), c['out']);
      });
    }
    for (final c in _cases(f, 'formatClockMinutes')) {
      test('formatClockMinutes ${c['in']}', () {
        expect(formatClockMinutes(c['in']! as int), c['out']);
      });
    }
    for (final c in _cases(f, 'parseClockMinutes')) {
      test('parseClockMinutes "${c['in']}"', () {
        expect(parseClockMinutes(c['in'] as String?), c['out']);
      });
    }
  });

  group('copy_cases.json', () {
    final f = _load('copy_cases.json');

    for (final c in _cases(f, 'findDashes')) {
      test('findDashes ${c['rules']} "${c['text']}"', () {
        final rules = CopyRules.values.byName(c['rules']! as String);
        final kinds = findDashes(c['text']! as String, rules: rules)
            .map((i) => i.kind.name)
            .toList();
        expect(kinds, c['kinds']);
      });
    }
    for (final c in _cases(f, 'titleCase')) {
      test('titleCase "${c['in']}"', () {
        expect(titleCase(c['in']! as String), c['out']);
      });
    }
    for (final c in _cases(f, 'plural')) {
      test('plural ${c['n']} ${c['one']}', () {
        expect(
            plural(c['n']! as int, c['one']! as String, c['many'] as String?),
            c['out']);
      });
    }
  });
}
