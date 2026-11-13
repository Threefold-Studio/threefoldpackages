import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The core stays pure Dart: only the SharedPreferences adapter may import a
/// Flutter or plugin package.
void main() {
  test('no Flutter or plugin imports outside the adapter', () {
    final bad = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('shared_preferences_store.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        if (RegExp(
                r'''^(import|export) 'package:(flutter|flame|shared_preferences|supabase)''')
            .hasMatch(line)) {
          bad.add('${f.path}: $line');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('no DateTime.now() call outside the clock defaults', () {
    final bad = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final src = f.readAsStringSync();
      if (RegExp(r'DateTime\.now\(\)').hasMatch(src)) bad.add(f.path);
    }
    expect(bad, isEmpty, reason: 'defaults use the DateTime.now tear-off only');
  });
}
