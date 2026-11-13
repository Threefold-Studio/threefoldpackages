import 'dart:io';

import 'package:test/test.dart';
import 'package:threefold_kit/copy_matchers.dart';
import 'package:threefold_kit/threefold_kit.dart';

void main() {
  group('findDashes', () {
    test('reports offsets and the matched text', () {
      final issues = findDashes('A \u2014 B &ndash; C');
      expect(issues, [
        const CopyIssue(DashKind.emDash, 2, '\u2014'),
        const CopyIssue(DashKind.enDash, 6, '&ndash;'),
      ]);
      expect(issues.first.hint, contains('comma'));
      expect(issues.last.toString(), contains('enDash'));
    });

    test('website rules sort every issue by position', () {
      final issues =
          findDashes('a -- b \u2014 c - d', rules: CopyRules.website);
      expect(issues.map((i) => i.kind), [
        DashKind.doubleHyphen,
        DashKind.emDash,
        DashKind.spacedHyphen,
      ]);
      expect(issues.last.offset, 11);
    });

    test('numeric HTML entities', () {
      expect(findDashes('a &#8212; b &#x2013; c').map((i) => i.kind),
          [DashKind.emDash, DashKind.enDash]);
    });

    test('isCleanCopy and findDashesInAll', () {
      expect(isCleanCopy('Built by Threefold Studio'), isTrue);
      final bad = findDashesInAll(['ok', 'not \u2014 ok', 'fine']);
      expect(bad.keys, ['not \u2014 ok']);
    });
  });

  group('matchers', () {
    test('hasNoDashes passes clean text and fails dashes', () {
      expect('Send My Inquiry', hasNoDashes);
      expect('6 to 7 PM', hasNoDashes);
      expect('6\u20137 PM', isNot(hasNoDashes));
      expect('Fast - free', hasNoDashes);
      expect('Fast - free', isNot(hasNoDashes(rules: CopyRules.website)));
      expect(42, isNot(hasNoDashes));
    });

    test('the mismatch names the dash', () {
      final state = <Object?, Object?>{};
      const text = 'Wait \u2014 now';
      expect(hasNoDashes.matches(text, state), isFalse);
      final d =
          hasNoDashes.describeMismatch(text, StringDescription(), state, false);
      expect(d.toString(), contains('emDash'));
      expect(hasNoDashes.describe(StringDescription()).toString(),
          contains('no dashes'));
    });
  });

  group('Dart source scanning', () {
    test('finds literal text, skips comments and interpolated code', () {
      const src = '''
// A comment \u2014 allowed.
/* block \u2014 /* nested \u2014 */ still comment \u2014 */
final a = 'Clean text';
final b = "Doors \u2014 open";
final c = 'Hi \${name.isEmpty ? "x \u2014 y" : name} there';
final d = r'raw \u2013 dash';
final e = \'\'\'
multi
line \u2014 here\'\'\';
final f = 'escaped \\' quote \u2014';
final g = 'skip \u2014 me'; // copy-check: ignore
''';
      final issues = findDashesInDartSource(src);
      expect(issues.map((i) => i.line), [4, 5, 6, 9, 10]);
      expect(issues.map((i) => i.issue.kind), [
        DashKind.emDash,
        DashKind.emDash,
        DashKind.enDash,
        DashKind.emDash,
        DashKind.emDash,
      ]);
      expect(issues.first.column, 18);
      expect(issues.first.toString(), contains('final b'));
    });

    test('dartStringParts splits around interpolation', () {
      final parts =
          dartStringParts(r"var s = 'Hello $name, you have ${n + 1} new';");
      expect(parts.map((p) => p.text), ['Hello ', ', you have ', ' new']);
      expect(parts.first.line, 1);
      expect(parts.first.column, 10);
    });

    test('an identifier ending in r is not a raw string', () {
      final parts = dartStringParts("var s = bar'x';");
      expect(parts.map((p) => p.text), ['x']);
    });

    test('source escapes are caught too', () {
      final issues = findDashesInDartSource(r"final s = 'A \u2014 B';");
      expect(issues.single.issue.match, r'\u2014');
    });

    test('website rules apply to Dart sources', () {
      const src = "final s = 'Fast - free';";
      expect(findDashesInDartSource(src), isEmpty);
      expect(
          findDashesInDartSource(src, rules: CopyRules.website), hasLength(1));
    });

    test('this package ships no dashes in its own strings', () {
      final dir = Directory('lib');
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        expect(findDashesInDartSource(src), isEmpty, reason: f.path);
      }
    });
  });

  group('bin/check_copy.dart', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('check_copy'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<ProcessResult> run(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/check_copy.dart', ...args]);

    test('passes clean files and fails dashes', () async {
      final clean = File('${tmp.path}/clean.dart')
        ..writeAsStringSync("final s = 'Fine, thanks'; // comment \u2014 ok\n");
      final bad = File('${tmp.path}/lib/bad.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("final s = 'Not \u2014 fine';\n");
      File('${tmp.path}/lib/bad_test.dart')
          .writeAsStringSync("final s = 'Tests \u2014 skipped';\n");

      final ok = await run([clean.path]);
      expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
      expect(ok.stdout, contains('OK'));

      final fail = await run([tmp.path]);
      expect(fail.exitCode, 1);
      expect(fail.stdout, contains('${bad.path}:1:16'));
      expect(fail.stdout, isNot(contains('bad_test.dart')));
    });

    test('website flag and usage errors', () async {
      final f = File('${tmp.path}/site.dart')
        ..writeAsStringSync("final s = 'Fast - free';\n");
      expect((await run([f.path])).exitCode, 0);
      expect((await run(['--website', f.path])).exitCode, 1);
      expect((await run([])).exitCode, 64);
      expect((await run(['--nope', f.path])).exitCode, 64);
      expect((await run(['${tmp.path}/missing.dart'])).exitCode, 64);
      expect((await run(['--help'])).exitCode, 0);
    });
  });
}
