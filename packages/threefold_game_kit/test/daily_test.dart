import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

/// Any reward type works; strings keep the tests readable.
final daily = Daily<String>(DailyConfig(
  welcome: [
    for (var i = 1; i <= 7; i++) ['welcome $i']
  ],
  calendar: [
    for (var i = 1; i <= 7; i++) ['calendar $i']
  ],
  milestoneReward: (d) => ['milestone $d'],
));

DateTime day(int d, [int hour = 12]) => DateTime(2026, 11, d, hour);

void main() {
  test('welcome week, then the repeating calendar', () {
    final s = DailyState();
    daily.onOpen(s, day(1));
    expect(s.firstDay, '2026-11-01');
    for (var i = 0; i < 7; i++) {
      expect(daily.inWelcome(s), isTrue);
      expect(daily.claim(s, day(1 + i)), ['welcome ${i + 1}']);
    }
    expect(daily.inWelcome(s), isFalse);
    for (var i = 0; i < 8; i++) {
      expect(daily.claim(s, day(8 + i)), ['calendar ${i % 7 + 1}']);
    }
  });

  test('one claim per local calendar day', () {
    final s = DailyState();
    expect(daily.claim(s, day(1, 8)), isNotEmpty);
    expect(daily.claimedToday(s, day(1, 23)), isTrue);
    expect(daily.canClaim(s, day(1, 23)), isFalse);
    expect(daily.claim(s, day(1, 23)), isEmpty);
    expect(daily.canClaim(s, day(2, 0)), isTrue);
  });

  test('consecutive days count the streak', () {
    final s = DailyState();
    for (var i = 1; i <= 5; i++) {
      daily.onOpen(s, day(i));
      daily.claim(s, day(i));
    }
    expect(s.streak, 5);
    expect(s.bestStreak, 5);
  });

  test('milestones 2, 3, 5, 7, 10, 14, 21, 30, then every 15', () {
    expect(daily.milestonesUpTo(1), isEmpty);
    expect(daily.milestonesUpTo(7), [2, 3, 5, 7]);
    expect(daily.milestonesUpTo(75), [2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 75]);
    expect(daily.nextMilestone(0), 2);
    expect(daily.nextMilestone(30), 45);
    expect(daily.nextMilestone(46), 60);
  });

  test('milestones are game config', () {
    final custom = Daily<String>(DailyConfig(
      welcome: const [],
      calendar: const [
        ['c']
      ],
      milestoneDays: const [4],
      repeatEvery: 10,
      milestoneReward: (d) => ['m$d'],
    ));
    expect(custom.milestonesUpTo(24), [4, 14, 24]);
    expect(custom.welcomeDays, 0);
    expect(custom.nextReward(DailyState()), ['c']);
  });

  test('milestones claim once each and reset with a new streak', () {
    final s = DailyState();
    for (var i = 1; i <= 3; i++) {
      daily.claim(s, day(i));
    }
    expect(daily.claimableMilestones(s), [2, 3]);
    expect(daily.claimMilestone(s, 2), ['milestone 2']);
    expect(daily.claimMilestone(s, 2), isEmpty);
    expect(daily.claimMilestone(s, 5), isEmpty);
    expect(daily.claimMilestone(s, 3, hold: true), isEmpty);
    expect(daily.claimableMilestones(s), [3]);
  });

  group('missed day and saver', () {
    DailyState fourDays() {
      final s = DailyState();
      for (var i = 1; i <= 4; i++) {
        daily.claim(s, day(i));
      }
      return s;
    }

    test('a missed day breaks the streak and offers the saver', () {
      final s = fourDays();
      expect(daily.onOpen(s, day(5)), isFalse, reason: 'next day is fine');
      expect(daily.onOpen(s, day(6)), isTrue, reason: 'day 5 was missed');
      expect(s.brokenStreak, 4);
      expect(s.streak, 0);
      expect(daily.canClaim(s, day(6)), isFalse,
          reason: 'decide on the saver first');
      expect(daily.onOpen(s, day(6)), isFalse, reason: 'offered once');
    });

    test('saver by currency keeps the streak however long the gap', () {
      final s = fourDays();
      expect(daily.onOpen(s, day(25)), isTrue);
      expect(daily.saveStreak(s, day(25), balance: 99), isNull,
          reason: 'not enough currency');
      expect(s.brokenStreak, 4);
      expect(daily.saveStreak(s, day(25), balance: 500), 100);
      expect(daily.canClaim(s, day(25)), isTrue);
      daily.claim(s, day(25));
      expect(s.streak, 5);
      expect(daily.onOpen(s, day(26)), isFalse);
    });

    test('saver by ad costs nothing', () {
      final s = fourDays();
      daily.onOpen(s, day(7));
      expect(daily.saveStreak(s, day(7), payment: StreakSaverPayment.ad), 0);
      daily.claim(s, day(7));
      expect(s.streak, 5);
    });

    test('nothing to save returns null', () {
      expect(daily.saveStreak(DailyState(), day(1), balance: 1000), isNull);
    });

    test('declining starts over at day 1 and resets milestones', () {
      final s = fourDays();
      daily.claimMilestone(s, 2);
      daily.onOpen(s, day(9));
      daily.declineSave(s);
      daily.claim(s, day(9));
      expect(s.streak, 1);
      expect(s.milestonesClaimed, isEmpty);
      expect(s.bestStreak, 4);
    });

    test('saving just after a spring forward midnight keeps the streak', () {
      final s = DailyState();
      for (var i = 5; i <= 7; i++) {
        daily.claim(s, DateTime(2026, 3, i, 12));
      }
      final now = DateTime(2026, 3, 9, 0, 30);
      expect(daily.onOpen(s, now), isTrue);
      daily.saveStreak(s, now, payment: StreakSaverPayment.ad);
      expect(s.lastClaimDay, '2026-03-08');
      daily.claim(s, now);
      expect(s.streak, 4);
    });

    test('fall back night (Nov 1, 2026) keeps a daily streak', () {
      final s = DailyState();
      daily.claim(s, DateTime(2026, 10, 31, 23, 30));
      daily.claim(s, DateTime(2026, 11, 1, 1, 30));
      expect(daily.onOpen(s, DateTime(2026, 11, 2, 0, 15)), isFalse);
      daily.claim(s, DateTime(2026, 11, 2, 0, 15));
      expect(s.streak, 3);
    });
  });

  group('clock tricks', () {
    test('a claim dated tomorrow (flying west) blocks a second claim', () {
      final s = DailyState();
      daily.claim(s, day(1));
      daily.claim(s, day(2, 0));
      expect(daily.canClaim(s, day(1, 23)), isFalse);
    });

    test('a big jump back (clock fixed) lets the player claim', () {
      final s = DailyState();
      daily.claim(s, day(20));
      expect(daily.canClaim(s, day(10)), isTrue);
    });

    test('hold blocks claims while the clock is skewed', () {
      final s = DailyState();
      expect(daily.canClaim(s, day(1), hold: true), isFalse);
      expect(daily.claim(s, day(1), hold: true), isEmpty);
      expect(s.lastClaimDay, isEmpty);
      expect(daily.claim(s, day(1)), isNotEmpty);
    });

    test('a damaged last claim day counts as long ago', () {
      final s = DailyState(lastClaimDay: 'garbage', streak: 3);
      expect(daily.canClaim(s, day(1)), isTrue);
      expect(daily.onOpen(s, day(1)), isTrue);
    });
  });

  test('JSON keys match the games\' saves', () {
    final s = DailyState(
        firstDay: '2026-10-21',
        welcomeClaimed: 7,
        calendarIndex: 12,
        lastClaimDay: '2026-11-12',
        streak: 19,
        bestStreak: 19,
        milestonesClaimed: {7, 2});
    final j = s.toJson();
    expect(j['milestonesClaimed'], [2, 7]);
    final back = DailyState.fromJson(j);
    expect(back.toJson(), j);
    expect(DailyState.fromJson(null).streak, 0);
  });
}
