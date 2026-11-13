/// Regenerating lives: hearts, apples, lollipops (SOP R15.11).
library;

/// The game's numbers for its lives. Names and copy stay in the game.
class LivesConfig {
  const LivesConfig({
    this.max = 5,
    this.refill = const Duration(minutes: 15),
    int? cap,
  })  : cap = cap ?? max * 2,
        assert(max > 0);

  /// Lives the timer refills up to.
  final int max;

  /// Time for one life to come back.
  final Duration refill;

  /// Hard ceiling when rewards add lives above [max].
  final int cap;
}

/// The stored lives fields. JSON keys are the game's choice; [fromJson]
/// accepts custom names so an existing save keeps its keys.
class LivesState {
  LivesState(
      {required this.lives,
      required this.updatedAtMs,
      this.unlimitedUntilMs = 0});

  /// Full lives as of [nowMs].
  factory LivesState.full(LivesConfig config, int nowMs) =>
      LivesState(lives: config.max, updatedAtMs: nowMs);

  int lives;

  /// When the refill timer last counted from, epoch ms.
  int updatedAtMs;

  /// Lives are unlimited until this epoch ms (0 = not unlimited).
  int unlimitedUntilMs;

  Map<String, dynamic> toJson({
    String livesKey = 'lives',
    String updatedKey = 'livesUpdatedAt',
    String unlimitedKey = 'infiniteUntil',
  }) =>
      {
        livesKey: lives,
        updatedKey: updatedAtMs,
        unlimitedKey: unlimitedUntilMs
      };

  factory LivesState.fromJson(
    Map<String, dynamic> j, {
    required LivesConfig config,
    required int nowMs,
    String livesKey = 'lives',
    String updatedKey = 'livesUpdatedAt',
    String unlimitedKey = 'infiniteUntil',
  }) =>
      LivesState(
        lives: (j[livesKey] as num?)?.toInt() ?? config.max,
        updatedAtMs: (j[updatedKey] as num?)?.toInt() ?? nowMs,
        unlimitedUntilMs: (j[unlimitedKey] as num?)?.toInt() ?? 0,
      );
}

/// Pure lives rules. Every method takes the time, so tests and dev time
/// travel drive it directly. Pass `GameClock.nowMs()`.
class Lives {
  const Lives(this.config);

  final LivesConfig config;

  int get _refillMs => config.refill.inMilliseconds;

  bool isUnlimited(LivesState s, int nowMs) => s.unlimitedUntilMs > nowMs;

  Duration unlimitedRemaining(LivesState s, int nowMs) => Duration(
      milliseconds: isUnlimited(s, nowMs) ? s.unlimitedUntilMs - nowMs : 0);

  bool canPlay(LivesState s, int nowMs) => isUnlimited(s, nowMs) || s.lives > 0;

  /// Brings [s] up to date: adds every life earned since the timer last
  /// counted. Returns the lives gained.
  ///
  /// A timer stamp in the future (the clock was wound back) is clamped to
  /// now, so lives never freeze. With [hold] true (server skew, see
  /// `GameClock.holdClaims`) no catch-up is granted.
  int refill(LivesState s, int nowMs, {bool hold = false}) {
    if (s.updatedAtMs > nowMs) s.updatedAtMs = nowMs;
    if (s.lives >= config.max) {
      s.updatedAtMs = nowMs;
      return 0;
    }
    if (hold) return 0;
    final gained = (nowMs - s.updatedAtMs) ~/ _refillMs;
    if (gained <= 0) return 0;
    final before = s.lives;
    s.lives = (s.lives + gained).clamp(0, config.max);
    s.updatedAtMs += gained * _refillMs;
    if (s.lives >= config.max) s.updatedAtMs = nowMs;
    return s.lives - before;
  }

  /// Time until the next life, or zero when full.
  Duration nextLifeIn(LivesState s, int nowMs) {
    if (s.lives >= config.max) return Duration.zero;
    final elapsed = nowMs - s.updatedAtMs;
    return Duration(milliseconds: (_refillMs - elapsed).clamp(0, _refillMs));
  }

  /// When lives will be full again, or null if they are (for the "lives
  /// full" reminder).
  DateTime? fullAt(LivesState s, int nowMs) {
    if (s.lives >= config.max) return null;
    final missing = config.max - s.lives;
    return DateTime.fromMillisecondsSinceEpoch(nowMs +
        nextLifeIn(s, nowMs).inMilliseconds +
        (missing - 1) * _refillMs);
  }

  /// Spends one life (a lost or abandoned level). Returns false when none
  /// was spent: unlimited lives are on, or there were none.
  bool lose(LivesState s, int nowMs, {bool hold = false}) {
    if (isUnlimited(s, nowMs)) return false;
    refill(s, nowMs, hold: hold);
    if (s.lives <= 0) return false;
    // Losing from full starts the timer now, not from an old stamp.
    if (s.lives >= config.max) s.updatedAtMs = nowMs;
    s.lives -= 1;
    return true;
  }

  /// Adds [n] lives (ads, rewards), up to [LivesConfig.cap].
  void add(LivesState s, int n, int nowMs) {
    refill(s, nowMs);
    s.lives = (s.lives + n).clamp(0, config.cap);
    if (s.lives >= config.max) s.updatedAtMs = nowMs;
  }

  /// Sets lives back to full (a paid refill).
  void fill(LivesState s, int nowMs) {
    s.lives = s.lives > config.max ? s.lives : config.max;
    s.updatedAtMs = nowMs;
  }

  /// Extends the unlimited window by [d], stacking on time already left.
  void grantUnlimited(LivesState s, Duration d, int nowMs) {
    final base = isUnlimited(s, nowMs) ? s.unlimitedUntilMs : nowMs;
    s.unlimitedUntilMs = base + d.inMilliseconds;
  }
}
