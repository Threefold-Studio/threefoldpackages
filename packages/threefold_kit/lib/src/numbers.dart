/// Counts and plurals (SOP R10.7).
library;

import 'money.dart' show groupDigits;

/// 4398 is "4,398".
String formatCount(int n) => groupDigits(n);

/// "1 ticket", "2 tickets", "4,398 tickets"; never "ticket(s)". Pass
/// [many] for irregular plurals: `plural(3, 'child', 'children')`.
String plural(int n, String one, [String? many]) =>
    '${formatCount(n)} ${n == 1 ? one : (many ?? '${one}s')}';

/// A fraction as a percentage: 0.034 is "3.4%", 0.5 is "50%". Up to
/// [decimals] places, trailing zeros dropped. For display of estimates and
/// ratios; fees are basis points ([formatBps]).
String formatPercent(double fraction, {int decimals = 1}) {
  final fixed = (fraction * 100).toStringAsFixed(decimals);
  return '${_trimZeros(fixed)}%';
}

/// Basis points as a percentage: 300 is "3%", 290 is "2.9%", 125 is "1.25%".
/// Exact (integer maths).
String formatBps(int bps) {
  final sign = bps < 0 ? '-' : '';
  final a = bps.abs();
  final whole = a ~/ 100;
  final frac = (a % 100).toString().padLeft(2, '0');
  return '$sign${_trimZeros('$whole.$frac')}%';
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  var out = s.replaceFirst(RegExp(r'0+$'), '');
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out == '-0' ? '0' : out;
}
