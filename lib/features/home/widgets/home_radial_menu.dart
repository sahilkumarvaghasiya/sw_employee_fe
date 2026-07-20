import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class HomeRadialAction {
  const HomeRadialAction({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.enabled = true,
    this.disabledHint,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledHint;
}

/// Floating flat action dock pinned to the bottom of home.
class HomeRadialMenu extends StatelessWidget {
  const HomeRadialMenu({
    super.key,
    required this.actions,
  });

  final List<HomeRadialAction> actions;

  /// Visible dock body (excludes outer margins + safe area).
  static const double contentHeight = 68;

  /// Horizontal inset + gap below dock above the home indicator.
  static const double outerInset = 16;
  static const double bottomGap = 10;

  /// Total scroll clearance: dock + gap + safe area.
  static double scrollClearance(BuildContext context) =>
      contentHeight + bottomGap + MediaQuery.paddingOf(context).bottom;

  void _onActionTap(BuildContext context, HomeRadialAction action) {
    if (!action.enabled) {
      HapticFeedback.heavyImpact();
      final hint = (action.disabledHint ?? '').trim();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              hint.isEmpty
                  ? '${action.label} access is locked by your manager.'
                  : hint,
            ),
          ),
        );
      return;
    }
    HapticFeedback.selectionClick();
    action.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          outerInset,
          0,
          outerInset,
          bottomGap + bottomPad,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: SizedBox(
            height: contentHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 28,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.slate100,
                      ),
                    Expanded(
                      child: _BarItem(
                        action: actions[i],
                        isDark: isDark,
                        onTap: () => _onActionTap(context, actions[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatefulWidget {
  const _BarItem({
    required this.action,
    required this.isDark,
    required this.onTap,
  });

  final HomeRadialAction action;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_BarItem> createState() => _BarItemState();
}

class _BarItemState extends State<_BarItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = widget.action;
    final isDark = widget.isDark;
    final enabled = action.enabled;
    final accent = action.accentColor;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.32)
        : AppColors.slate400;
    final labelColor = enabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.9)
            : AppColors.slate700)
        : muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: isDark ? 0.22 : 0.16),
                              accent.withValues(alpha: isDark ? 0.1 : 0.06),
                            ],
                          )
                        : null,
                    color: enabled
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.slate100),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: enabled ? accent : muted,
                  ),
                ),
                if (!enabled)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate600 : AppColors.slate500,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.slate800 : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1.1,
                letterSpacing: -0.15,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
