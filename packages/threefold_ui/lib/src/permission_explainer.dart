// Flutter 3.47 moved Material to package:material_ui. This package still
// supports Flutter 3.19, so it keeps the framework import for now.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'buttons.dart';

/// The explainer shown before any OS permission prompt (SOP R11.11,
/// R13.4), in ThrottleEDGE's `PermissionGate` style: one headline, one
/// reason, one 60 point button.
///
/// It never calls an OS API itself. The app decides when to show it, asks
/// the OS in [onAllow], opens Settings in [onOpenSettings], and snoozes the
/// offer in [onNotNow] (R13.4: "Not now" snoozes, never retires the offer).
/// When [deniedForever] is true the main button reads [openSettingsLabel]
/// and calls [onOpenSettings], because iOS will not show the prompt twice.
///
/// All text and colours come from the app. Wrap it in
/// [PermissionExplainerScreen] for a full screen.
class PermissionExplainer extends StatelessWidget {
  const PermissionExplainer({
    super.key,
    required this.headline,
    required this.reason,
    required this.allowLabel,
    required this.onAllow,
    required this.onOpenSettings,
    this.deniedForever = false,
    this.deniedMessage,
    this.openSettingsLabel = 'Open Settings',
    this.notNowLabel,
    this.onNotNow,
    this.leading,
    this.headlineStyle,
    this.bodyStyle,
    this.textColor,
    this.buttonColor,
    this.buttonTextColor,
    this.maxWidth = 480,
  }) : assert(
          (notNowLabel == null) == (onNotNow == null),
          'Pass notNowLabel and onNotNow together',
        );

  /// One line: "Turn on location for ride alerts".
  final String headline;

  /// One reason, in plain words, for why the app needs it.
  final String reason;

  /// The main button before the OS has said no: "Turn On Location".
  final String allowLabel;

  /// Ask the OS. Called only by a tap on the main button.
  final VoidCallback onAllow;

  /// Open the system Settings page for this app.
  final VoidCallback onOpenSettings;

  /// The OS answer is "denied forever": show Settings instead of the prompt.
  final bool deniedForever;

  /// Extra line shown when [deniedForever], for example "Location is off
  /// for this app in Settings."
  final String? deniedMessage;

  /// The main button's text when [deniedForever] (SOP R11.11 wording).
  final String openSettingsLabel;

  /// Optional second button, such as "Not Now".
  final String? notNowLabel;
  final VoidCallback? onNotNow;

  /// An optional logo or illustration above the headline.
  final Widget? leading;

  final TextStyle? headlineStyle;
  final TextStyle? bodyStyle;

  /// Headline and body colour; defaults to the theme's `onSurface`.
  final Color? textColor;

  /// Main button colours; default to the theme's filled button.
  final Color? buttonColor;
  final Color? buttonTextColor;

  /// Keeps lines readable on tablets and in landscape.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = textColor ?? theme.colorScheme.onSurface;
    final head =
        (headlineStyle ?? theme.textTheme.headlineSmall ?? const TextStyle())
            .copyWith(color: ink);
    final body = (bodyStyle ?? theme.textTheme.bodyLarge ?? const TextStyle())
        .copyWith(color: ink, height: 1.35);
    final mainLabel = deniedForever ? openSettingsLabel : allowLabel;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[
            Center(child: leading!),
            const SizedBox(height: 32),
          ],
          Semantics(header: true, child: Text(headline, style: head)),
          const SizedBox(height: 12),
          Text(reason, style: body),
          if (deniedForever && deniedMessage != null) ...[
            const SizedBox(height: 12),
            Text(deniedMessage!, style: body),
          ],
          const SizedBox(height: 32),
          GloveButton(
            label: mainLabel,
            semanticLabel: mainLabel,
            onPressed: deniedForever ? onOpenSettings : onAllow,
            backgroundColor: buttonColor,
            foregroundColor: buttonTextColor,
            expand: true,
          ),
          if (notNowLabel != null) ...[
            const SizedBox(height: 8),
            GloveButton(
              label: notNowLabel!,
              semanticLabel: notNowLabel!,
              onPressed: onNotNow,
              variant: GloveButtonVariant.text,
              foregroundColor: ink,
              expand: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// A [PermissionExplainer] as a full screen: centred, scrollable at large
/// text sizes, inside a safe area.
class PermissionExplainerScreen extends StatelessWidget {
  const PermissionExplainerScreen({
    super.key,
    required this.explainer,
    this.backgroundColor,
    this.appBar,
  });

  final PermissionExplainer explainer;

  /// Defaults to the theme's scaffold colour.
  final Color? backgroundColor;

  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: explainer,
          ),
        ),
      ),
    );
  }
}
