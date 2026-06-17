import 'package:flutter/material.dart';

/// A reusable, Material 3–styled action icon button used in the invite section.
/// Supports tooltips, semantics, and theme-adaptive colors.
class ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final String semanticsLabel;
  final Color? iconColor;

  const ActionIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.semanticsLabel,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = iconColor ?? cs.primary;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: color.withValues(alpha: 0.15),
            highlightColor: color.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

