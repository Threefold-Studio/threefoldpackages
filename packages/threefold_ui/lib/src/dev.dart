// Flutter 3.47 moved Material to package:material_ui. This package still
// supports Flutter 3.19, so it keeps the framework import for now.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Safety orange for every dev and testing control (SOP R5.4). No app
/// palette uses it, so a dev control can never pass for a real one.
const Color kDevOrange = Color(0xFFFF6D00);

/// Text and icons on [kDevOrange]: black, about 7.4:1.
const Color kDevInk = Color(0xFF000000);

/// The suffix every dev control's label ends with.
const String kDevSuffix = '(Dev)';

/// The Developer section header wording (SOP R5.4).
const String kDevSectionTitle = 'Developer: not in the store app';

/// [label] with " (Dev)" added, unless it already ends that way:
/// `devLabel('Add 500 coins')` is "Add 500 coins (Dev)".
String devLabel(String label) {
  final t = label.trimRight();
  return t.endsWith(kDevSuffix) ? t : '$t $kDevSuffix';
}

/// DEV-ONLY: a diagonal ribbon over the whole app (SOP R5.4), so every
/// screenshot and tester can tell a dev build. Shows nothing extra when
/// [enabled] is false; pass the app's own `Env.devTools` there.
///
/// Use [devBannerBuilder] for `MaterialApp.builder`.
class DevBanner extends StatelessWidget {
  const DevBanner({
    super.key,
    required this.enabled,
    required this.child,
    this.message = 'DEV',
    this.location = BannerLocation.topEnd,
  });

  /// The app's dev tools flag.
  final bool enabled;

  /// "DEV", or "DEV: FREE" while Force Free is on (SOP R5.8).
  final String message;

  final BannerLocation location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return Banner(
      message: message,
      location: location,
      color: kDevOrange,
      textDirection: direction,
      layoutDirection: direction,
      textStyle: TextStyle(
        color: kDevInk,
        fontWeight: FontWeight.w800,
        fontSize: message.length > 4 ? 9 : 11,
        letterSpacing: 0.5,
        height: 1,
      ),
      child: child,
    );
  }
}

/// DEV-ONLY: a `MaterialApp.builder` that wraps every screen in a
/// [DevBanner]. Chain another builder (a text scale clamp, say) with
/// [inner].
///
/// ```dart
/// MaterialApp(builder: devBannerBuilder(enabled: Env.devTools), ...)
/// ```
TransitionBuilder devBannerBuilder({
  required bool enabled,
  String message = 'DEV',
  TransitionBuilder? inner,
}) {
  return (BuildContext context, Widget? child) {
    final app = inner != null
        ? inner(context, child)
        : (child ?? const SizedBox.shrink());
    return DevBanner(enabled: enabled, message: message, child: app);
  };
}

/// DEV-ONLY: the one look every dev control uses (SOP R5.4): orange tint,
/// wrench icon, and a label ending "(Dev)". Needs a `Material` ancestor, as
/// any `ListTile` does.
class DevTile extends StatelessWidget {
  const DevTile({
    super.key,
    required this.label,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  /// The feature name; " (Dev)" is added for you.
  final String label;

  /// What it changes, for example "This phone only".
  final String? subtitle;

  final VoidCallback? onTap;

  /// A switch, a value, or a segmented control.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 16,
      leading: const Icon(Icons.build_rounded, color: kDevOrange),
      title: Text(devLabel(label)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      tileColor: kDevOrange.withAlpha(24),
      onTap: onTap,
      enabled: onTap != null || trailing != null,
    );
  }
}

/// DEV-ONLY: the Developer section header, "Developer: not in the store
/// app", in the dev colour and marked as a header for screen readers.
class DevSectionHeader extends StatelessWidget {
  const DevSectionHeader({super.key, this.title = kDevSectionTitle});

  final String title;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        color: kDevOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.build_rounded, color: kDevInk, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: (style ?? const TextStyle())
                    .copyWith(color: kDevInk, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DEV-ONLY: a small orange "Dev" chip with a wrench, for the one dev
/// control that must sit on the screen it tests (SOP R5.3), such as
/// "Unlock all levels" on a level map.
class DevBadge extends StatelessWidget {
  const DevBadge({super.key, this.label = 'Dev'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label feature',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kDevOrange,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build_rounded, size: 12, color: kDevInk),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: kDevInk,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
