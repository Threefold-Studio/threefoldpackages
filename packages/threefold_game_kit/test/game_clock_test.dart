import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

/// Matches a DateTime at the same instant, local or UTC.
Matcher at(DateTime t) => predicate<DateTime>(
    (d) => d.isAtSameMomentAs(t), 'at ${t.toUtc().toIso8601String()}');

void main() {
  late DateTime device;
  DateTime src() => device;

  setUp(() => device = DateTime(2026, 11, 13, 12));

  test('now() follows the injected device clock', () {
    final c = GameClock(source: src);
    expect(c.now(), at(device));
    device = device.add(const Duration(minutes: 5));
    expect(c.now(), at(device));
    expect(c.nowMs(), device.millisecondsSinceEpoch);
  });

  test('server offset corrects a phone clock set wrong', () {
    final c = GameClock(source: src);
    final server = device.add(const Duration(hours: 3));
    c.onServerTime(server);
    expect(c.now(), at(server));
    expect(c.skew, const Duration(hours: 3));
    device = device.add(const Duration(minutes: 1));
    expect(c.now(), at(server.add(const Duration(minutes: 1))));
  });

  test('claims hold only when skew is over the limit', () {
    final c = GameClock(source: src);
    expect(c.skew, isNull);
    expect(c.holdClaims, isFalse, reason: 'never reached the server');
    c.onServerTime(device.add(const Duration(hours: 1, minutes: 59)));
    expect(c.holdClaims, isFalse);
    c.onServerTime(device.subtract(const Duration(hours: 2, minutes: 1)));
    expect(c.holdClaims, isTrue);
    c.onServerTime(device);
    expect(c.holdClaims, isFalse, reason: 'clock fixed');
  });

  test('a clock wound back more than 10 minutes holds at the last seen time',
      () {
    final c = GameClock(source: src);
    final seen = c.now();
    device = device.subtract(const Duration(minutes: 5));
    expect(c.now(), at(device), reason: 'small step back is allowed');
    device = seen.subtract(const Duration(hours: 6));
    expect(c.now(), at(seen), reason: 'big step back is held');
    device = seen.add(const Duration(minutes: 1));
    expect(c.now(), at(device), reason: 'moves again once real time passes');
  });

  test('server time resets the rollback guard', () {
    final c = GameClock(source: src);
    device = device.add(const Duration(days: 2)); // phone set 2 days ahead
    c.now();
    final real = device.subtract(const Duration(days: 2));
    c.onServerTime(real);
    expect(c.now(), at(real), reason: 'server truth, not the held time');
  });

  test('offset and last seen time survive a restart', () async {
    final store = MemoryKeyValueStore();
    final a = GameClock(source: src, store: store);
    a.onServerTime(device.add(const Duration(hours: 3)));
    await Future<void>.delayed(Duration.zero);
    final b = GameClock(source: src, store: store);
    expect(b.now(), at(device.add(const Duration(hours: 3))));
    expect(b.holdClaims, isTrue);
    expect(store.keys, containsAll(['clock.offsetMs', 'clock.lastSeenMs']));
  });

  test('dev time travel needs devTools and never touches storage', () {
    final off = GameClock(source: src);
    off.advanceForDev(const Duration(days: 1));
    expect(off.now(), at(device));
    expect(off.devOffset, Duration.zero);

    final store = MemoryKeyValueStore();
    final on = GameClock(source: src, store: store, devTools: true);
    on.advanceForDev(const Duration(days: 1));
    expect(on.now(), at(device.add(const Duration(days: 1))));
    on.resetDevOffsetForDev();
    expect(on.now(), at(device), reason: 'reset is not seen as a rollback');
    final seen = int.parse(store.getString('clock.lastSeenMs')!);
    expect(seen, lessThanOrEqualTo(device.millisecondsSinceEpoch),
        reason: 'the stored guard time never includes the dev offset');
  });

  test('parseServerTime reads ISO strings and epoch milliseconds', () {
    final t = DateTime.utc(2026, 11, 13, 17, 30);
    expect(parseServerTime('2026-11-13T17:30:00Z'), t);
    expect(parseServerTime('2026-11-13T12:30:00-05:00'), t);
    expect(parseServerTime(t.millisecondsSinceEpoch), t);
    expect(parseServerTime(t.millisecondsSinceEpoch.toDouble()), t);
    expect(parseServerTime('soon'), isNull);
    expect(parseServerTime(null), isNull);
  });
}
