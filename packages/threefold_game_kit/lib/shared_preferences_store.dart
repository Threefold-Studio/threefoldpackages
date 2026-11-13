/// The SharedPreferences adapter for [KeyValueStore]. Kept in its own library
/// so the rest of the kit stays pure Dart.
///
/// ```dart
/// import 'package:threefold_game_kit/shared_preferences_store.dart';
/// final store = await SharedPreferencesKeyValueStore.create();
/// ```
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'src/storage/key_value_store.dart';

export 'src/storage/key_value_store.dart';

/// [KeyValueStore] backed by the platform's SharedPreferences.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore(this.prefs);

  /// Loads the platform SharedPreferences and wraps it.
  static Future<SharedPreferencesKeyValueStore> create() async =>
      SharedPreferencesKeyValueStore(await SharedPreferences.getInstance());

  final SharedPreferences prefs;

  @override
  String? getString(String key) {
    // A key written by older code as a non-string reads as missing rather
    // than throwing.
    final v = prefs.get(key);
    return v is String ? v : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await prefs.remove(key);
  }

  @override
  Set<String> get keys => prefs.getKeys();
}
