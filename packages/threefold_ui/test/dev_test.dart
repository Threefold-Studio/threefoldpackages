// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_ui/threefold_ui.dart';

import 'helpers.dart';

void main() {
  test('devLabel adds (Dev) once', () {
    expect(devLabel('Add 500 coins'), 'Add 500 coins (Dev)');
    expect(devLabel('Force Pro (Dev)'), 'Force Pro (Dev)');
    expect(devLabel('Reset progress  '), 'Reset progress (Dev)');
  });

  test('the dev colour is safety orange', () {
    expect(kDevOrange, const Color(0xFFFF6D00));
    expect(kDevSectionTitle, 'Developer: not in the store app');
  });

  group('DevBanner', () {
    testWidgets('shows the ribbon only when enabled', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: devBannerBuilder(enabled: true),
        debugShowCheckedModeBanner: false,
        home: const Text('Home'),
      ));
      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.message, 'DEV');
      expect(banner.color, kDevOrange);
      expect(banner.textStyle.color, kDevInk);
      expect(find.text('Home'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        builder: devBannerBuilder(enabled: false),
        debugShowCheckedModeBanner: false,
        home: const Text('Home'),
      ));
      expect(find.byType(Banner), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('reads DEV: FREE while Force Free is on', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: devBannerBuilder(enabled: true, message: 'DEV: FREE'),
        debugShowCheckedModeBanner: false,
        home: const SizedBox(),
      ));
      expect(tester.widget<Banner>(find.byType(Banner)).message, 'DEV: FREE');
    });

    testWidgets('chains an inner builder', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: devBannerBuilder(
          enabled: true,
          inner: (context, child) => ColoredBox(
            key: const Key('inner'),
            color: Colors.white,
            child: child,
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const Text('Home'),
      ));
      expect(find.byKey(const Key('inner')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(Banner),
              matching: find.byKey(const Key('inner'))),
          findsOneWidget);
    });

    testWidgets('works without a Directionality above it', (tester) async {
      await tester
          .pumpWidget(const DevBanner(enabled: true, child: SizedBox()));
      expect(find.byType(Banner), findsOneWidget);
    });
  });

  group('DevTile', () {
    testWidgets('orange, wrench, "(Dev)" label, and taps', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        DevTile(
          label: 'Add 500 coins',
          subtitle: 'This phone only',
          onTap: () => taps++,
        ),
      );
      expect(find.text('Add 500 coins (Dev)'), findsOneWidget);
      expect(find.text('This phone only'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.build_rounded));
      expect(icon.color, kDevOrange);
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.tileColor, kDevOrange.withAlpha(24));
      expect(find.bySemanticsLabel(RegExp(r'Add 500 coins \(Dev\)')),
          findsOneWidget);
      await tester.tap(find.byType(DevTile));
      expect(taps, 1);
      expect(tester.getSize(find.byType(ListTile)).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('with a trailing control', (tester) async {
      await pumpApp(
        tester,
        DevTile(
          label: 'Force Pro',
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
      );
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Force Pro (Dev)'), findsOneWidget);
    });
  });

  testWidgets('DevSectionHeader is a header with the SOP wording',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const DevSectionHeader());
    expect(find.text(kDevSectionTitle), findsOneWidget);
    expect(
      tester.getSemantics(find.text(kDevSectionTitle)),
      matchesSemantics(label: kDevSectionTitle, isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('DevBadge reads as a dev feature', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const DevBadge());
    expect(find.text('Dev'), findsOneWidget);
    expect(find.bySemanticsLabel('Dev feature'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container));
    expect((box.decoration! as BoxDecoration).color, kDevOrange);
    handle.dispose();
  });
}
