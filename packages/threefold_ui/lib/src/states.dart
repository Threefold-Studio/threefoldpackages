// Flutter 3.47 moved Material to package:material_ui. This package still
// supports Flutter 3.19, so it keeps the framework import for now.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'buttons.dart';

// The shared async states (SOP R11.10), from nsepto's `status_widgets.dart`
// and thedesignward's `EmptyState`. Every string comes from the app, so the
// wording can say which kind of empty it is ("nothing posted in this date
// range", never just blank). Colours default to the theme.

/// "Nothing here", with a reason.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.action,
    this.iconColor,
    this.titleStyle,
    this.messageStyle,
  });

  final String title;
  final String message;

  /// Decorative; hidden from screen readers.
  final IconData? icon;

  /// A button that fixes it ("Add Your First Item").
  final Widget? action;

  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    return _StateBody(
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      titleStyle: titleStyle,
      messageStyle: messageStyle,
      action: action,
    );
  }
}

/// A spinner with a screen reader label, and an optional line of text.
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    required this.semanticLabel,
    this.message,
    this.color,
    this.messageStyle,
  });

  /// What a screen reader says: "Loading the calendar".
  final String semanticLabel;

  /// Optional visible text under the spinner.
  final String? message;

  final Color? color;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              semanticsLabel: semanticLabel,
              color: color,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: messageStyle ?? theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure with a way forward. Never a raw red error screen; the message
/// says what to do next, and Retry is a real button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
    this.titleStyle,
    this.messageStyle,
    this.retryMinSize = kMinTap,
  }) : assert(
          (onRetry == null) == (retryLabel == null),
          'Pass onRetry and retryLabel together',
        );

  final String title;
  final String message;
  final VoidCallback? onRetry;

  /// "Try Again".
  final String? retryLabel;

  /// Decorative; hidden from screen readers.
  final IconData? icon;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;

  /// 48 by default; pass [kGloveTap] in glove apps.
  final double retryMinSize;

  @override
  Widget build(BuildContext context) {
    return _StateBody(
      icon: icon,
      iconColor: iconColor ?? Theme.of(context).colorScheme.error,
      title: title,
      message: message,
      titleStyle: titleStyle,
      messageStyle: messageStyle,
      liveRegion: true,
      action: onRetry == null
          ? null
          : _RetryButton(
              label: retryLabel!,
              onPressed: onRetry!,
              minSize: retryMinSize,
            ),
    );
  }
}

/// A thin strip saying the content is old: the app writes the words,
/// for example "Offline. Last updated 2 hr ago." (with `formatAge` from
/// threefold_kit).
class StaleBanner extends StatelessWidget {
  const StaleBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.cloud_off_outlined,
    this.backgroundColor,
    this.foregroundColor,
  }) : assert(
          (onRetry == null) == (retryLabel == null),
          'Pass onRetry and retryLabel together',
        );

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData icon;

  /// Default: the theme's `surfaceVariant` family (`secondaryContainer`).
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foregroundColor ?? scheme.onSecondaryContainer;
    return Material(
      color: backgroundColor ?? scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(message, style: TextStyle(color: fg, height: 1.3)),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  minimumSize: const Size(kMinTap, kMinTap),
                ),
                child: Text(retryLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.label,
    required this.onPressed,
    required this.minSize,
  });

  final String label;
  final VoidCallback onPressed;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    if (minSize >= kGloveTap) {
      return GloveButton(
        label: label,
        semanticLabel: label,
        onPressed: onPressed,
        icon: Icons.refresh_rounded,
        variant: GloveButtonVariant.outlined,
        minSize: minSize,
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: Size(minSize, minSize)),
      icon: const Icon(Icons.refresh_rounded),
      label: Text(label),
    );
  }
}

class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.titleStyle,
    required this.messageStyle,
    required this.action,
    this.liveRegion = false,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String message;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final Widget? action;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 40,
                color: iconColor ?? theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
            ],
            Semantics(
              liveRegion: liveRegion,
              child: MergeSemantics(
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: titleStyle ?? theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: messageStyle ?? theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
