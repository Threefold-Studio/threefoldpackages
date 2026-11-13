import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

const seasonJson = {
  'id': 's1',
  'name': 'Season One',
  'startsAt': '2026-10-21T00:00:00Z',
  'endsAt': '2026-11-20T00:00:00Z',
  'xpPerTier': 50,
  'premiumProductId': 'game.pass.s1',
  'tiers': [
    {
      'tier': 1,
      'free': {'type': 'coins', 'amount': 30},
      'premium': {'type': 'coins', 'amount': 90},
    },
    {
      'tier': 2,
      'free': null,
      'premium': {'type': 'bundle', 'amount': 1},
    },
    {
      'tier': 3,
      'free': {'type': 'undo', 'amount': 1},
      'premium': {'type': 'coins', 'amount': 200},
    },
  ],
};

String reward(Map<String, dynamic> j) => '${j['type']} ${j['amount']}';

void main() {
  final season = Season<String>.fromJson(seasonJson, reward);
  final pass = SeasonPass(season);
  final during = DateTime.utc(2026, 11, 1);

  test('parses the games\' season JSON', () {
    expect(season.id, 's1');
    expect(season.premiumProductId, 'game.pass.s1');
    expect(season.tiers, hasLength(3));
    expect(season.tiers[1].free, isNull);
    expect(season.tiers[0].premium, 'coins 90');
  });

  test('active window is start inclusive, end exclusive', () {
    expect(season.isActive(DateTime.utc(2026, 10, 21)), isTrue);
    expect(season.isActive(DateTime.utc(2026, 11, 20)), isFalse);
    expect(season.isActive(DateTime.utc(2026, 10, 20, 23)), isFalse);
  });

  test('tiers from XP, capped at the last tier', () {
    expect(pass.tierForXp(0), 0);
    expect(pass.tierForXp(49), 0);
    expect(pass.tierForXp(50), 1);
    expect(pass.tierForXp(149), 2);
    expect(pass.tierForXp(9999), 3);
    final p = PassProgress(seasonId: 's1', xp: 75);
    expect(pass.progressInTier(p), 0.5);
    p.xp = 500;
    expect(pass.progressInTier(p), 1);
  });

  test('XP only counts while the season runs', () {
    final p = PassProgress(seasonId: 's1');
    expect(pass.addXp(p, 30, during), 30);
    expect(pass.addXp(p, 30, DateTime.utc(2026, 12, 1)), 0);
    expect(pass.addXp(p, -5, during), 0);
    expect(p.xp, 30);
  });

  test('free claims up to the reached tier, once each', () {
    final p = PassProgress(seasonId: 's1', xp: 100);
    expect(pass.canClaim(p, 1, premium: false), isTrue);
    expect(pass.claim(p, 1, premium: false), 'coins 30');
    expect(pass.claim(p, 1, premium: false), isNull);
    expect(pass.canClaim(p, 2, premium: false), isFalse, reason: 'no free');
    expect(pass.canClaim(p, 3, premium: false), isFalse, reason: 'not reached');
    expect(pass.canClaim(p, 0, premium: false), isFalse);
    expect(p.claimedFree, {1});
  });

  test('premium needs the premium flag', () {
    final p = PassProgress(seasonId: 's1', xp: 150);
    expect(pass.claim(p, 1, premium: true), isNull);
    p.premium = true;
    expect(pass.claim(p, 2, premium: true), 'bundle 1');
    expect(pass.claimableTiers(p), [1, 3]);
    expect(pass.claimableTiers(p, hold: true), isEmpty);
  });

  test('hold blocks claims', () {
    final p = PassProgress(seasonId: 's1', xp: 150);
    expect(pass.claim(p, 1, premium: false, hold: true), isNull);
    expect(p.claimedFree, isEmpty);
  });

  test('a new season resets progress, premium included', () {
    final p = PassProgress(
        seasonId: 's0', xp: 400, premium: true, claimedFree: {1, 2});
    expect(pass.canClaim(p, 1, premium: false), isFalse,
        reason: 'old season progress');
    expect(pass.adopt(p), isTrue);
    expect(p.seasonId, 's1');
    expect(p.xp, 0);
    expect(p.premium, isFalse);
    expect(p.claimedFree, isEmpty);
    expect(pass.adopt(p), isFalse);
  });

  test('JSON keys match the games\' saves', () {
    final p = PassProgress(
        seasonId: 's1', xp: 420, premium: true, claimedFree: {2, 1});
    final j = p.toJson();
    expect(j, {
      'seasonId': 's1',
      'xp': 420,
      'premium': true,
      'claimedFree': [1, 2],
      'claimedPremium': <int>[],
    });
    expect(PassProgress.fromJson(j).toJson(), j);
    expect(PassProgress.fromJson(const {}).seasonId, '');
  });
}
