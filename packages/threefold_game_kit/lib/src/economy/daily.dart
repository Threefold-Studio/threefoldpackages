/// Daily rewards, the welcome week, the streak with milestones and the
/// streak saver (SOP R15.12). Taken from the games' `daily.dart`, the
/// version all three games share, with the reward tables passed in.
library;

import '../time/day_key.dart';

/// What the player stores for the daily system. The JSON keys match the
/// games' existing `DailyState`, so current saves load unchanged.
class DailyState {
  DailyState({
    this.firstDay = '',
    this.welcomeClaimed = 0,
    this.calendarIndex = 0,
    this.lastClaimDay = '',
    this.streak = 0,
    this.bestStreak = 0,
    this.brokenStreak = 0,
    Set<int>? milestonesClaimed,
  }) : milestonesClaimed = milestonesClaimed ?? <int>{};

  /// Day key of the first launch.
  String firstDay;

  /// Welcome days claimed so far.
  int welcomeClaimed;

  /// Position in the repeating calendar after the welcome days.
  int calendarIndex;

  /// Day key of the last daily claim. Empty before the first claim.
  String lastClaimDay;

  /// Consecutive days with a claim.
  int streak;
  int bestStreak;

  /// A broken streak waiting for the player to save it or let it go
  /// (0 = none).
  int brokenStreak;

  /// Milestones claimed during the current streak.
  final Set<int> milestonesClaimed;

  Map<String, dynamic> toJson() => {
        'firstDay': firstDay,
        'welcomeClaimed': welcomeClaimed,
        'calendarIndex': calendarIndex,
        'lastClaimDay': lastClaimDay,
        'streak': streak,
        'bestStreak': bestStreak,
        'brokenStreak': brokenStreak,
        'milestonesClaimed': milestonesClaimed.toList()..sort(),
      };

