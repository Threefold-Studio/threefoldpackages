/// US phone numbers (SOP R10.8, R10.9).
///
/// Keep what the person typed; display through [formatPhone]; send and link
/// through [toE164]. Both mirror nsepto/nseptoweb's SQL, so the app, the
/// website and old app versions agree:
/// `public.format_phone(text)` (migration 20261031000100_phone_format.sql)
/// and `public.to_e164(text)` (20260906001500_sms_e164.sql).
library;

final RegExp _nonDigit = RegExp(r'\D');
final RegExp _plusOne = RegExp(r'^\+\s*1');

/// The ten digit US number inside [raw], or null when it is not one.
/// SQL: digits only; `+` followed by anything but 1 is not US.
String? _usTen(String raw) {
  if (raw.startsWith('+') && !_plusOne.hasMatch(raw)) return null;
  var d = raw.replaceAll(_nonDigit, '');
  if (d.length == 11 && d.startsWith('1')) d = d.substring(1);
  return d.length == 10 ? d : null;
}

/// A US number as `(302) 555-0134`: 10 digits, or 11 starting with 1, or
/// `+1 ...`. Anything else (international, an extension, partial) comes back
/// trimmed, exactly as typed. Never changes the digits. Null or blank gives
/// an empty string (SQL gives null).
String formatPhone(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '';
  final d = _usTen(t);
  if (d == null) return t;
  return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
}

final RegExp _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');
final RegExp _nanp11 = RegExp(r'^1[2-9][0-9]{9}$');
final RegExp _nanp10 = RegExp(r'^[2-9][0-9]{9}$');

/// E.164 for SMS and `tel:` links, or null when the number cannot be
/// trusted, in which case build no link. Same rule as SQL `to_e164`: keep
/// digits and `+`, then accept an existing `+` number of 8 to 15 digits, an
/// 11 digit `1` number, or a bare 10 digit NANP number (area code 2 to 9).
String? toE164(String? raw) {
  final d = (raw ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (_e164.hasMatch(d)) return d;
  if (_nanp11.hasMatch(d)) return '+$d';
  if (_nanp10.hasMatch(d)) return '+1$d';
  return null;
}

/// `tel:+13025550134`, or null when [toE164] is null.
String? telUri(String? raw) {
  final e = toE164(raw);
  return e == null ? null : 'tel:$e';
}

/// The one validation message for phone fields.
const String phoneProblemMessage = 'Enter a phone number, like (302) 555-0134.';

final RegExp _phoneChars = RegExp(r'^[0-9+()\-. ]+$');

/// Null when [text] is blank or looks like a phone number (digits and
/// `+ ( ) - .` and spaces, 10 to 15 digits), otherwise
/// [phoneProblemMessage]. The rule of nsepto's `phoneProblem` and the
/// database's `profiles_phone_looks_like_phone`.
String? phoneProblem(String? text) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return null;
  final digits = value.replaceAll(_nonDigit, '').length;
  if (!_phoneChars.hasMatch(value) || digits < 10 || digits > 15) {
    return phoneProblemMessage;
  }
  return null;
}

/// The as-you-type shape for a phone field, the logic of nsepto's
/// `PhoneInputFormatter` and nseptoweb's `formatPhoneTyping`: `3025550134`
/// shows `(302) 555-0134`. A number starting with `+` that is not `+1` is
/// left exactly as typed. Leading 1s are dropped (no US area code starts
/// with 1) and at most 10 digits are kept. Backspacing over a bracket,
/// space or dash takes the digit before it.
String formatPhoneTyping(String next, {String previous = ''}) {
  final trimmed = next.trimLeft();
  if (trimmed.startsWith('+') && !_plusOne.hasMatch(trimmed)) return next;
  var digits = next.replaceAll(_nonDigit, '');
  final prevDigits = previous.replaceAll(_nonDigit, '');
  if (next.length < previous.length &&
      digits == prevDigits &&
      digits.isNotEmpty) {
    digits = digits.substring(0, digits.length - 1);
  }
  digits = digits.replaceFirst(RegExp(r'^1+'), '');
  if (digits.length > 10) digits = digits.substring(0, 10);
  return _shape(digits);
}

String _shape(String digits) {
  if (digits.isEmpty) return '';
  if (digits.length <= 3) return '($digits';
  final area = digits.substring(0, 3);
  if (digits.length <= 6) return '($area) ${digits.substring(3)}';
  return '($area) ${digits.substring(3, 6)}-${digits.substring(6)}';
}
