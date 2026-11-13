// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_ui/threefold_ui.dart';

import 'helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('title, message and action; icon is decorative',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing posted yet',
          message: 'The PTO has not posted anything in the last 7 days.',
          action: GloveButton(
              label: 'Show Older',
              semanticLabel: 'Show older posts',
              onPressed: () {}),
        ),
      );
      expect(find.text('Nothing posted yet'), findsOneWidget);
      expect(find.byType(GloveButton), findsOneWidget);
      expect(
        find.bySemanticsLabel(
            RegExp(r'Nothing posted yet\nThe PTO has not posted anything')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Show older posts'), findsOneWidget);
      await expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('icon is optional and takes the app colour', (tester) async {
      await pumpApp(tester, const EmptyState(title: 'T', message: 'M'));
      expect(find.byType(Icon), findsNothing);
      await pumpApp(
        tester,
        const EmptyState(
            title: 'T',
            message: 'M',
            icon: Icons.inbox,
            iconColor: Color(0xFF5C6E4F)),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color,
          const Color(0xFF5C6E4F));
    });
  });

  group('LoadingState', () {
    testWidgets('spinner carries the screen reader label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const LoadingState(
          semanticLabel: 'Loading the calendar',
          message: 'One moment',
          color: Color(0xFF174273),
        ),
      );
      expect(find.bySemanticsLabel('Loading the calendar'), findsOneWidget);
      expect(find.text('One moment'), findsOneWidget);
      expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .color,
          const Color(0xFF174273));
      handle.dispose();
    });
  });

  group('ErrorState', () {
    testWidgets('message plus a working Retry', (tester) async {
      final handle = tester.ensureSemantics();
      var retries = 0;
      await pumpApp(
        tester,
        ErrorState(
          title: 'No connection',
          message: 'We could not check for new posts. Try again in a minute.',
          retryLabel: 'Try Again',
          onRetry: () => retries++,
        ),
      );
      expect(find.text('No connection'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retries, 1);
      expect(tester.getSize(find.byType(OutlinedButton)).height,
          greaterThanOrEqualTo(48));
      await expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('a glove app gets a 60 point Retry', (tester) async {
      await pumpApp(
        tester,
        ErrorState(
          title: 'T',
          message: 'M',
          retryLabel: 'Try Again',
          onRetry: () {},
          retryMinSize: kGloveTap,
        ),
      );
      expect(find.byType(GloveButton), findsOneWidget);
      expect(tester.getSize(find.byType(GloveButton)).height,
          greaterThanOrEqualTo(60));
    });

    testWidgets('no Retry without a callback', (tester) async {
      await pumpApp(tester, const ErrorState(title: 'T', message: 'M'));
      expect(find.byType(OutlinedButton), findsNothing);
    });

    test('retry label and callback go together', () {
      expect(() => ErrorState(title: 'T', message: 'M', onRetry: () {}),
          throwsAssertionError);
    });
  });

  group('StaleBanner', () {
    testWidgets('shows the app message and retries', (tester) async {
      var retries = 0;
      await pumpApp(
        tester,
        StaleBanner(
          message: 'Offline. Last updated 2 hr ago.',
          retryLabel: 'Retry',
          onRetry: () => retries++,
        ),
      );
      expect(find.text('Offline. Last updated 2 hr ago.'), findsOneWidget);
      expect(tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
      await expectAccessible(tester);
    });
  });
}
