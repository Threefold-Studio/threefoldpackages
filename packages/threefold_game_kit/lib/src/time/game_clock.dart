/// The game's one clock (SOP R15.8, R15.10, R9.3, R9.12 and R5.7).
library;

import 'dart:async';

import '../storage/key_value_store.dart';

/// The single source of "now" for every timer in a game: lives, unlimited
/// lives windows, daily claims, streaks and the season pass.
///
/// `now()` is built in three layers:
///
/// 1. The device clock ([source], injectable for tests).
/// 2. The server offset learnt from the last bootstrap or sync
///    ([onServerTime]), so a phone clock set wrong does not move timers.
/// 3. A rollback guard: when the result is more than [rollbackTolerance]
///    behind the latest time already seen, the latest time seen is used
///    instead, so winding the phone clock back cannot freeze or replay
///    anything.
///
/// On top of that sits the dev time travel offset ([advanceForDev]), which
/// only works when [devTools] is true and is never stored.
///
/// The SOP calls this `TrustedClock`; [TrustedClock] is an alias.
class GameClock {
  GameClock({
    DateTime Function()? source,
    KeyValueStore? store,
    String keyPrefix = 'clock',
    this.devTools = false,
    this.skewLimit = const Duration(hours: 2),
    this.rollbackTolerance = const Duration(minutes: 10),
  })  : _source = source ?? DateTime.now,
        _store = store,
        _offsetKey = '$keyPrefix.offsetMs',
        _lastSeenKey = '$keyPrefix.lastSeenMs',
        _skewKey = '$keyPrefix.skewMs' {
    final s = _store;
    if (s != null) {
      _offsetMs = int.tryParse(s.getString(_offsetKey) ?? '') ?? 0;
      _lastSeenMs = int.tryParse(s.getString(_lastSeenKey) ?? '') ?? 0;
      _persistedLastSeenMs = _lastSeenMs;
      _skewMs = int.tryParse(s.getString(_skewKey) ?? '');
    }
  }

  final DateTime Function() _source;
  final KeyValueStore? _store;
  final String _offsetKey;
  final String _lastSeenKey;
  final String _skewKey;

  /// Whether dev time travel is allowed. Pass the game's `Env.devTools`.
  final bool devTools;

  /// Above this server skew, claims and refill catch-up are held (R9.12).
  final Duration skewLimit;

  /// How far the clock may step back before the rollback guard holds it.
  final Duration rollbackTolerance;

  int _offsetMs = 0;
  int _lastSeenMs = 0;
  int _persistedLastSeenMs = 0;
  int? _skewMs;
  Duration _devOffset = Duration.zero;

  /// How often the latest seen time is written to storage, at most.
  static const _persistEvery = 60 * 1000;

  /// The raw device time, with no correction. For measuring round trips.
  DateTime deviceNow() => _source();

  /// The trusted time every game timer should read, as a local DateTime.
  DateTime now() {
    var ms = _source().millisecondsSinceEpoch + _offsetMs;
    if (ms < _lastSeenMs - rollbackTolerance.inMilliseconds) {
      ms = _lastSeenMs; // the clock was pushed back: hold
    }
    if (ms > _lastSeenMs) {
      _lastSeenMs = ms;
      if (ms - _persistedLastSeenMs >= _persistEvery) _persistLastSeen();
    }
    return DateTime.fromMillisecondsSinceEpoch(
        ms + (devTools ? _devOffset.inMilliseconds : 0));
  }

  /// [now] in epoch milliseconds.
  int nowMs() => now().millisecondsSinceEpoch;

  /// Records the server's time from a bootstrap or sync response.
  ///
  /// [deviceAt] is the device time the server time belongs to; pass the
  /// midpoint of the request when you have it (the [SyncClient] does).
  /// Sets the server offset, records the skew, and resets the rollback
  /// guard to the server's time, because the server is the truth.
  void onServerTime(DateTime server, {DateTime? deviceAt}) {
    final device = (deviceAt ?? _source()).millisecondsSinceEpoch;
    final serverMs = server.millisecondsSinceEpoch;
    _offsetMs = serverMs - device;
    _skewMs = _offsetMs;
    _lastSeenMs = serverMs + (_source().millisecondsSinceEpoch - device);
    final s = _store;
    if (s != null) {
      unawaited(s.setString(_offsetKey, '$_offsetMs'));
      unawaited(s.setString(_skewKey, '$_skewMs'));
    }
    _persistLastSeen();
  }

  /// Server time minus device time at the last server contact, or null if
  /// the server has never been reached.
  Duration? get skew =>
      _skewMs == null ? null : Duration(milliseconds: _skewMs!);

  /// True when the last server contact found the phone clock off by more
  /// than [skewLimit]. While true, refuse daily claims, pass claims and
  /// lives refill catch-up (SOP R9.12).
  bool get holdClaims {
    final s = _skewMs;
    return s != null && s.abs() > skewLimit.inMilliseconds;
  }

  /// DEV-ONLY: the current time travel offset.
  Duration get devOffset => devTools ? _devOffset : Duration.zero;

  /// DEV-ONLY: moves the game clock forward (or back) by [by]. Ignored
  /// unless [devTools] is true. Never changes the phone clock.
  void advanceForDev(Duration by) {
    if (devTools) _devOffset += by;
  }

  /// DEV-ONLY: removes the time travel offset.
  void resetDevOffsetForDev() => _devOffset = Duration.zero;

  void _persistLastSeen() {
    _persistedLastSeenMs = _lastSeenMs;
    final s = _store;
    if (s != null) unawaited(s.setString(_lastSeenKey, '$_lastSeenMs'));
  }
}

/// The SOP's name for [GameClock] (R15.10).
typedef TrustedClock = GameClock;

/// Reads a server time sent as an ISO 8601 string or as epoch milliseconds.
/// Returns null for anything else.
DateTime? parseServerTime(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  return null;
}
