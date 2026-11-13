/// Season pass progress and rules (SOP R15.13). Taken from the games'
/// `PassProgress` and `Season`, with the time passed in instead of
/// the phone clock and the reward type supplied by the game.
library;

/// The player's pass progress. JSON keys match the games' existing
/// `PassProgress`, so saves and the `sync-progress` payload are unchanged.
class PassProgress {
  PassProgress({
    required this.seasonId,
    this.xp = 0,
    this.premium = false,
    Set<int>? claimedFree,
    Set<int>? claimedPremium,
  })  : claimedFree = claimedFree ?? <int>{},
        claimedPremium = claimedPremium ?? <int>{};

  String seasonId;
  int xp;

  /// Set only from the purchase webhook (through sync); never by the client
  /// on its own in a store build.
  bool premium;
  final Set<int> claimedFree;
  final Set<int> claimedPremium;

  Map<String, dynamic> toJson() => {
        'seasonId': seasonId,
        'xp': xp,
        'premium': premium,
        'claimedFree': claimedFree.toList()..sort(),
        'claimedPremium': claimedPremium.toList()..sort(),
      };

  factory PassProgress.fromJson(Map<String, dynamic> j) => PassProgress(
        seasonId: j['seasonId'] as String? ?? '',
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        premium: j['premium'] as bool? ?? false,
        claimedFree: ((j['claimedFree'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toSet(),
        claimedPremium: ((j['claimedPremium'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toSet(),
      );
}

/// One tier: an optional free reward and a premium reward.
class PassTier<R> {
  const PassTier(this.tier, this.free, this.premium);

  /// 1-based tier number, as in the season JSON.
  final int tier;
  final R? free;
  final R? premium;
}

/// A season definition, loaded from the game's bundled JSON or bootstrap.
class Season<R> {
  const Season({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.xpPerTier,
    required this.tiers,
    this.premiumProductId = '',
  }) : assert(xpPerTier > 0);

  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final int xpPerTier;
  final String premiumProductId;
  final List<PassTier<R>> tiers;

  bool isActive(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  /// Parses the games' season JSON. [reward] turns one reward object into the
  /// game's reward type.
  factory Season.fromJson(
          Map<String, dynamic> j, R Function(Map<String, dynamic>) reward) =>
      Season(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        xpPerTier: (j['xpPerTier'] as num).toInt(),
        premiumProductId: j['premiumProductId'] as String? ?? '',
        tiers: [
          for (final e in (j['tiers'] as List).cast<Map<String, dynamic>>())
            PassTier<R>(
              (e['tier'] as num).toInt(),
              e['free'] == null
                  ? null
                  : reward(Map<String, dynamic>.from(e['free'] as Map)),
              e['premium'] == null
                  ? null
                  : reward(Map<String, dynamic>.from(e['premium'] as Map)),
            ),
        ],
      );
}

/// The pass rules for one season.
class SeasonPass<R> {
  const SeasonPass(this.season);

  final Season<R> season;

  int get maxTier => season.tiers.length;

  /// Tiers reached with [xp], 0 to [maxTier].
  int tierForXp(int xp) => (xp ~/ season.xpPerTier).clamp(0, maxTier);

  int tier(PassProgress p) => tierForXp(p.xp);

  /// Progress inside the current tier, 0 to 1 (1 once the pass is done).
  double progressInTier(PassProgress p) {
    if (tier(p) >= maxTier) return 1;
    return (p.xp % season.xpPerTier) / season.xpPerTier;
  }

  /// Makes [p] belong to this season. Progress from another season starts
  /// over, including premium (each season is bought separately). Returns
  /// true when it reset.
  bool adopt(PassProgress p) {
    if (p.seasonId == season.id) return false;
    p
      ..seasonId = season.id
      ..xp = 0
      ..premium = false
      ..claimedFree.clear()
      ..claimedPremium.clear();
    return true;
  }

  /// Adds XP while the season is running. Returns the XP actually added.
  int addXp(PassProgress p, int xp, DateTime now) {
    if (xp <= 0 || p.seasonId != season.id || !season.isActive(now)) return 0;
    p.xp += xp;
    return xp;
  }

  PassTier<R>? _tier(int n) {
    for (final t in season.tiers) {
      if (t.tier == n) return t;
    }
    return null;
  }

  /// Whether [tierNumber] can be claimed on the free or premium track.
  /// [hold] is `GameClock.holdClaims`.
  bool canClaim(PassProgress p, int tierNumber,
      {required bool premium, bool hold = false}) {
    if (hold || p.seasonId != season.id) return false;
    if (tierNumber < 1 || tierNumber > tier(p)) return false;
    final t = _tier(tierNumber);
    if (t == null) return false;
    if (premium) {
      return p.premium &&
          t.premium != null &&
          !p.claimedPremium.contains(tierNumber);
    }
    return t.free != null && !p.claimedFree.contains(tierNumber);
  }

  /// Records the claim and returns the reward, or null when it cannot be
  /// claimed. The game grants the reward; the server re-checks the tier
  /// against its own XP in `claim-pass-reward`.
  R? claim(PassProgress p, int tierNumber,
      {required bool premium, bool hold = false}) {
    if (!canClaim(p, tierNumber, premium: premium, hold: hold)) return null;
    final t = _tier(tierNumber)!;
    if (premium) {
      p.claimedPremium.add(tierNumber);
      return t.premium;
    }
    p.claimedFree.add(tierNumber);
    return t.free;
  }

  /// Every tier with something left to claim on either track.
  List<int> claimableTiers(PassProgress p, {bool hold = false}) => [
        for (final t in season.tiers)
          if (canClaim(p, t.tier, premium: false, hold: hold) ||
              canClaim(p, t.tier, premium: true, hold: hold))
            t.tier,
      ];
}
