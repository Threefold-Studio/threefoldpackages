/// `package:test` matchers for copy style, kept apart from the main library
/// so app code never imports a test helper.
///
/// ```dart
/// import 'package:threefold_kit/copy_matchers.dart';
///
/// expect(welcomeSmsBody('Ana'), hasNoDashes);
/// expect(siteHeadline, hasNoDashes(rules: CopyRules.website));
/// ```
library;

import 'package:matcher/matcher.dart';

import 'src/copy.dart';

export 'src/copy.dart' show CopyRules;

/// Matches a string with no em dash or en dash (app rules). Call it,
/// `hasNoDashes(rules: CopyRules.website)`, for website rules.
const HasNoDashes hasNoDashes = HasNoDashes._(CopyRules.app);

/// Matcher behind [hasNoDashes].
class HasNoDashes extends Matcher {
  const HasNoDashes._(this.rules);

  final CopyRules rules;

  /// The same matcher with other [rules].
  HasNoDashes call({CopyRules rules = CopyRules.app}) => HasNoDashes._(rules);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) return false;
    final issues = findDashes(item, rules: rules);
    if (issues.isEmpty) return true;
    matchState['issues'] = issues;
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('text with no dashes as punctuation (${rules.name})');

  @override
  Description describeMismatch(Object? item, Description mismatchDescription,
      Map<Object?, Object?> matchState, bool verbose) {
    if (item is! String) return mismatchDescription.add('is not a String');
    final issues = matchState['issues'] as List<CopyIssue>? ?? const [];
    return mismatchDescription.add('has ${issues.join('; ')}');
  }
}
