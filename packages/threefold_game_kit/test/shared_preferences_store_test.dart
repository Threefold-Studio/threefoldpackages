import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threefold_game_kit/shared_preferences_store.dart';
import 'package:threefold_game_kit/threefold_game_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads, writes, removes and lists keys', () async {
    SharedPreferences.setMockInitialValues({'old.int': 3, 'a': 'x'});
    final s = await SharedPreferencesKeyValueStore.create();
    expect(s.getString('a'), 'x');
    expect(s.getString('old.int'), isNull,
        reason: 'non-string reads as missing');
    await s.setString('b', 'y');
    expect(s.getString('b'), 'y');
    expect(s.keys, containsAll(['a', 'b', 'old.int']));
    await s.remove('a');
    expect(s.getString('a'), isNull);
  });

  test('a SaveStore on SharedPreferences recovers from a torn save', () async {
    SharedPreferences.setMockInitialValues({});
    final kv = await SharedPreferencesKeyValueStore.create();
    final save = SaveStore(kv, 'game.save', schema: 1);
    await save.write({'level': 1});
    await save.write({'level': 2});
    await kv.setString('game.save', '{');
    final got = await SaveStore(kv, 'game.save', schema: 1)
        .load((j) => j['level'] as int);
    expect(got.value, 1);
    expect(got.source, SaveSource.backup);
  });
}
