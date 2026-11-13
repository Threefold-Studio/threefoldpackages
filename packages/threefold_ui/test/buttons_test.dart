// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:threefold_ui/threefold_ui.dart';

import 'helpers.dart';

void main() {
  test('tap sizes', () {
    expect(kGloveTap, 60);
    expect(kMinTap, 48);
  });

  group('GloveButton', () {
    for (final variant in GloveButtonVariant.values) {
      testWidgets('${variant.name} is at least 60 by 60', (tester) async {
        await pumpApp(
          tester,
          GloveButton(
            label: 'Go',
            semanticLabel: 'Start the ride',
            onPressed: () {},
            variant: variant,
          ),
        );
        final size = tester.getSize(find.byType(GloveButton));
        expect(size.width, greaterThanOrEqualTo(60));
        expect(size.height, greaterThanOrEqualTo(60));
        await expectAccessible(tester);
      });
    }

    testWidgets('screen readers hear the semantic label, and can tap',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        GloveButton(
          label: 'Go',
          semanticLabel: 'Start the ride',
          icon: Icons.play_arrow,
          onPressed: () => taps++,
        ),
      );
      final node = tester.getSemantics(find.byType(GloveButton));
      expect(
        node,
        matchesSemantics(
          label: 'Start the ride',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      handle.dispose();
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const GloveButton(label: 'Go', semanticLabel: 'Start', onPressed: null),
      );
      expect(
        tester.getSemantics(find.byType(GloveButton)),
        matchesSemantics(
            label: 'Start',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('takes the app colours and can fill the width', (tester) async {
      await pumpApp(
        tester,
        SizedBox(
          width: 300,
          child: GloveButton(
            label: 'Go',
            semanticLabel: 'Go',
            onPressed: () {},
            expand: true,
            backgroundColor: const Color(0xFF174273),
            foregroundColor: const Color(0xFFFFFFFF),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FilledButton)).width, 300);
      final material = tester.widget<Material>(find.descendant(
          of: find.byType(FilledButton), matching: find.byType(Material)));
      expect(material.color, const Color(0xFF174273));
    });

    testWidgets('a bigger minimum is honoured', (tester) async {
      await pumpApp(
        tester,
        GloveButton(
            label: 'X', semanticLabel: 'Close', onPressed: () {}, minSize: 86),
      );
      expect(tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(86));
    });

    test('below 60 is refused', () {
      expect(
        () => GloveButton(
            label: 'X', semanticLabel: 'X', onPressed: () {}, minSize: 44),
        throwsAssertionError,
      );
    });
  });

  group('icon buttons', () {
    testWidgets('GloveIconButton is 60 by 60 with its label', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        GloveIconButton(
          icon: Icons.navigation,
          semanticLabel: 'Recenter map',
          onPressed: () => taps++,
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size(60, 60));
      expect(find.bySemanticsLabel('Recenter map'), findsOneWidget);
      expect(find.byTooltip('Recenter map'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
      await expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('LabeledIconButton is 48 by 48 by default', (tester) async {
      await pumpApp(
        tester,
        LabeledIconButton(
            icon: Icons.close, semanticLabel: 'Close', onPressed: () {}),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
      await expectAccessible(tester);
    });

    testWidgets('without a tooltip it still has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        GloveIconButton(
          icon: Icons.close,
          semanticLabel: 'Cancel route',
          onPressed: () {},
          showTooltip: false,
        ),
      );
      expect(find.byTooltip('Cancel route'), findsNothing);
      expect(
        tester.getSemantics(find.byType(GloveIconButton)),
        matchesSemantics(
          label: 'Cancel route',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    test('a glove icon button below 60 is refused', () {
      expect(
        () => GloveIconButton(
            icon: Icons.close, semanticLabel: 'X', onPressed: () {}, size: 50),
        throwsAssertionError,
      );
      expect(
        () => LabeledIconButton(
            icon: Icons.close, semanticLabel: 'X', onPressed: () {}, size: 40),
        throwsAssertionError,
      );
    });
  });
}
