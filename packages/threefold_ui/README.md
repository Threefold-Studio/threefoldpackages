# threefold_ui

Shared Flutter widgets for Threefold Studio apps: the DEV ribbon and Dev controls (SOP Section 5), glove-size buttons and labelled icon buttons (Section 11), the permission explainer (R11.11, R13.4), and empty, loading, error and stale states (R11.10).

No brand is baked in. Every string and colour comes from the app; colours left out fall back to the app's `Theme`. The one fixed colour is the dev orange, which by design no app palette uses.

Works with Flutter 3.19 or later (Dart 3.3 or later). It has no dependencies beyond Flutter.

## Add it

```yaml
dependencies:
  threefold_ui:
    git:
      url: https://github.com/Threefold-Studio/threefoldpackages.git
      path: packages/threefold_ui
      ref: v0.1.0
```

Always pin a tag, never a branch.

```dart
import 'package:threefold_ui/threefold_ui.dart';
```

## Dev ribbon and Dev controls (R5.3, R5.4, R5.8)

Pass the app's own compile-time flag. Because `Env.devTools` is a `const`, the compiler drops dev blocks from a store build.

```dart
MaterialApp(
  builder: devBannerBuilder(
    enabled: Env.devTools,
    message: proMode == ProMode.forceFree ? 'DEV: FREE' : 'DEV',
  ),
  ...
);
```

To chain another builder (a text scale clamp, for example), pass it as `inner:`.

On the Developer screen:

```dart
const DevSectionHeader(), // "Developer: not in the store app"
DevTile(
  label: 'Add 500 coins', // shown as "Add 500 coins (Dev)"
  subtitle: 'This phone only',
  onTap: player.addCoinsForDev,
),
DevTile(
  label: 'Time travel',
  subtitle: DevClock.describe(), // from threefold_kit
  onTap: () => DevClock.advanceForDev(const Duration(days: 1)),
),
```

For the rare dev control that must sit on the screen it tests, put a `DevBadge()` beside it.

## Glove buttons (R11.5, R11.6)

```dart
GloveButton(
  label: 'Start Ride',
  semanticLabel: 'Start the ride',
  icon: Icons.play_arrow,
  onPressed: start,
  backgroundColor: AppColors.green,
  foregroundColor: AppColors.blue,
  expand: true,
);

GloveIconButton(
  icon: Icons.navigation,
  semanticLabel: 'Recenter map',
  onPressed: recenter,
);

LabeledIconButton( // 48 point version for everyday screens
  icon: Icons.close,
  semanticLabel: 'Close',
  onPressed: close,
);
```

The label is a required argument, so no icon button can ship without one. `GloveButton` asserts a minimum of 60 points and `LabeledIconButton` of 48. `variant:` picks filled, outlined or text.

## Permission explainer (R11.11, R13.4, R13.5)

Show it at a moment of value, never on first launch. It only calls back; the app asks the OS, opens Settings and records the snooze.

```dart
PermissionExplainerScreen(
  explainer: PermissionExplainer(
    headline: 'Turn on notifications',
    reason: 'We tell you the moment the PTO posts something urgent.',
    allowLabel: 'Turn On Notifications',
    onAllow: notifications.requestPermission,
    deniedForever: status.isPermanentlyDenied,
    deniedMessage: 'Notifications are off for this app in Settings.',
    onOpenSettings: openAppSettings,
    notNowLabel: 'Not Now',
    onNotNow: () => prefs.snoozeNotificationAsk(const Duration(days: 30)),
    leading: Image.asset('assets/images/logo.png', width: 160),
  ),
);
```

When `deniedForever` is true the main button reads "Open Settings" (change it with `openSettingsLabel`) and calls `onOpenSettings`.

## States (R11.10)

```dart
const LoadingState(semanticLabel: 'Loading the calendar');

EmptyState(
  icon: Icons.inbox_outlined,
  title: 'Nothing posted yet',
  message: 'The PTO has not posted anything in the last 7 days.',
  action: GloveButton(label: 'Show Older', semanticLabel: 'Show older posts', onPressed: showOlder),
);

ErrorState(
  title: 'No connection',
  message: 'We could not check for new posts. Try again in a minute.',
  retryLabel: 'Try Again',
  onRetry: refresh,
  retryMinSize: kGloveTap, // in glove apps
);

StaleBanner(
  message: 'Offline. Last updated ${formatAge(savedAt, now: AppClock.now())}.',
  retryLabel: 'Retry',
  onRetry: refresh,
);
```

Icons are decorative and hidden from screen readers; titles are marked as headers; error and stale text is a live region so a screen reader announces it.

## A note on the Material import

Flutter 3.47 deprecated `package:flutter/material.dart` in favour of `package:material_ui`. This package still supports Flutter 3.19, so it keeps the framework import with an `ignore` comment. Moving to `material_ui` will be a major version (v1) once every app is on a new enough Flutter.

## Development

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

Widget tests check sizes, semantics labels and Flutter's tap target, labelled tap target and text contrast guidelines.
