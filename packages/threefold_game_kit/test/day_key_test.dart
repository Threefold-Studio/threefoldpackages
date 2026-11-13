import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

void main() {
  test('dayKey pads and reads calendar fields', () {
    expect(dayKey(DateTime(2026, 3, 8, 23, 59)), '2026-03-08');
    expect(dayKey(DateTime.utc(987, 1, 2)), '0987-01-02');
  });

  test('tryParseDayKey rejects bad and rolled-over dates', () {
    expect(tryParseDayKey('2026-11-01'), DateTime.utc(2026, 11, 1));
    expect(tryParseDayKey('2026-02-30'), isNull);
    expect(tryParseDayKey('2026-1-1'), isNull);
    expect(tryParseDayKey(''), isNull);
    expect(tryParseDayKey(null), isNull);
  });

  test('daysBetween ignores daylight saving (2026 US changes)', () {
    expect(daysBetween('2026-03-07', '2026-03-09'), 2); // spring forward Mar 8
    expect(daysBetween('2026-10-31', '2026-11-02'), 2); // fall back Nov 1
    expect(daysBetween('2026-12-31', '2027-01-01'), 1);
    expect(daysBetween('2028-02-28', '2028-03-01'), 2); // leap year
    expect(daysBetween('2026-11-05', '2026-11-01'), -4);
    expect(() => daysBetween('nope', '2026-11-01'), throwsFormatException);
  });

  test('addDaysToKey crosses months, years and DST', () {
    expect(addDaysToKey('2026-03-07', 2), '2026-03-09');
    expect(addDaysToKey('2026-01-31', 1), '2026-02-01');
    expect(addDaysToKey('2027-01-01', -1), '2026-12-31');
    expect(addDaysToKey('2028-02-28', 1), '2028-02-29');
  });

  test('yesterdayKey just after a spring forward midnight', () {
    // 00:30 on Mar 9 is only 23.5 hours after Mar 8 began in US zones.
    expect(yesterdayKey(DateTime(2026, 3, 9, 0, 30)), '2026-03-08');
    expect(yesterdayKey(DateTime(2026, 3, 1)), '2026-02-28');
  });

  test('weekStartKey is the Monday of the week', () {
    expect(weekStartKey(DateTime(2026, 11, 13)), '2026-11-09'); // Friday
    expect(weekStartKey(DateTime(2026, 11, 9)), '2026-11-09'); // Monday
    expect(weekStartKey(DateTime(2026, 11, 8)), '2026-11-02'); // Sunday
    expect(weekStartKey(DateTime(2026, 3, 1)), '2026-02-23');
  });
}
