import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

class FakeTransport implements SyncTransport {
  FakeTransport(this.reply, {this.onSend});
  Map<String, dynamic>? Function(Map<String, dynamic> body) reply;
  final void Function()? onSend;
  final bodies = <Map<String, dynamic>>[];
  Completer<void>? gate;

  @override
  Future<Map<String, dynamic>?> send(Map<String, dynamic> body) async {
    bodies.add(body);
    onSend?.call();
    if (gate != null) await gate!.future;
    return reply(body);
  }
}

void main() {
  late DateTime device;
  late GameClock clock;
  setUp(() {
    device = DateTime.utc(2026, 11, 13, 15);
    clock = GameClock(source: () => device);
  });

  test('sends progress, counters, deltas, results and mode', () async {
    final t = FakeTransport((_) => {
          'progress': {'level': 5}
        });
    final c =
        SyncClient(transport: t, clock: clock, store: MemoryKeyValueStore());
    final r = await c.sync(
      progress: {'level': 5},
      counters: {'level': 5, 'coins': 300},
      results: [
        {'level': 4, 'won': true}
      ],
      mode: SyncMode.overwrite,
      extra: {'previous_token': 'abc'},
    );
    expect(r.ok, isTrue);
    expect(r.progress, {'level': 5});
    final b = t.bodies.single;
    expect(b['mode'], 'overwrite');
    expect(b['previous_token'], 'abc');
    expect(b['delta'], {'level': 5, 'coins': 300});
    expect(b['counters'], {'level': 5, 'coins': 300});
    expect(b['results'], hasLength(1));
  });

  test('deltas count from the last acknowledged sync, even after restart',
      () async {
    final store = MemoryKeyValueStore();
    final t = FakeTransport((_) => {});
    await SyncClient(transport: t, clock: clock, store: store)
        .sync(progress: {}, counters: {'level': 10, 'coins': 500});
    final c2 = SyncClient(transport: t, clock: clock, store: store);
    expect(c2.acknowledged, {'level': 10, 'coins': 500});
    await c2
        .sync(progress: {}, counters: {'level': 12, 'coins': 450, 'xp': 30});
    expect(t.bodies.last['delta'], {'level': 2, 'coins': -50, 'xp': 30});
  });

  test('a failed sync is not acknowledged, so the next delta includes it',
      () async {
    var online = false;
    final t = FakeTransport((_) => online ? {} : null);
    final c =
        SyncClient(transport: t, clock: clock, store: MemoryKeyValueStore());
    final r = await c.sync(progress: {}, counters: {'level': 3});
    expect(r.ok, isFalse);
    expect(c.acknowledged, isEmpty);
    online = true;
    await c.sync(progress: {}, counters: {'level': 7});
    expect(t.bodies.last['delta'], {'level': 7});
    expect(c.acknowledged, {'level': 7});
    await c.resetAcknowledged();
    expect(c.deltaFor({'level': 7}), {'level': 7});
  });

  test('server time sets the clock; skew over 2 hours holds claims', () async {
    final t = FakeTransport((_) => {
          'serverTime': device.add(const Duration(hours: 3)).toIso8601String(),
        });
    final c = SyncClient(transport: t, clock: clock);
    final r = await c.sync(progress: {});
    expect(r.serverTime, isNotNull);
    expect(r.skew, const Duration(hours: 3));
    expect(r.holdClaims, isTrue);
    expect(clock.holdClaims, isTrue);
    expect(clock.now().isAtSameMomentAs(device.add(const Duration(hours: 3))),
        isTrue);
  });

  test('small skew does not hold; round trip midpoint is used', () async {
    final t = FakeTransport(
      (_) => {
        'server_time':
            DateTime.utc(2026, 11, 13, 15, 0, 1).millisecondsSinceEpoch
      },
      onSend: () => device = device.add(const Duration(seconds: 2)),
    );
    final r = await SyncClient(transport: t, clock: clock).sync(progress: {});
    expect(r.holdClaims, isFalse);
    // Sent at 15:00:00, answered at 15:00:02: the server's 15:00:01 is no skew.
    expect(r.skew, Duration.zero);
  });

  test('no server time leaves the clock alone', () async {
    final r =
        await SyncClient(transport: FakeTransport((_) => {}), clock: clock)
            .sync(progress: {});
    expect(r.ok, isTrue);
    expect(r.serverTime, isNull);
    expect(r.skew, isNull);
    expect(clock.skew, isNull);
  });

  test('overlapping calls share one request', () async {
    final t = FakeTransport((_) => {})..gate = Completer<void>();
    final c = SyncClient(transport: t, clock: clock);
    final a = c.sync(progress: {'n': 1});
    final b = c.sync(progress: {'n': 2});
    expect(c.busy, isTrue);
    t.gate!.complete();
    expect(identical(await a, await b), isTrue);
    expect(t.bodies, hasLength(1));
    expect(c.busy, isFalse);
  });

  group('FunctionSyncTransport', () {
    test('passes the name and body, accepts map or JSON string', () async {
      String? name;
      final t = FunctionSyncTransport('sync-progress', (n, body) async {
        name = n;
        return '{"ok":true}';
      });
      expect(await t.send({'a': 1}), {'ok': true});
      expect(name, 'sync-progress');
      final m = FunctionSyncTransport('f', (_, __) async => {'x': 1});
      expect(await m.send({}), {'x': 1});
    });

    test('errors and odd replies come back as null', () async {
      Object? seen;
      final t = FunctionSyncTransport('f', (_, __) async => throw 'offline',
          onError: (e, _) => seen = e);
      expect(await t.send({}), isNull);
      expect(seen, 'offline');
      expect(await FunctionSyncTransport('f', (_, __) async => 42).send({}),
          isNull);
      expect(await const NoopSyncTransport().send({}), isNull);
    });
  });

  test('a fetch is read only, so its counters are not acknowledged', () async {
    final t = FakeTransport((_) => {});
    final c = SyncClient(
      transport: t,
      clock: clock,
      store: MemoryKeyValueStore(),
    );
    await c.sync(progress: {}, counters: {'coins': 200}, mode: SyncMode.fetch);
    expect(c.acknowledged, isEmpty);
    await c.sync(progress: {}, counters: {'coins': 200});
    expect(t.bodies.last['delta'], {'coins': 200});
    expect(c.acknowledged, {'coins': 200});
  });

  test('a reset during a sync is not undone when that sync answers',
      () async {
    final t = FakeTransport((_) => {})..gate = Completer<void>();
    final c =
        SyncClient(transport: t, clock: clock, store: MemoryKeyValueStore());
    final pending = c.sync(progress: {}, counters: {'level': 100});
    await c.resetAcknowledged();
    t.gate!.complete();
    expect((await pending).ok, isTrue);
    expect(c.acknowledged, isEmpty);
    expect(c.deltaFor({'level': 5}), {'level': 5});
  });
}
