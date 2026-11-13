import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

const min = 60 * 1000;

void main() {
  const lives = Lives(LivesConfig()); // 5 max, 15 minutes, cap 10
  final t0 = DateTime(2026, 11, 13, 9).millisecondsSinceEpoch;

  test('defaults match the games: 5 max, 15 minutes, cap 10', () {
    expect(lives.config.max, 5);
    expect(lives.config.refill, const Duration(minutes: 15));
    expect(lives.config.cap, 10);
  });

  test('one life back every refill interval, up to max', () {
    final s = LivesState(lives: 1, updatedAtMs: t0);
    expect(lives.refill(s, t0 + 14 * min), 0);
    expect(lives.refill(s, t0 + 15 * min), 1);
    expect(s.lives, 2);
    expect(lives.nextLifeIn(s, t0 + 20 * min), const Duration(minutes: 10));
    expect(lives.refill(s, t0 + 600 * min), 3);
    expect(s.lives, 5);
    expect(lives.nextLifeIn(s, t0 + 600 * min), Duration.zero);
  });

  test('partial progress carries over between refills', () {
    final s = LivesState(lives: 0, updatedAtMs: t0);
    lives.refill(s, t0 + 22 * min);
    expect(s.lives, 1);
    expect(s.updatedAtMs, t0 + 15 * min, reason: '7 minutes kept');
    lives.refill(s, t0 + 30 * min);
    expect(s.lives, 2);
  });

  test('fullAt for the lives full reminder', () {
    final s = LivesState(lives: 3, updatedAtMs: t0);
    expect(lives.fullAt(s, t0 + 5 * min),
        DateTime.fromMillisecondsSinceEpoch(t0 + 30 * min));
    expect(lives.fullAt(LivesState.full(lives.config, t0), t0), isNull);
  });

  test('losing from full starts the timer from now', () {
    final s = LivesState(lives: 5, updatedAtMs: t0 - 1000 * min);
    expect(lives.lose(s, t0), isTrue);
    expect(s.lives, 4);
    expect(s.updatedAtMs, t0);
    expect(lives.nextLifeIn(s, t0), const Duration(minutes: 15));
  });

  test('cannot lose with none left; unlimited costs nothing', () {
    final s = LivesState(lives: 0, updatedAtMs: t0);
    expect(lives.canPlay(s, t0), isFalse);
    expect(lives.lose(s, t0), isFalse);
    lives.grantUnlimited(s, const Duration(minutes: 30), t0);
    expect(lives.canPlay(s, t0), isTrue);
    expect(lives.lose(s, t0 + 10 * min), isFalse);
    expect(lives.unlimitedRemaining(s, t0 + 10 * min),
        const Duration(minutes: 20));
    lives.grantUnlimited(s, const Duration(minutes: 30), t0 + 10 * min);
    expect(s.unlimitedUntilMs, t0 + 60 * min, reason: 'stacks');
    expect(lives.isUnlimited(s, t0 + 60 * min), isFalse);
  });

  test('rewards go above max up to the cap; fill tops up', () {
    final s = LivesState(lives: 4, updatedAtMs: t0);
    lives.add(s, 3, t0);
    expect(s.lives, 7);
    lives.add(s, 10, t0);
    expect(s.lives, 10);
    final low = LivesState(lives: 1, updatedAtMs: t0);
    lives.fill(low, t0);
    expect(low.lives, 5);
  });

  group('time travel', () {
    test('dev clock forward refills like real time', () {
      final clock = GameClock(
          source: () => DateTime.fromMillisecondsSinceEpoch(t0),
          devTools: true);
      final s = LivesState(lives: 0, updatedAtMs: clock.nowMs());
      clock.advanceForDev(const Duration(hours: 1));
      lives.refill(s, clock.nowMs());
      expect(s.lives, 4);
    });

    test('a stamp in the future (clock wound back) is clamped to now', () {
      final s = LivesState(lives: 2, updatedAtMs: t0 + 600 * min);
      lives.refill(s, t0);
      expect(s.updatedAtMs, t0, reason: 'never in the future');
      lives.refill(s, t0 + 15 * min);
      expect(s.lives, 3, reason: 'lives do not freeze');
    });

    test('hold (server skew) grants no catch-up', () {
      final s = LivesState(lives: 0, updatedAtMs: t0);
      expect(lives.refill(s, t0 + 120 * min, hold: true), 0);
      expect(s.lives, 0);
      expect(s.updatedAtMs, t0);
      expect(lives.refill(s, t0 + 120 * min), 5);
    });
  });

  group('daylight saving', () {
    test('fall back (Nov 1, 2026) adds no extra lives', () {
      // 01:30 local, an hour of real time passes, the wall clock shows 01:30
      // again in US zones. Lives count real time only.
      final start = DateTime.utc(2026, 11, 1, 5, 30).millisecondsSinceEpoch;
      final s = LivesState(lives: 0, updatedAtMs: start);
      lives.refill(s, start + 60 * min);
      expect(s.lives, 4);
    });

    test('spring forward (Mar 8, 2026) loses no lives', () {
      final start = DateTime.utc(2026, 3, 8, 6, 50).millisecondsSinceEpoch;
      final s = LivesState(lives: 0, updatedAtMs: start);
      lives.refill(s, start + 30 * min); // wall clock jumps 01:50 to 03:20
      expect(s.lives, 2);
    });
  });

  test('JSON round trip with the game\'s own key names', () {
    final s = LivesState(lives: 3, updatedAtMs: t0, unlimitedUntilMs: 9);
    final j = s.toJson(
        livesKey: 'refills',
        updatedKey: 'refillsUpdatedAt',
        unlimitedKey: 'unlimitedUntil');
    expect(j, {'refills': 3, 'refillsUpdatedAt': t0, 'unlimitedUntil': 9});
    final back = LivesState.fromJson(j,
        config: lives.config,
        nowMs: 0,
        livesKey: 'refills',
        updatedKey: 'refillsUpdatedAt',
        unlimitedKey: 'unlimitedUntil');
    expect(back.lives, 3);
    expect(back.updatedAtMs, t0);
    final empty = LivesState.fromJson({}, config: lives.config, nowMs: t0);
    expect(empty.lives, 5);
    expect(empty.updatedAtMs, t0);
  });

  test('add with hold gives the reward but no timer catch-up', () {
    final s = LivesState(lives: 0, updatedAtMs: t0);
    lives.add(s, 1, t0 + 120 * min, hold: true);
    expect(s.lives, 1);
    final s2 = LivesState(lives: 0, updatedAtMs: t0);
    lives.add(s2, 1, t0 + 120 * min);
    expect(s2.lives, 6,
        reason: 'without hold the overdue timer refills to 5 first');
  });

  test('fullAt counts lives already earned but not yet refilled', () {
    final s = LivesState(lives: 3, updatedAtMs: t0);
    expect(lives.fullAt(s, t0 + 20 * min),
        DateTime.fromMillisecondsSinceEpoch(t0 + 30 * min));
    expect(lives.fullAt(s, t0 + 45 * min), isNull,
        reason: 'already full once refill runs, so no reminder');
  });
}
