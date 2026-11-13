import 'copy.dart';

/// One piece of literal text inside a Dart string literal: the parts
/// between interpolations, as written in the source (escapes not decoded).
class DartStringPart {
  const DartStringPart(this.text, this.offset, this.line, this.column);

  /// The source text of this part.
  final String text;

  /// Offset of [text] in the source.
  final int offset;

  /// 1-based line and column of [text]'s first character.
  final int line;
  final int column;
}

/// A copy problem found in a Dart source file.
class DartCopyIssue {
  const DartCopyIssue(this.line, this.column, this.issue, this.lineText);

  final int line;
  final int column;
  final CopyIssue issue;

  /// The whole source line, trimmed, for reports.
  final String lineText;

  @override
  String toString() => '$line:$column: ${issue.hint}: $lineText';
}

/// The marker that skips a line in [findDashesInDartSource], for the rare
/// literal that must hold a dash (a test fixture, a regex).
const String copyIgnoreMarker = 'copy-check: ignore';

/// Every literal text part of every string literal in [source], skipping
/// comments. A small hand-written lexer (no `package:analyzer`, so apps can
/// depend on this without version fights). It understands `'`, `"`, triple
/// quotes, raw strings, escapes, `$name` and nested `${...}` interpolation,
/// and nested `/* */` comments.
List<DartStringPart> dartStringParts(String source) => _Lexer(source).run();

/// Dashes in the string literals of a Dart [source] file. Comments are
/// ignored (code comments may use any dash), and so is any line carrying
/// [copyIgnoreMarker].
List<DartCopyIssue> findDashesInDartSource(String source,
    {CopyRules rules = CopyRules.app}) {
  final lines = source.split('\n');
  final lineStarts = _lineStarts(source);
  final out = <DartCopyIssue>[];
  for (final part in dartStringParts(source)) {
    for (final issue in findDashes(part.text, rules: rules)) {
      final at = part.offset + issue.offset;
      final line = _lineOf(lineStarts, at);
      final text = lines[line - 1];
      if (text.contains(copyIgnoreMarker)) continue;
      out.add(DartCopyIssue(
          line, at - lineStarts[line - 1] + 1, issue, text.trim()));
    }
  }
  return out;
}

List<int> _lineStarts(String s) {
  final starts = <int>[0];
  for (var i = 0; i < s.length; i++) {
    if (s.codeUnitAt(i) == 0x0A) starts.add(i + 1);
  }
  return starts;
}

int _lineOf(List<int> starts, int offset) {
  var lo = 0;
  var hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (starts[mid] <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo + 1;
}

class _Lexer {
  _Lexer(this.s) : _starts = _lineStarts(s);

  final String s;
  final List<int> _starts;
  int i = 0;
  final List<DartStringPart> parts = [];

  List<DartStringPart> run() {
    _code(untilBrace: false);
    return parts;
  }

  bool _at(String t) => s.startsWith(t, i);

  /// Code until end of input, or until the `}` closing an interpolation.
  void _code({required bool untilBrace}) {
    var depth = 0;
    while (i < s.length) {
      final c = s[i];
      if (_at('//')) {
        final nl = s.indexOf('\n', i);
        i = nl < 0 ? s.length : nl + 1;
      } else if (_at('/*')) {
        _blockComment();
      } else if (c == '{') {
        depth++;
        i++;
      } else if (c == '}') {
        if (untilBrace && depth == 0) {
          i++;
          return;
        }
        depth--;
        i++;
      } else if (c == "'" || c == '"') {
        _string(raw: false);
      } else if ((c == 'r' || c == 'R') &&
          i + 1 < s.length &&
          (s[i + 1] == "'" || s[i + 1] == '"') &&
          !_identBefore()) {
        i++;
        _string(raw: true);
      } else {
        i++;
      }
    }
  }

  bool _identBefore() {
    if (i == 0) return false;
    final p = s.codeUnitAt(i - 1);
    return (p >= 0x30 && p <= 0x39) ||
        (p >= 0x41 && p <= 0x5A) ||
        (p >= 0x61 && p <= 0x7A) ||
        p == 0x5F ||
        p == 0x24;
  }

  void _blockComment() {
    var depth = 0;
    while (i < s.length) {
      if (_at('/*')) {
        depth++;
        i += 2;
      } else if (_at('*/')) {
        depth--;
        i += 2;
        if (depth == 0) return;
      } else {
        i++;
      }
    }
  }

  void _string({required bool raw}) {
    final q = s[i];
    final triple = _at('$q$q$q');
    final close = triple ? '$q$q$q' : q;
    i += close.length;
    var start = i;

    void flush(int end) {
      if (end > start) {
        final line = _lineOf(_starts, start);
        parts.add(DartStringPart(s.substring(start, end), start, line,
            start - _starts[line - 1] + 1));
      }
    }

    while (i < s.length) {
      if (_at(close)) {
        flush(i);
        i += close.length;
        return;
      }
      final c = s[i];
      if (!triple && c == '\n') {
        flush(i); // unterminated; stop at the line end
        return;
      }
      if (!raw && c == r'\') {
        i += 2;
        continue;
      }
      if (!raw && c == r'$') {
        if (i + 1 < s.length && s[i + 1] == '{') {
          flush(i);
          i += 2;
          _code(untilBrace: true);
          start = i;
          continue;
        }
        flush(i);
        i++;
        while (i < s.length && _isIdent(s.codeUnitAt(i))) {
          i++;
        }
        start = i;
        continue;
      }
      i++;
    }
    flush(i);
  }

  static bool _isIdent(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F;
}
