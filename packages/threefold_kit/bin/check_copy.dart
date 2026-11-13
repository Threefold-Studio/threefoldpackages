import 'dart:io';

import 'package:threefold_kit/threefold_kit.dart';

/// Scans the string literals of Dart files for dashes (SOP R10.11).
///
///   dart run threefold_kit:check_copy lib
///   dart run threefold_kit:check_copy --website lib/site_copy.dart
///
/// Arguments are files or directories. Directories are searched for `.dart`
/// files, skipping `*_test.dart`, generated `*.g.dart` / `*.freezed.dart`,
/// and `build/` and `.dart_tool/` folders. Comments are ignored; a line
/// holding `copy-check: ignore` is skipped.
///
/// Exit codes: 0 clean, 1 dashes found, 64 usage error.
void main(List<String> args) {
  var rules = CopyRules.app;
  final paths = <String>[];
  for (final a in args) {
    if (a == '--website') {
      rules = CopyRules.website;
    } else if (a == '-h' || a == '--help') {
      stdout.writeln(_usage);
      return;
    } else if (a.startsWith('-')) {
      stderr.writeln('Unknown option $a\n$_usage');
      exitCode = 64;
      return;
    } else {
      paths.add(a);
    }
  }
  if (paths.isEmpty) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final files = <File>[];
  for (final p in paths) {
    final type = FileSystemEntity.typeSync(p);
    if (type == FileSystemEntityType.file) {
      files.add(File(p));
    } else if (type == FileSystemEntityType.directory) {
      files.addAll(_dartFilesIn(Directory(p)));
    } else {
      stderr.writeln('Not found: $p');
      exitCode = 64;
      return;
    }
  }

  var hits = 0;
  for (final f in files) {
    for (final issue
        in findDashesInDartSource(f.readAsStringSync(), rules: rules)) {
      stdout.writeln('${f.path}:$issue');
      hits++;
    }
  }
  if (hits > 0) {
    stdout.writeln('$hits dash${hits == 1 ? '' : 'es'} in shipped text '
        '(use a comma, colon, period or "to").');
    exitCode = 1;
  } else {
    stdout.writeln('OK    copy check (${files.length} files)');
  }
}

Iterable<File> _dartFilesIn(Directory dir) sync* {
  final entries = dir.listSync(recursive: true, followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final e in entries) {
    if (e is! File) continue;
    final p = e.path.replaceAll(r'\', '/');
    if (!p.endsWith('.dart')) continue;
    if (p.endsWith('_test.dart') ||
        p.endsWith('.g.dart') ||
        p.endsWith('.freezed.dart')) {
      continue;
    }
    if (p.contains('/build/') || p.contains('/.dart_tool/')) continue;
    yield e;
  }
}

const _usage = 'Usage: dart run threefold_kit:check_copy [--website] '
    '<file or directory>...';
