/// The versioned save with a backup and a quarantine (SOP R15.9).
library;

import 'dart:convert';

import '../storage/key_value_store.dart';

/// Turns save data of one schema into the next schema.
typedef SaveMigration = Map<String, dynamic> Function(Map<String, dynamic>);

/// Where a [SaveLoad] came from.
enum SaveSource {
  /// The main save loaded cleanly.
  primary,

  /// The main save was unreadable, so the last good save was used.
  backup,

  /// Only an old pre-envelope save under [SaveStore.legacyKey] was found.
  legacy,

  /// There was no readable save at all: start a new player.
  none,
}

/// The result of [SaveStore.load].
class SaveLoad<T> {
  const SaveLoad(this.value, this.source,
      {this.fromSchema, this.savedAt, this.errors = const []});

  /// The decoded save, or null when [source] is [SaveSource.none].
  final T? value;
  final SaveSource source;

  /// The schema the save was written with, before migrations ran.
  final int? fromSchema;

  /// When the loaded save was written (null for legacy saves).
  final DateTime? savedAt;

  /// Every problem met on the way, oldest first. Non-empty means something
  /// was quarantined: log it.
  final List<Object> errors;

  /// True when a save existed but could not be read (it was quarantined).
  bool get recovered => errors.isNotEmpty;
}

/// Thrown when a save was written by a newer app than this one.
class SaveFromNewerAppError extends StateError {
  SaveFromNewerAppError(this.schema, this.supported)
      : super('save schema $schema is newer than supported $supported');
  final int schema;
  final int supported;
}

/// One JSON save document wrapped as
/// `{"schema": N, "savedAt": ms, "data": {...}}`.
///
/// On load it parses, runs `migrations[from]`, `migrations[from + 1]` and so
/// on up to [schema], then hands the data to the game's decoder. If any of
/// that throws, the raw string is kept under `<key>.corrupt.<ms>` and the
/// backup (`<key>.backup`, the last save that loaded cleanly) is tried. A
/// save that failed to read is never overwritten without being kept.
///
/// Keep the game's sync edit counter inside `data`; it is not [schema].
class SaveStore {
  SaveStore(
    this.store,
    this.key, {
    required this.schema,
    this.migrations = const {},
    this.legacyKey,
    DateTime Function()? clock,
    this.maxQuarantined = 5,
  })  : assert(schema >= 1, 'schema starts at 1; 0 means pre-envelope'),
        assert(
            List.generate(schema - 1, (i) => i + 1)
                .every(migrations.containsKey),
            'every schema from 1 to schema - 1 needs a migration'),
        _clock = clock ?? DateTime.now;

  final KeyValueStore store;

  /// For example 'mygame.save'.
  final String key;

  /// The schema this build writes.
  final int schema;

  /// `migrations[n]` turns schema n data into schema n + 1. Schema 0 is a
  /// bare, pre-envelope save; without `migrations[0]` it is used as is.
  final Map<int, SaveMigration> migrations;

  /// The old pre-envelope key (for example 'mygame.player.v1'), read only
  /// when [key] and its backup hold nothing. Only [clear] deletes it.
  final String? legacyKey;

  /// Oldest quarantined copies beyond this are removed.
  final int maxQuarantined;

  final DateTime Function() _clock;

  /// The raw string of the last save known to be readable, which becomes
  /// the backup on the next write.
  String? _lastGood;
  bool _lastGoodKnown = false;

  String get backupKey => '$key.backup';
  String get _corruptPrefix => '$key.corrupt.';

