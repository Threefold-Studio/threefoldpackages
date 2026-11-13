import 'package:test/test.dart';
import 'package:threefold_kit/threefold_kit.dart';

void main() {
  group('formatCents', () {
    test('auto never rounds a non-whole amount (the nsepto formatMoney bug)',
        () {
      expect(formatCents(1240), r'$12.40');
      expect(formatCents(1250), r'$12.50');
      expect(formatCents(1299), r'$12.99');
    });

    test('never throws rather than hide cents', () {
      expect(
          () => formatCents(1240, mode: CentsMode.never), throwsArgumentError);
    });

    test('round trips through parseCents', () {
      for (final c in [0, 1, 99, 100, 1240, 124999, 100000000]) {
        expect(parseCents(formatCents(c)), c);
        expect(parseCents(formatCents(c, mode: CentsMode.always)), c);
        expect(parseCents(formatCents(-c), allowNegative: true), -c);
      }
    });
  });

  test('groupDigits', () {
    expect(groupDigits(0), '0');
    expect(groupDigits(1000), '1,000');
    expect(groupDigits(-1234), '-1,234');
  });

  test('centsToEditableString round trips', () {
    expect(centsToEditableString(124999), '1249.99');
    expect(centsToEditableString(0), '');
    expect(centsToEditableString(-505), '-5.05');
    for (final c in [1, 1240, 124999]) {
      expect(parseCents(centsToEditableString(c)), c);
    }
  });

  group('grossUpCents', () {
    test('is not just adding the fee', () {
      expect(grossUpCents(81250), isNot((81250 * 1.03).round()));
    });

    test('matches the floating point form across a range', () {
      for (var s = 1; s < 200000; s += 997) {
        expect(grossUpCents(s), (s / 0.97).round(), reason: '$s');
      }
    });

    test('rejects a fee of 100% or more', () {
      expect(() => grossUpCents(100, feeBps: 10000), throwsArgumentError);
    });
  });

  test('bpsOf rounds half up', () {
    expect(bpsOf(10000, 300), 300);
    expect(bpsOf(83763, 300), 2513);
    expect(bpsOf(50, 100), 1); // 0.5 cents rounds up
    expect(bpsOf(49, 100), 0);
    expect(bpsOf(-50, 100), -1);
  });

  group('numbers', () {
    test('formatPercent', () {
      expect(formatPercent(0.034), '3.4%');
      expect(formatPercent(0.5), '50%');
      expect(formatPercent(0.12345, decimals: 2), '12.35%');
      expect(formatPercent(0), '0%');
    });

    test('formatBps negative', () {
      expect(formatBps(-250), '-2.5%');
    });
  });

  group('phone', () {
    test('telUri only for a number we can place', () {
      expect(telUri('(302) 555-0134'), 'tel:+13025550134');
      expect(telUri('555-0134'), isNull);
    });

    test('formatPhone never changes the digits', () {
      for (final raw in [
        '3025550134',
        '+44 20 7946 0958',
        '555-0134',
        '1 302 555 0134'
      ]) {
        final digits = raw.replaceAll(RegExp(r'\D'), '');
        final shown = formatPhone(raw).replaceAll(RegExp(r'\D'), '');
        expect(digits.endsWith(shown), isTrue, reason: raw);
      }
    });

    test('display and E.164 agree for US numbers', () {
      expect(toE164(formatPhone('13025550134')), '+13025550134');
    });

    test('the validation message has no dashes as punctuation', () {
      expect(isCleanCopy(phoneProblemMessage), isTrue);
    });
  });
}
