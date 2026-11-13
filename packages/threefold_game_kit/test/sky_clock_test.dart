import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

void main() {
  const ny = SkyClock(timeZone: 'America/New_York');

  test('New York solstice sunrise and sunset within a few minutes', () {
    final (lat, lon) = kTimeZonePlaces['America/New_York']!;
    final sun = SkyClock.sunTimes(2026, 6, 21, lat, lon);
    // Published: sunrise 5:25 AM EDT (09:25Z), sunset 8:31 PM EDT (00:31Z).
    expect(
        sun.rise!.difference(DateTime.utc(2026, 6, 21, 9, 25)).inMinutes.abs(),
        lessThan(6));
    expect(
        sun.set!.difference(DateTime.utc(2026, 6, 22, 0, 31)).inMinutes.abs(),
        lessThan(6));
  });

  test('phases through a New York day (UTC instants)', () {
    expect(ny.phaseAt(DateTime.utc(2026, 6, 21, 7)), SkyPhase.night);
    expect(ny.phaseAt(DateTime.utc(2026, 6, 21, 9, 25)), SkyPhase.sunrise);
    expect(ny.phaseAt(DateTime.utc(2026, 6, 21, 16)), SkyPhase.day);
    // 8:10 PM EDT is already the next UTC day: still the June 21 sunset.
    expect(ny.phaseAt(DateTime.utc(2026, 6, 22, 0, 10)), SkyPhase.sunset);
    expect(ny.phaseAt(DateTime.utc(2026, 6, 22, 3)), SkyPhase.night);
  });

  test('the window edges are exclusive', () {
    final (lat, lon) = kTimeZonePlaces['America/New_York']!;
    final rise = SkyClock.sunTimes(2026, 6, 21, lat, lon).rise!;
    const w = Duration(minutes: 45);
    expect(ny.phaseAt(rise.subtract(w)), SkyPhase.night);
    expect(ny.phaseAt(rise.subtract(w).add(const Duration(seconds: 1))),
        SkyPhase.sunrise);
    expect(ny.phaseAt(rise.add(w)), SkyPhase.day);
    const short =
        SkyClock(timeZone: 'America/New_York', window: Duration(minutes: 10));
    expect(short.phaseAt(rise.add(const Duration(minutes: 11))), SkyPhase.day);
  });

  test('a zone far from UTC reads the right day', () {
    const tokyo = SkyClock(timeZone: 'Asia/Tokyo');
    // Noon in Tokyo is 03:00Z; midnight in Tokyo is 15:00Z the day before.
    expect(tokyo.phaseAt(DateTime.utc(2026, 6, 21, 3)), SkyPhase.day);
    expect(tokyo.phaseAt(DateTime.utc(2026, 6, 20, 15)), SkyPhase.night);
    const honolulu = SkyClock(timeZone: 'Pacific/Honolulu');
    // Noon in Honolulu is 22:00Z.
    expect(honolulu.phaseAt(DateTime.utc(2026, 12, 21, 22)), SkyPhase.day);
  });

  test('midnight sun and polar night', () {
    const svalbard = SkyClock(place: (78.2, 15.6));
    expect(svalbard.phaseAt(DateTime.utc(2026, 6, 21, 0)), SkyPhase.day);
    expect(svalbard.phaseAt(DateTime.utc(2026, 12, 21, 12)), SkyPhase.night);
    expect(SkyClock.sunTimes(2026, 6, 21, 78.2, 15.6).alwaysUp, isTrue);
    expect(SkyClock.sunTimes(2026, 12, 21, 78.2, 15.6).alwaysDown, isTrue);
  });

  test('unknown or missing zone uses the fixed schedule', () {
    const none = SkyClock();
    const unknown = SkyClock(timeZone: 'Mars/Olympus');
    expect(none.location, isNull);
    expect(unknown.location, isNull);
    expect(none.phaseAt(DateTime(2026, 1, 1, 4, 59)), SkyPhase.night);
    expect(none.phaseAt(DateTime(2026, 1, 1, 5)), SkyPhase.sunrise);
    expect(none.phaseAt(DateTime(2026, 1, 1, 7)), SkyPhase.day);
    expect(unknown.phaseAt(DateTime(2026, 1, 1, 17)), SkyPhase.sunset);
    expect(unknown.phaseAt(DateTime(2026, 1, 1, 20)), SkyPhase.night);
  });

  test('twilight groups sunrise and sunset for three-picture games', () {
    expect(SkyPhase.sunrise.isTwilight, isTrue);
    expect(SkyPhase.sunset.isTwilight, isTrue);
    expect(SkyPhase.day.isTwilight, isFalse);
    expect(SkyPhase.night.isTwilight, isFalse);
  });

  test('day of year rolls over and ignores DST', () {
    final a = SkyClock.sunTimes(2026, 3, 8, 40.7, -74.0);
    final b = SkyClock.sunTimes(2026, 2, 36, 40.7, -74.0); // = Mar 8
    expect(a.rise, b.rise);
  });
}