  /// Every quarantined copy key, oldest first.
  List<String> get quarantinedKeys {
    final out = store.keys.where((k) => k.startsWith(_corruptPrefix)).toList()
      ..sort((a, b) {
        final x = _suffix(a), y = _suffix(b);
        return x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2);
      });
    return out;
  }

  (int, int) _suffix(String k) {
    final parts = k.substring(_corruptPrefix.length).split('.');
    return (
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  /// Loads the save. [decode] turns migrated data into the game's state and
  /// should throw on anything it cannot use (a cast error is enough), so a
  /// bad field sends the save to quarantine instead of becoming a new
  /// player. [onError] is called for every failure, for logging.
  Future<SaveLoad<T>> load<T>(
    T Function(Map<String, dynamic> data) decode, {
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    final errors = <Object>[];
    for (final (k, source) in [
      (key, SaveSource.primary),
      (backupKey, SaveSource.backup),
    ]) {
      final raw = store.getString(k);
      if (raw == null) continue;
      try {
        final (data, from, savedAt) = _open(raw);
        final value = decode(data);
        _lastGood = raw;
        _lastGoodKnown = true;
        return SaveLoad(value, source,
            fromSchema: from, savedAt: savedAt, errors: errors);
      } catch (e, st) {
        errors.add(e);
        onError?.call(e, st);
        await _quarantine(raw);
      }
    }
    final lk = legacyKey;
    final legacyRaw = lk == null ? null : store.getString(lk);
    if (legacyRaw != null) {
      try {
        final (data, from, _) = _open(legacyRaw, legacy: true);
        final value = decode(data);
        _lastGoodKnown = true; // nothing under [key] worth backing up
        return SaveLoad(value, SaveSource.legacy,
            fromSchema: from, errors: errors);
      } catch (e, st) {
        errors.add(e);
        onError?.call(e, st);
        await _quarantine(legacyRaw);
      }
    }
    _lastGoodKnown = true;
    return SaveLoad<T>(null, SaveSource.none, errors: errors);
  }

  /// Writes [data] as the current save. The previous save becomes the
  /// backup only if it was readable; an unreadable one is quarantined first.
  Future<void> write(Map<String, dynamic> data) async {
    if (!_lastGoodKnown) {
      // Writing before load(): look at what is there now.
      // The main save if readable, else the backup if readable; anything
      // unreadable is quarantined, so nothing is lost either way.
      for (final k in [key, backupKey]) {
        final current = store.getString(k);
        if (current == null) continue;
        if (_readable(current)) {
          _lastGood = current;
          break;
        }
        await _quarantine(current);
      }
      _lastGoodKnown = true;
    }
    final good = _lastGood;
    if (good != null) {
      await store.setString(backupKey, good);
    } else if (store.getString(backupKey) != null) {
      // Only an unreadable backup can be here, and it is already kept in
      // quarantine.
      await store.remove(backupKey);
    }
    final raw = jsonEncode({
      'schema': schema,
      'savedAt': _clock().millisecondsSinceEpoch,
      'data': data,
    });
    await store.setString(key, raw);
    _lastGood = raw;
  }

  /// Removes the save, its backup and the legacy save (for "Reset
  /// progress"), so a later load starts a new player. Quarantined copies
  /// stay.
  Future<void> clear() async {
    await store.remove(key);
    await store.remove(backupKey);
    final lk = legacyKey;
    if (lk != null) await store.remove(lk);
    _lastGood = null;
    _lastGoodKnown = true;
  }

  bool _readable(String raw) {
    try {
      _open(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  (Map<String, dynamic>, int, DateTime?) _open(String raw,
      {bool legacy = false}) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('save is not an object');
    final env = Map<String, dynamic>.from(decoded);
    final enveloped = !legacy && env['schema'] is int && env['data'] is Map;
    var from = enveloped ? env['schema'] as int : 0;
    var data = enveloped ? Map<String, dynamic>.from(env['data'] as Map) : env;
    final savedAtMs = enveloped ? env['savedAt'] : null;
    if (from > schema) throw SaveFromNewerAppError(from, schema);
    while (from < schema) {
      final m = migrations[from];
      if (m != null) {
        data = m(data);
      } else if (from != 0) {
        throw StateError('no migration from schema $from');
      }
      from++;
    }
    return (
      data,
      enveloped ? env['schema'] as int : 0,
      savedAtMs is int ? DateTime.fromMillisecondsSinceEpoch(savedAtMs) : null,
    );
  }

  Future<void> _quarantine(String raw) async {
    final existing = quarantinedKeys;
    for (final k in existing) {
      if (store.getString(k) == raw) return; // already kept
    }
    final ms = _clock().millisecondsSinceEpoch;
    var k = '$_corruptPrefix$ms';
    var n = 1;
    while (store.getString(k) != null) {
      k = '$_corruptPrefix$ms.${n++}';
    }
    await store.setString(k, raw);
    final all = quarantinedKeys;
    for (var i = 0; i < all.length - maxQuarantined; i++) {
      await store.remove(all[i]);
    }
  }
}
