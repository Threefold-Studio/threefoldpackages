/// The client side of `sync-progress` (SOP R15.14, R15.10, R9.12): sends the
/// progress snapshot plus the deltas since the last acknowledged sync, reads
/// the server time, and feeds it to the [GameClock] for skew detection.
library;

import 'dart:async';
import 'dart:convert';

import '../storage/key_value_store.dart';
import '../time/game_clock.dart';

/// How the server should treat this sync (the games' existing modes).
/// [sync] applies the device copy when it is newer; [fetch] only reads the
/// cloud copy; [overwrite] replaces the cloud copy (the player chose it).
enum SyncMode { sync, fetch, overwrite }

/// Sends one request body and returns the decoded JSON response, or null on
/// any failure (offline, error status). The kit never depends on Supabase;
/// see [FunctionSyncTransport] for the thin adapter.
abstract interface class SyncTransport {
  Future<Map<String, dynamic>?> send(Map<String, dynamic> body);
}

/// Adapts any "invoke a function by name" call, for example Supabase's
/// `client.functions.invoke`, without the kit importing Supabase:
///
/// ```dart
/// FunctionSyncTransport('sync-progress', (name, body) async =>
///     (await supabase.functions.invoke(name, body: body)).data);
/// ```
class FunctionSyncTransport implements SyncTransport {
  FunctionSyncTransport(this.functionName, this.invoke, {this.onError});

  final String functionName;
  final Future<Object?> Function(String name, Map<String, dynamic> body) invoke;
  final void Function(Object error, StackTrace stack)? onError;

  @override
  Future<Map<String, dynamic>?> send(Map<String, dynamic> body) async {
    try {
      final data = await invoke(functionName, body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String) {
        final d = jsonDecode(data);
        if (d is Map) return Map<String, dynamic>.from(d);
      }
    } catch (e, st) {
      onError?.call(e, st);
    }
    return null;
  }
}

/// A transport that never reaches a server (no keys, or offline builds).
class NoopSyncTransport implements SyncTransport {
  const NoopSyncTransport();
  @override
  Future<Map<String, dynamic>?> send(Map<String, dynamic> body) async => null;
}

/// What one [SyncClient.sync] call came back with.
class SyncResult {
  const SyncResult({
    required this.ok,
    this.progress,
    this.response,
    this.serverTime,
    this.skew,
    this.holdClaims = false,
  });

  static const failed = SyncResult(ok: false);

  /// The server answered.
  final bool ok;

  /// The server's merged progress (`response['progress']`), if any.
  final Map<String, dynamic>? progress;

  /// The whole response, for game-specific fields.
  final Map<String, dynamic>? response;

  final DateTime? serverTime;

  /// Server time minus device time, measured at the middle of the request.
  final Duration? skew;

  /// The phone clock is more than the clock's skew limit off: hold daily
  /// and pass claims and lives catch-up until it is fixed.
  final bool holdClaims;
}

/// Sends progress to the game's sync function.
///
/// Each call sends:
/// * `progress`: the full snapshot the game builds (unchanged from today).
/// * `counters`: running totals the server caps (levels, currency, XP,
///   boosters, whatever the game names), and `delta`: each counter minus
///   the value last acknowledged by the server. The server checks `delta`
///   against per call and rolling 24 hour caps.
/// * `results`, `mode`, and any `extra` fields.
///
/// The acknowledged counters are stored only after the server answers, so a
/// failed sync is simply sent again, with the larger delta, next time.
/// Overlapping calls share one request.
class SyncClient {
  SyncClient({
    required this.transport,
    required this.clock,
    KeyValueStore? store,
    this.ackKey = 'sync.acked',
  }) : _store = store;

  final SyncTransport transport;
  final GameClock clock;
  final KeyValueStore? _store;
  final String ackKey;

  Map<String, num>? _ackedCache;
  Future<SyncResult>? _inFlight;

  /// Raised by [resetAcknowledged]; a request started before a reset never
  /// acknowledges its counters.
  int _ackEpoch = 0;

  /// Counters the server has acknowledged.
  Map<String, num> get acknowledged {
    final cached = _ackedCache;
    if (cached != null) return Map.unmodifiable(cached);
    final raw = _store?.getString(ackKey);
    var out = <String, num>{};
    if (raw != null) {
      try {
        final m = jsonDecode(raw);
        if (m is Map) {
          out = {
            for (final e in m.entries)
              if (e.value is num) '${e.key}': e.value as num,
          };
        }
      } catch (_) {
        // A damaged record only means the next delta is the full total.
      }
    }
    _ackedCache = out;
    return Map.unmodifiable(out);
  }

  /// Each counter minus its acknowledged value. A counter that went down
  /// (spending) gives a negative delta.
  Map<String, num> deltaFor(Map<String, num> counters) {
    final acked = acknowledged;
    return {
      for (final e in counters.entries) e.key: e.value - (acked[e.key] ?? 0)
    };
  }

  /// True while a sync is running.
  bool get busy => _inFlight != null;

  Future<SyncResult> sync({
    required Map<String, dynamic> progress,
    Map<String, num> counters = const {},
    List<Map<String, dynamic>> results = const [],
    SyncMode mode = SyncMode.sync,
    Map<String, dynamic> extra = const {},
  }) {
    return _inFlight ??= _run(progress, counters, results, mode, extra)
        .whenComplete(() => _inFlight = null);
  }

  Future<SyncResult> _run(
    Map<String, dynamic> progress,
    Map<String, num> counters,
    List<Map<String, dynamic>> results,
    SyncMode mode,
    Map<String, dynamic> extra,
  ) async {
    final sent = Map<String, num>.of(counters);
    final epoch = _ackEpoch;
    final body = <String, dynamic>{
      ...extra,
      'progress': progress,
      'counters': sent,
      'delta': deltaFor(sent),
      'results': results,
      'mode': mode.name,
    };
    final t0 = clock.deviceNow();
    final res = await transport.send(body);
    if (res == null) return SyncResult.failed;
    final t1 = clock.deviceNow();
    final serverTime = parseServerTime(res['serverTime'] ?? res['server_time']);
    if (serverTime != null) {
      final mid = t0.add(t1.difference(t0) ~/ 2);
      clock.onServerTime(serverTime, deviceAt: mid);
    }
    // Fetch mode is read-only on the server, so the totals were not
    // applied and must still be sent as a delta next time.
    if (sent.isNotEmpty && mode != SyncMode.fetch && epoch == _ackEpoch) {
      await _ack(sent);
    }
    final p = res['progress'];
    return SyncResult(
      ok: true,
      progress: p is Map ? Map<String, dynamic>.from(p) : null,
      response: res,
      serverTime: serverTime,
      skew: serverTime == null ? null : clock.skew,
      holdClaims: clock.holdClaims,
    );
  }

  Future<void> _ack(Map<String, num> sent) async {
    final next = {...acknowledged, ...sent};
    _ackedCache = next;
    await _store?.setString(ackKey, jsonEncode(next));
  }

  /// Forgets the acknowledged counters (after sign in to another account or
  /// a progress reset), so the next delta is the full total.
  /// A request still waiting for its answer will not acknowledge afterwards.
  Future<void> resetAcknowledged() async {
    _ackEpoch++;
    _ackedCache = <String, num>{};
    await _store?.remove(ackKey);
  }
}
