/// Money is integer cents from the database to the screen (SOP R10.1 to
/// R10.4). Never a double for anything charged, recorded or totalled.
///
/// Base: thedesignward `money.dart` (hand-rolled grouping, digit by digit
/// parsing, gross-up pinned to the SQL), with nseptoweb's rule that cents
/// show whenever the amount is not whole. That rule fixes nsepto's
/// `formatMoney`, which dropped the cents and showed 1240 cents as "$12", a
/// number the server would reject as a bid.
library;

/// When [formatCents] shows the cents digits.
enum CentsMode {
  /// Only when the amount is not whole: `$12`, `$12.40`.
  auto,

  /// Always: `$12.00`. For invoices, receipts and PDFs.
  always,

  /// Never, and throws if that would hide real cents. For tight spots that
  /// only ever hold whole dollars.
  never,
}

const int _centsPerDollar = 100;

/// 124999 is "$1,249.99"; 1200 is "$12" (auto); 1240 is "$12.40" (auto,
/// never rounded); -500 is "-$5". The minus sign goes before the symbol.
String formatCents(int cents, {CentsMode mode = CentsMode.auto}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ _centsPerDollar;
  final rem = abs % _centsPerDollar;
  if (mode == CentsMode.never && rem != 0) {
    throw ArgumentError.value(
        cents, 'cents', 'CentsMode.never would hide the cents');
  }
  final showCents = switch (mode) {
    CentsMode.always => true,
    CentsMode.never => false,
    CentsMode.auto => rem != 0,
  };
  final b = StringBuffer(negative ? r'-$' : r'$')..write(groupDigits(whole));
  if (showCents) b.write('.${rem.toString().padLeft(2, '0')}');
  return b.toString();
}

/// 1234567 is "1,234,567". Non-negative whole numbers only.
String groupDigits(int value) {
  if (value < 0) return '-${groupDigits(-value)}';
  final s = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// The most whole-dollar digits [parseCents] accepts (well under 2^53).
const int _maxWholeDigits = 13;

/// Parses typed money into cents, digit by digit (R10.3). Never goes
/// through a double: "10.005" as a double is 10.004999..., which silently
/// eats a cent.
///
/// The grammar, after trimming:
///   [-] [$] [spaces] whole [. up to two digits]
/// where whole is plain digits (`1249`) or correctly grouped thousands
/// (`1,249`), and may be empty when a fraction follows (`.99`).
///
/// Accepts `24`, `24.5`, `24.50`, `$1,249.99`, `.99`, `24.`, and a leading
/// `-` only when [allowNegative] is true. Returns null for anything else:
/// letters anywhere (`abc5`, `5abc`), a dash in the middle (`1-2`), two dots,
/// misplaced commas (`1,24`), three decimals (`10.005`), or a lone `$`.
int? parseCents(String? input, {bool allowNegative = false}) {
  final t = (input ?? '').trim();
  var i = 0;
  var negative = false;

  if (i < t.length && t[i] == '-') {
    negative = true;
    i++;
  }
  if (i < t.length && t[i] == r'$') {
    i++;
    while (i < t.length && t[i] == ' ') {
      i++;
    }
  }

  // Whole part: digits, with commas allowed only as thousands separators.
  var whole = 0;
  var wholeDigits = 0;
  var groupLen = 0; // digits since the last comma
  var sawComma = false;
  while (i < t.length && (_isDigit(t, i) || t[i] == ',')) {
    if (t[i] == ',') {
      // First group 1 to 3 digits, every later group exactly 3.
      if (wholeDigits == 0) return null;
      if (sawComma ? groupLen != 3 : groupLen > 3) return null;
      sawComma = true;
      groupLen = 0;
    } else {
      whole = whole * 10 + _digit(t, i);
      wholeDigits++;
      groupLen++;
      if (wholeDigits > _maxWholeDigits) return null;
    }
    i++;
  }
  if (sawComma && groupLen != 3) return null;

  // Fraction: a dot and up to two digits.
  var frac = 0;
  var fracDigits = 0;
  var sawDot = false;
  if (i < t.length && t[i] == '.') {
    sawDot = true;
    i++;
    while (i < t.length && _isDigit(t, i)) {
      if (fracDigits == 2) return null;
      frac = frac * 10 + _digit(t, i);
      fracDigits++;
      i++;
    }
  }

  if (i != t.length) return null; // junk after the number
  if (wholeDigits == 0 && fracDigits == 0) return null;
  if (!sawDot && wholeDigits == 0) return null;
  if (negative && !allowNegative) return null;

  if (fracDigits == 1) frac *= 10;
  final cents = whole * _centsPerDollar + frac;
  return negative ? -cents : cents;
}

bool _isDigit(String s, int i) {
  final c = s.codeUnitAt(i);
  return c >= 0x30 && c <= 0x39;
}

int _digit(String s, int i) => s.codeUnitAt(i) - 0x30;

/// Stored cents back into a text field: 124999 is "1249.99", 0 is "".
String centsToEditableString(int cents) {
  if (cents == 0) return '';
  final abs = cents.abs();
  final sign = cents < 0 ? '-' : '';
  return '$sign${abs ~/ _centsPerDollar}.'
      '${(abs % _centsPerDollar).toString().padLeft(2, '0')}';
}

/// The total charged when a processing fee of [feeBps] basis points
/// (300 is 3%) is grossed up, so the fee is exactly that share of what is
/// charged: $812.50 at 3% is $837.63, not $836.88. Integer maths, rounded
/// half up. The database's generated column is the authority; this is only
/// for a live preview and must be pinned to the SQL by a test (R10.5).
int grossUpCents(int subtotalCents, {int feeBps = 300}) {
  if (subtotalCents <= 0 || feeBps <= 0) return subtotalCents;
  if (feeBps >= 10000) {
    throw ArgumentError.value(feeBps, 'feeBps', 'must be below 10000');
  }
  final keep = 10000 - feeBps;
  return (subtotalCents * 10000 + keep ~/ 2) ~/ keep;
}

/// [bps] of [cents], rounded half up: `bpsOf(10000, 300)` is 300.
int bpsOf(int cents, int bps) {
  final product = cents * bps;
  final q = product ~/ 10000;
  final r = product.remainder(10000).abs();
  if (r * 2 >= 10000) return product < 0 ? q - 1 : q + 1;
  return q;
}
