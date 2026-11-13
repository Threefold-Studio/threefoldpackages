/// The small storage surface the kit needs. Games pass a
/// `SharedPreferencesKeyValueStore` (see `shared_preferences_store.dart`);
/// tests pass a [MemoryKeyValueStore].
library;

/// String key-value storage with synchronous reads and asynchronous writes,
/// the same shape as SharedPreferences.
abstract interface class KeyValueStore {
  /// The stored string for [key], or null when there is none.
  String? getString(String key);

  /// Stores [value] under [key].
  Future<void> setString(String key, String value);

  /// Removes [key]. Removing a missing key is not an error.
  Future<void> remove(String key);

  /// Every key currently stored.
  Set<String> get keys;
}

/// An in-memory [KeyValueStore] for tests and for running with no storage.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  /// A copy of everything stored, for assertions in tests.
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Set<String> get keys => _values.keys.toSet();
}
