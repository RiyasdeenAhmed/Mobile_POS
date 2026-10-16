import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class QubeXUi {
  static const pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 96);
  static const sectionGap = 24.0;
  static const fieldGap = 12.0;
  static const cardRadius = 16.0;
  static const controlRadius = 12.0;
  static const controlHeight = 52.0;
  static const border = Color(0xFFE2E5EA);
  static const mutedSurface = Color(0xFFF2F6FF);
}

class QubeXSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const QubeXSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child:
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class QubeXPrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final IconData? icon;

  const QubeXPrimaryButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? FilledButton(onPressed: onPressed, child: child)
        : FilledButton.icon(
            onPressed: onPressed, icon: Icon(icon), label: child);
    return SizedBox(width: double.infinity, height: 52, child: button);
  }
}

class QubeXEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const QubeXEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title,
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: QubeXCoreColors.qubexDarkGray),
              textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