  factory DailyState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return DailyState();
    return DailyState(
      firstDay: j['firstDay'] as String? ?? '',
      welcomeClaimed: (j['welcomeClaimed'] as num?)?.toInt() ?? 0,
      calendarIndex: (j['calendarIndex'] as num?)?.toInt() ?? 0,
      lastClaimDay: j['lastClaimDay'] as String? ?? '',
      streak: (j['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
      brokenStreak: (j['brokenStreak'] as num?)?.toInt() ?? 0,
      milestonesClaimed: ((j['milestonesClaimed'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toSet(),
    );
  }
}

/// How a broken streak is saved.
enum StreakSaverPayment { currency, ad }

/// The game's reward tables. [R] is the game's own reward type.
class DailyConfig<R> {
  const DailyConfig({
    required this.welcome,
    required this.calendar,
    required this.milestoneReward,
    this.milestoneDays = const [2, 3, 5, 7, 10, 14, 21, 30],
    this.repeatEvery = 15,
    this.saverCost = 100,
  }) : assert(calendar.length > 0);

  /// One reward list per welcome day, in order (7 in every game today).
  final List<List<R>> welcome;

  /// The repeating calendar after the welcome days.
  final List<List<R>> calendar;

  /// Streak milestones. After the last one, one every [repeatEvery] days.
  final List<int> milestoneDays;
  final int repeatEvery;

  /// The reward for reaching streak day `day` (any milestone, including the
  /// repeating ones).
  final List<R> Function(int day) milestoneReward;

  /// Currency to save a broken streak (the same however long the player was
  /// away). An ad also saves it.
  final int saverCost;
}

/// The daily rules for one game. All methods take the time, so tests and
/// dev time travel drive them directly. Pass `GameClock.now()`, a local
/// DateTime: days reset on the player's local calendar day.
class Daily<R> {
  const Daily(this.config);

  final DailyConfig<R> config;

  int get welcomeDays => config.welcome.length;

  /// Every milestone at or below [streak].
  List<int> milestonesUpTo(int streak) {
    final days = config.milestoneDays;
    final out = days.where((d) => d <= streak).toList();
    if (days.isEmpty) return out;
    for (var d = days.last + config.repeatEvery;
        d <= streak;
        d += config.repeatEvery) {
      out.add(d);
    }
    return out;
  }

  /// The first milestone above [streak].
  int nextMilestone(int streak) {
    for (final d in config.milestoneDays) {
      if (d > streak) return d;
    }
    var d = (config.milestoneDays.isEmpty ? 0 : config.milestoneDays.last) +
        config.repeatEvery;
    while (d <= streak) {
      d += config.repeatEvery;
    }
    return d;
  }

  /// Call on launch and on every return to the foreground. Returns true when
  /// a streak just broke and the saver should be offered.
  bool onOpen(DailyState s, DateTime now) {
    final today = dayKey(now);
    if (s.firstDay.isEmpty) s.firstDay = today;
    if (s.lastClaimDay.isEmpty || s.streak == 0 || s.brokenStreak > 0) {
      return false;
    }
    if (_gap(s.lastClaimDay, today) >= 2) {
      s.brokenStreak = s.streak;
      s.streak = 0;
      return true;
    }
    return false;
  }

  bool claimedToday(DailyState s, DateTime now) =>
      s.lastClaimDay == dayKey(now);

  /// Whether today's claim is open. [hold] is `GameClock.holdClaims`: while
  /// the phone clock is far off the server's, nothing can be claimed.
  bool canClaim(DailyState s, DateTime now, {bool hold = false}) {
    if (hold || s.brokenStreak > 0) return false;
    if (s.lastClaimDay.isEmpty) return true;
    final gap = _gap(s.lastClaimDay, dayKey(now));
    // 0: already claimed today. -1: the last claim is dated tomorrow, for
    // example after flying west across midnight; claiming would give a
    // second reward. A bigger jump back is a clock that was fixed.
    return gap >= 1 || gap < -1;
  }

  bool inWelcome(DailyState s) => s.welcomeClaimed < welcomeDays;

  /// What the next claim gives.
  List<R> nextReward(DailyState s) => inWelcome(s)
      ? config.welcome[s.welcomeClaimed]
      : config.calendar[s.calendarIndex % config.calendar.length];

  /// Claims today's reward and advances the streak. Returns the rewards, or
  /// an empty list when nothing can be claimed.
  List<R> claim(DailyState s, DateTime now, {bool hold = false}) {
    if (!canClaim(s, now, hold: hold)) return const [];
    final today = dayKey(now);
    final reward = nextReward(s);
    if (inWelcome(s)) {
      s.welcomeClaimed++;
    } else {
      s.calendarIndex++;
    }
    final continued =
        s.lastClaimDay.isNotEmpty && _gap(s.lastClaimDay, today) == 1;
    if (continued) {
      s.streak++;
    } else {
      s.streak = 1;
      s.milestonesClaimed.clear();
    }
    if (s.streak > s.bestStreak) s.bestStreak = s.streak;
    s.lastClaimDay = today;
    return reward;
  }

  /// Keeps a broken streak. Returns the currency to charge (0 for an ad), or
  /// null when there is nothing to save or [balance] is too low. The caller
  /// takes the currency (or shows the ad first).
  int? saveStreak(
    DailyState s,
    DateTime now, {
    StreakSaverPayment payment = StreakSaverPayment.currency,
    int balance = 0,
  }) {
    if (s.brokenStreak == 0) return null;
    final cost = payment == StreakSaverPayment.ad ? 0 : config.saverCost;
    if (balance < cost) return null;
    s.streak = s.brokenStreak;
    s.brokenStreak = 0;
    // Calendar yesterday from fields: subtracting 24 hours lands two days
    // back just after a spring forward midnight.
    s.lastClaimDay = yesterdayKey(now);
    return cost;
  }

  /// Lets the broken streak go. The next claim starts again at day 1.
  void declineSave(DailyState s) {
    s.brokenStreak = 0;
    s.streak = 0;
    s.milestonesClaimed.clear();
  }

  List<int> claimableMilestones(DailyState s) => milestonesUpTo(s.streak)
      .where((d) => !s.milestonesClaimed.contains(d))
      .toList();

  /// Claims milestone [day]. Returns its rewards, or empty when it is not
  /// claimable.
  List<R> claimMilestone(DailyState s, int day, {bool hold = false}) {
    if (hold || !claimableMilestones(s).contains(day)) return const [];
    s.milestonesClaimed.add(day);
    return config.milestoneReward(day);
  }

  /// Days between two keys, treating an unreadable key as "long ago".
  static int _gap(String from, String to) {
    if (tryParseDayKey(from) == null) return 1 << 20;
    return daysBetween(from, to);
  }
}
