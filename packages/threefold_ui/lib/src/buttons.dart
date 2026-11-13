// Flutter 3.47 moved Material to package:material_ui. This package still
// supports Flutter 3.19, so it keeps the framework import for now.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// The glove tap target: 60 by 60 points (SOP R11.5, Spec Section 9 in
/// ThrottleEDGE). For apps used with gloves, in motion, or half asleep.
const double kGloveTap = 60;

/// The everyday minimum tap target: 48 by 48 (SOP R11.5).
const double kMinTap = 48;

/// Which Material button a [GloveButton] draws.
enum GloveButtonVariant { filled, outlined, text }

/// A text button at least 60 by 60 points, with a required screen reader
/// label (ThrottleEDGE's "label is a required constructor argument" trick,
/// SOP R11.6). Colours come from the app's theme unless passed in.
class GloveButton extends StatelessWidget {
  const GloveButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.variant = GloveButtonVariant.filled,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
    this.minSize = kGloveTap,
    this.expand = false,
  }) : assert(minSize >= kGloveTap, 'A glove button is at least 60 points');

  /// The visible text, in Title Case (SOP R10.12).
  final String label;

  /// What a screen reader says. Often the same as [label], sometimes fuller
  /// ("Turn On Location for ride alerts").
  final String semanticLabel;

  /// Null shows the button disabled.
  final VoidCallback? onPressed;

  final IconData? icon;
  final GloveButtonVariant variant;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? textStyle;

  /// Minimum width and height; never below [kGloveTap].
  final double minSize;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final size = Size(minSize, minSize);
    final style =
        textStyle ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    final Widget button;
    switch (variant) {
      case GloveButtonVariant.filled:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: size,
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: padding,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            textStyle: style,
          ),
          child: child,
        );
      case GloveButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: padding,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            textStyle: style,
          ),
          child: child,
        );
      case GloveButtonVariant.text:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: size,
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: padding,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            textStyle: style,
          ),
          child: child,
        );
    }

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// An icon-only button with a required label that becomes its tooltip and
/// screen reader label (SOP R11.6). [size] defaults to the 48 point
/// minimum; [GloveIconButton] is the 60 point version.
class LabeledIconButton extends StatelessWidget {
  const LabeledIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = kMinTap,
    this.iconSize,
    this.color,
    this.showTooltip = true,
  }) : assert(size >= kMinTap, 'A tap target is at least 48 points');

  final IconData icon;

  /// Required: the tooltip and the screen reader label.
  final String semanticLabel;

  final VoidCallback? onPressed;

  /// Width and height of the tap target.
  final double size;

  final double? iconSize;
  final Color? color;

  /// False keeps the label for screen readers but shows no long-press
  /// tooltip (handy with gloves, where long presses happen by accident).
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: showTooltip ? semanticLabel : null,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      iconSize: iconSize ?? size * 0.5,
      color: color,
      icon: Icon(icon),
      onPressed: onPressed,
    );
    // An explicit label rather than relying on the tooltip: newer Flutter
    // reports a tooltip as its own semantics property, not as the label.
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// A 60 point [LabeledIconButton] for gloved or in-motion use (ThrottleEDGE
/// `GloveIconButton`).
class GloveIconButton extends LabeledIconButton {
  const GloveIconButton({
    super.key,
    required super.icon,
    required super.semanticLabel,
    required super.onPressed,
    super.size = kGloveTap,
    super.iconSize,
    super.color,
    super.showTooltip,
  }) : assert(size >= kGloveTap, 'A glove button is at least 60 points');
}
