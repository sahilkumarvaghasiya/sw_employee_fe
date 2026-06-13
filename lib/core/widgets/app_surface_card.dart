import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Consistent elevated surface used across lists, tiles, and sections.
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final decoration = BoxDecoration(
      gradient: gradient,
      color: gradient == null
          ? (isDark ? colorScheme.surface : Colors.white)
          : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(
        color: borderColor ??
            (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE2E8F0)),
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(margin: margin, decoration: decoration, child: content);
    }

    return Container(
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
