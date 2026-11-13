import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

/// A stand-in for a game's PlayerState.fromJson: throws on a bad field.
class Player {
  Player(this.level, this.coins);
  final int level;
  final int coins;
  static Player fromJson(Map<String, dynamic> j) =>
      Player(j['level'] as int, j['coins'] as int);
  Map<String, dynamic> toJson() => {'level': level, 'coins': coins};
}

String fixture(String name) =>
    File('test/fixtures/saves/$name').readAsStringSync();

void main() {
  var ms = 1794500000000;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(ms++);

  SaveStore storeOf(MemoryKeyValueStore kv,
          {int schema = 1,
          Map<int, SaveMigration> migrations = const {},
          String? legacyKey}) =>
      SaveStore(kv, 'game.save',
          schema: schema,
          migrations: migrations,
          legacyKey: legacyKey,
          clock: clock);

  test('writes the envelope and reads it back', () async {
    final kv = MemoryKeyValueStore();
    final s = storeOf(kv);
    await s.write(Player(4, 10).toJson());
    final env = jsonDecode(kv.getString('game.save')!) as Map<String, dynamic>;
    expect(env['schema'], 1);
    expect(env['savedAt'], isA<int>());
    expect(env['data'], {'level': 4, 'coins': 10});

    final got = await storeOf(kv).load(Player.fromJson);
    expect(got.source, SaveSource.primary);
    expect(got.value!.level, 4);
    expect(got.savedAt, isNotNull);
    expect(got.recovered, isFalse);
  });

  test('nothing stored means a new player', () async {
    final got = await storeOf(MemoryKeyValueStore()).load(Player.fromJson);
    expect(got.source, SaveSource.none);
    expect(got.value, isNull);
  });

  test('the previous good save becomes the backup on each write', () async {
    final kv = MemoryKeyValueStore();
    final s = storeOf(kv);
    await s.write(Player(1, 0).toJson());
    expect(kv.getString('game.save.backup'), isNull);
    await s.write(Player(2, 0).toJson());
    await s.write(Player(3, 0).toJson());
    final backup = jsonDecode(kv.getString('game.save.backup')!) as Map;
    expect((backup['data'] as Map)['level'], 2);
  });

  test('unparseable save is quarantined and the backup is loaded', () async {
    final kv = MemoryKeyValueStore();
    final s = storeOf(kv);
    await s.write(Player(299, 50).toJson());
    await s.write(Player(300, 60).toJson());
    await kv.setString('game.save', '{"schema":1,"data":{"lev'); // torn write

    final errors = <Object>[];
    final s2 = storeOf(kv);
    final got =
        await s2.load(Player.fromJson, onError: (e, _) => errors.add(e));
    expect(got.source, SaveSource.backup);
    expect(got.value!.level, 299);
    expect(got.recovered, isTrue);
    expect(errors, hasLength(1));
    final q = s2.quarantinedKeys;
    expect(q, hasLength(1));
    expect(q.single, startsWith('game.save.corrupt.'));
    expect(kv.getString(q.single), '{"schema":1,"data":{"lev');

    // Writing next keeps the good backup, not the broken save.
    await s2.write(Player(299, 70).toJson());
    final backup = jsonDecode(kv.getString('game.save.backup')!) as Map;
    expect((backup['data'] as Map)['level'], 299);
    expect(kv.getString(q.single), isNotNull, reason: 'quarantine kept');
  });

  test('a bad field (decoder throws) is quarantined, not a new player',
      () async {
    final kv = MemoryKeyValueStore();
    final s = storeOf(kv);
    await s.write(Player(150, 5).toJson());
    await s.write({'level': 'oops', 'coins': 5});
    final got = await storeOf(kv).load(Player.fromJson);
    expect(got.source, SaveSource.backup);
    expect(got.value!.level, 150);
  });

  test('both saves broken: new player, both quarantined, no wipe', () async {
    final kv = MemoryKeyValueStore({
      'game.save': 'not json',
      'game.save.backup': '[1,2,3]',
    });
    final s = storeOf(kv);
    final got = await s.load(Player.fromJson);
    expect(got.source, SaveSource.none);
    expect(got.errors, hasLength(2));
    expect(s.quarantinedKeys.map(kv.getString),
        containsAll(['not json', '[1,2,3]']));
    await s.write(Player(1, 0).toJson());
    expect(kv.getString('game.save.backup'), isNull,
        reason: 'an unreadable save never becomes the backup');
  });

  test('writing before load() quarantines an unreadable save', () async {
    final kv = MemoryKeyValueStore({'game.save': '{broken'});
    final s = storeOf(kv);
    await s.write(Player(1, 0).toJson());
    expect(s.quarantinedKeys.map(kv.getString), ['{broken']);
    expect(kv.getString('game.save.backup'), isNull);
  });

  test('loading the same broken save twice quarantines it once', () async {
    final kv = MemoryKeyValueStore({'game.save': 'x'});
    await storeOf(kv).load(Player.fromJson);
    await storeOf(kv).load(Player.fromJson);
    expect(storeOf(kv).quarantinedKeys, hasLength(1));
  });

  test('quarantine keeps at most maxQuarantined copies, oldest dropped',
      () async {
    final kv = MemoryKeyValueStore();
    final s =
        SaveStore(kv, 'game.save', schema: 1, clock: clock, maxQuarantined: 2);
    for (final raw in ['a', 'b', 'c']) {
      await kv.setString('game.save', raw);
      await s.load(Player.fromJson);
    }
    expect(s.quarantinedKeys.map(kv.getString), ['b', 'c']);
  });

  test('a save from a newer app is kept and the backup is used', () async {
    final kv = MemoryKeyValueStore();
    final s = storeOf(kv);
    await s.write(Player(10, 0).toJson());
    await s.write(Player(11, 0).toJson());
    final newer = jsonEncode({
      'schema': 9,
      'savedAt': 1,
      'data': {'level': 99}
    });
    await kv.setString('game.save', newer);
    Object? err;
    final got =
        await storeOf(kv).load(Player.fromJson, onError: (e, _) => err = e);
    expect(err, isA<SaveFromNewerAppError>());
    expect(got.value!.level, 10);
    expect(storeOf(kv).quarantinedKeys.map(kv.getString), [newer]);
  });

  group('migrations', () {
    // Schema 1 -> 2: 'coins' renamed 'currency', 'editCount' kept apart.
    Map<String, dynamic> toV2(Map<String, dynamic> d) =>
        {...d, 'currency': d['coins']}..remove('coins');
    Player decodeV2(Map<String, dynamic> j) =>
        Player(j['level'] as int, j['currency'] as int);

    test('schema 1 fixture migrates to schema 2', () async {
      final kv = MemoryKeyValueStore({'game.save': fixture('schema_1.json')});
      final got =
          await storeOf(kv, schema: 2, migrations: {1: toV2}).load(decodeV2);
      expect(got.source, SaveSource.primary);
      expect(got.fromSchema, 1);
      expect(got.value!.coins, 4210);
      expect(got.value!.level, 312);
    });

    test('legacy pre-envelope fixture loads from the old key as schema 0',
        () async {
      final kv =
          MemoryKeyValueStore({'game.player.v1': fixture('legacy_v0.json')});
      final s = storeOf(kv,
          schema: 2,
          migrations: {
            0: (d) => {...d, 'editCount': d['version']}..remove('version'),
            1: toV2,
          },
          legacyKey: 'game.player.v1');
      final got = await s.load((j) {
        expect(j['editCount'], 918);
        expect(j.containsKey('version'), isFalse);
        return decodeV2(j);
      });
      expect(got.source, SaveSource.legacy);
      expect(got.fromSchema, 0);
      expect(got.value!.level, 312);

      await s.write({'level': 312, 'currency': 4210});
      expect(kv.getString('game.player.v1'), fixture('legacy_v0.json'),
          reason: 'the legacy key is never deleted');
      final again =
          await storeOf(kv, schema: 2, migrations: {1: toV2}).load(decodeV2);
      expect(again.source, SaveSource.primary);
    });

    test('a bare save under the new key is read as schema 0', () async {
      final kv = MemoryKeyValueStore({'game.save': '{"level":3,"coins":1}'});
      final got = await storeOf(kv).load(Player.fromJson);
      expect(got.fromSchema, 0);
      expect(got.value!.level, 3);
    });

    test('a migration that throws sends the save to quarantine', () async {
      final kv = MemoryKeyValueStore({'game.save': fixture('schema_1.json')});
      final s = storeOf(kv,
          schema: 2, migrations: {1: (_) => throw StateError('bad')});
      final got = await s.load(decodeV2);
      expect(got.source, SaveSource.none);
      expect(s.quarantinedKeys, hasLength(1));
    });
  });

  test('clear removes the save and backup but keeps quarantine', () async {
    final kv = MemoryKeyValueStore({'game.save': 'x'});
    final s = storeOf(kv);
    await s.load(Player.fromJson);
    await s.write(Player(1, 0).toJson());
    await s.write(Player(2, 0).toJson());
    await s.clear();
    expect(kv.getString('game.save'), isNull);
    expect(kv.getString('game.save.backup'), isNull);
    expect(s.quarantinedKeys, hasLength(1));
  });

  test(
    'writing before load() keeps a readable backup when the main is bad',
    () async {
      final good = jsonEncode({
        'schema': 1,
        'savedAt': 1,
        'data': {'level': 9, 'coins': 1},
      });
      final kv = MemoryKeyValueStore({
        'game.save': '{broken',
        'game.save.backup': good,
      });
      final s = storeOf(kv);
      await s.write(Player(10, 0).toJson());
      expect(
        kv.getString('game.save.backup'),
        good,
        reason: 'the readable backup is never thrown away',
      );
      expect(s.quarantinedKeys.map(kv.getString), ['{broken']);
    },
  );

  test('writing before load() quarantines an unreadable backup too', () async {
    final kv = MemoryKeyValueStore({'game.save.backup': 'nope'});
    final s = storeOf(kv);
    await s.write(Player(1, 0).toJson());
    expect(s.quarantinedKeys.map(kv.getString), ['nope']);
    expect(kv.getString('game.save.backup'), isNull);
  });

  test(
    'clear also removes the legacy save, so reset starts a new player',
    () async {
      final kv = MemoryKeyValueStore({
        'game.player.v1': fixture('legacy_v0.json'),
      });
      final s = storeOf(kv, legacyKey: 'game.player.v1');
      expect((await s.load(Player.fromJson)).source, SaveSource.legacy);
      await s.clear();
      final again = await storeOf(
        kv,
        legacyKey: 'game.player.v1',
      ).load(Player.fromJson);
      expect(again.source, SaveSource.none);
    },
  );
}
