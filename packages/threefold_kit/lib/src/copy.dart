/// Copy style checks (SOP R10.10 to R10.12, R10.16).
///
/// Shipped text has no em dashes. Ranges say "to", so an en dash is
/// punctuation too and is flagged in app copy as well. Website and marketing
/// copy uses no dashes as punctuation at all: [CopyRules.website] also flags
/// a spaced hyphen (`a - b`) and a double hyphen (`a -- b`). Hyphens inside
/// words (`one-time`, `555-0134`) are never flagged.
library;

/// Which rules a check applies.
enum CopyRules {
  /// App screens, notifications, emails, PDFs, TTS: em and en dashes.
  app,

  /// Website and marketing copy: also spaced and double hyphens.
  website,
}

/// What kind of dash a [CopyIssue] found.
enum DashKind {
  /// U+2014, or the source spellings `\u2014`, `\u{2014}`, `&mdash;`.
  emDash,

  /// U+2013, or `\u2013`, `\u{2013}`, `&ndash;`.
  enDash,

  /// U+2012 figure dash or U+2015 horizontal bar, read like an em dash.
  otherDash,

  /// ` - ` between words (website rules only).
  spacedHyphen,

  /// `--` used as a dash (website rules only).
  doubleHyphen,
}

/// One dash found in a piece of copy.
class CopyIssue {
  const CopyIssue(this.kind, this.offset, this.match);

  final DashKind kind;

  /// Index of the dash in the checked string.
  final int offset;

  /// The text that matched (the dash itself, or an escape such as `&mdash;`).
  final String match;

  /// A short fix hint for reports.
  String get hint => switch (kind) {
        DashKind.emDash ||
        DashKind.otherDash =>
          'em dash: use a comma, colon, period or parentheses',
        DashKind.enDash => 'en dash: say "to" for a range, or use a comma',
        DashKind.spacedHyphen ||
        DashKind.doubleHyphen =>
          'dash as punctuation: website copy uses none',
      };

  @override
  String toString() => '$offset: ${kind.name} "$match" ($hint)';

  @override
  bool operator ==(Object other) =>
      other is CopyIssue &&
      other.kind == kind &&
      other.offset == offset &&
      other.match == match;

  @override
  int get hashCode => Object.hash(kind, offset, match);
}

// The dash characters are written as escapes so this file is readable and
// passes its own check; each pattern line is skipped by the scanner.
final RegExp _always = RegExp(
  '(\u2014|\\\\u2014|\\\\u\\{2014\\}|&mdash;|&#8212;|&#x2014;)' // copy-check: ignore
  '|(\u2013|\\\\u2013|\\\\u\\{2013\\}|&ndash;|&#8211;|&#x2013;)' // copy-check: ignore
  '|(\u2012|\u2015)', // copy-check: ignore
  caseSensitive: false,
);

final RegExp _websiteOnly = RegExp(r'(?<=\S)( - )(?=\S)|(?<!-)(--)(?!-)');

/// Every dash in [text] that the [rules] forbid, in order of position.
List<CopyIssue> findDashes(String text, {CopyRules rules = CopyRules.app}) {
  final issues = <CopyIssue>[];
  for (final m in _always.allMatches(text)) {
    final kind = m.group(1) != null
        ? DashKind.emDash
        : m.group(2) != null
            ? DashKind.enDash
            : DashKind.otherDash;
    issues.add(CopyIssue(kind, m.start, m.group(0)!));
  }
  if (rules == CopyRules.website) {
    for (final m in _websiteOnly.allMatches(text)) {
      final spaced = m.group(1) != null;
      issues.add(CopyIssue(
        spaced ? DashKind.spacedHyphen : DashKind.doubleHyphen,
        spaced ? m.start + 1 : m.start,
        spaced ? '-' : '--',
      ));
    }
    issues.sort((a, b) => a.offset.compareTo(b.offset));
  }
  return issues;
}

/// True when [text] passes [findDashes].
bool isCleanCopy(String text, {CopyRules rules = CopyRules.app}) =>
    findDashes(text, rules: rules).isEmpty;

/// Every string in [texts] that fails [findDashes], with its issues. Handy
/// for pinning a whole copy file in one test.
Map<String, List<CopyIssue>> findDashesInAll(Iterable<String> texts,
    {CopyRules rules = CopyRules.app}) {
  final out = <String, List<CopyIssue>>{};
  for (final t in texts) {
    final issues = findDashes(t, rules: rules);
    if (issues.isNotEmpty) out[t] = issues;
  }
  return out;
}

const Set<String> _small = {
  'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of', //
  'on', 'or', 'per', 'the', 'to', 'via', 'vs',
};

/// Title Case for labels the app writes (titles, buttons, tabs), never for
/// anything a person typed (R10.13). Capitalises the first letter of each
/// word, keeps small words lower case except first and last, and leaves the
/// rest of every word alone (`iPhone`, `PTO`, `FAQ`).
String titleCase(String s) {
  final words = s.split(' ');
  final last = words.length - 1;
  return [
    for (var i = 0; i < words.length; i++)
      _titleWord(words[i], first: i == 0, last: i == last),
  ].join(' ');
}

String _titleWord(String w, {required bool first, required bool last}) {
  if (w.isEmpty) return w;
  if (!first && !last && _small.contains(w.toLowerCase())) {
    return w.toLowerCase();
  }
  // Leave brand-style words alone: iPhone, eBay.
  if (w[0] != w[0].toUpperCase() && w.substring(1).contains(RegExp('[A-Z]'))) {
    return w;
  }
  return w[0].toUpperCase() + w.substring(1);
}
