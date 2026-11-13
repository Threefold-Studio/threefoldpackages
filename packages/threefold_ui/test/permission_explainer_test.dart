// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_ui/threefold_ui.dart';

import 'helpers.dart';

void main() {
  var allow = 0, settings = 0, notNow = 0;
  setUp(() => allow = settings = notNow = 0);

  Widget explainer({bool deniedForever = false, bool withNotNow = true}) =>
      PermissionExplainerScreen(
        explainer: PermissionExplainer(
          headline: 'Turn on notifications',
          reason: 'We tell you when the PTO posts something urgent.',
          allowLabel: 'Turn On Notifications',
          onAllow: () => allow++,
          onOpenSettings: () => settings++,
          deniedForever: deniedForever,
          deniedMessage: 'Notifications are off for this app in Settings.',
          notNowLabel: withNotNow ? 'Not Now' : null,
          onNotNow: withNotNow ? () => notNow++ : null,
          leading: const Icon(Icons.notifications_outlined, size: 64),
        ),
      );

  testWidgets('one headline, one reason, one 60 point button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: explainer()));
    expect(find.text('Turn on notifications'), findsOneWidget);
    expect(find.text('We tell you when the PTO posts something urgent.'),
        findsOneWidget);
    expect(find.text('Notifications are off for this app in Settings.'),
        findsNothing);
    expect(
      tester.getSemantics(find.text('Turn on notifications')),
      matchesSemantics(label: 'Turn on notifications', isHeader: true),
    );

    final main = find.widgetWithText(GloveButton, 'Turn On Notifications');
    expect(tester.getSize(main).height, greaterThanOrEqualTo(60));
    expect(find.bySemanticsLabel('Turn On Notifications'), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(GloveButton, 'Not Now')).height,
        greaterThanOrEqualTo(60));
    await expectAccessible(tester);

    await tester.tap(main);
    await tester.tap(find.text('Not Now'));
    expect([allow, settings, notNow], [1, 0, 1]);
    handle.dispose();
  });

  testWidgets('denied forever shows Open Settings instead of the prompt',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: explainer(deniedForever: true)));
    expect(find.text('Turn On Notifications'), findsNothing);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Notifications are off for this app in Settings.'),
        findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    expect([allow, settings], [0, 1]);
  });

  testWidgets('Not Now is optional, and nothing fires on its own',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: explainer(withNotNow: false)));
    await tester.pumpAndSettle();
    expect(find.text('Not Now'), findsNothing);
    expect(find.byType(GloveButton), findsOneWidget);
    expect([allow, settings, notNow], [0, 0, 0]);
  });

  testWidgets('takes the app colours', (tester) async {
    const ink = Color(0xFFCAD1D8);
    const button = Color(0xFF00C25C);
    await tester.pumpWidget(MaterialApp(
      home: PermissionExplainerScreen(
        backgroundColor: const Color(0xFF1C1B1A),
        explainer: PermissionExplainer(
          headline: 'H',
          reason: 'R',
          allowLabel: 'Allow',
          onAllow: () {},
          onOpenSettings: () {},
          textColor: ink,
          buttonColor: button,
        ),
      ),
    ));
    expect(tester.widget<Text>(find.text('H')).style!.color, ink);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFF1C1B1A));
    final material = tester.widget<Material>(find.descendant(
        of: find.byType(FilledButton), matching: find.byType(Material)));
    expect(material.color, button);
  });

  testWidgets('scrolls instead of overflowing at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: MaterialApp(home: explainer(deniedForever: true)),
    ));
    expect(tester.takeException(), isNull);
  });

  test('notNowLabel and onNotNow go together', () {
    expect(
      () => PermissionExplainer(
        headline: 'H',
        reason: 'R',
        allowLabel: 'A',
        onAllow: () {},
        onOpenSettings: () {},
        notNowLabel: 'Not Now',
      ),
      throwsAssertionError,
    );
  });
}
