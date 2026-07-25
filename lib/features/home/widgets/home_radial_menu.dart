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
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledHint;
  final bool isPrimary;
}

/// Floating action dock with a raised center primary action (Billing).
class HomeRadialMenu extends StatelessWidget {
  const HomeRadialMenu({
    super.key,
    required this.actions,
  });

  final List<HomeRadialAction> actions;

  /// Flat bar body height (below the bump).
  static const double barHeight = 64;

  /// How far the center bump rises above the bar top.
  static const double bumpRise = 34;

  /// Diameter of the elevated primary action.
  static const double fabSize = 60;

  /// Visible dock body including bump (excludes outer margins + safe area).
  static const double contentHeight = barHeight + bumpRise;

  static const double outerInset = 16;
  static const double bottomGap = 10;

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

    final primaryIndex = actions.indexWhere((a) => a.isPrimary);
    final resolvedPrimaryIndex =
        primaryIndex >= 0 ? primaryIndex : (actions.length ~/ 2);
    final primary = actions.isEmpty ? null : actions[resolvedPrimaryIndex];
    final sideActions = <HomeRadialAction>[
      for (var i = 0; i < actions.length; i++)
        if (i != resolvedPrimaryIndex) actions[i],
    ];
    final left = sideActions.take(sideActions.length ~/ 2).toList();
    final right = sideActions.skip(sideActions.length ~/ 2).toList();

    final surface = isDark ? AppColors.slate800 : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.slate200;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          outerInset,
          0,
          outerInset,
          bottomGap + bottomPad,
        ),
        child: SizedBox(
          height: contentHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Match bump radius to rise so the crest sits at y = 0.
              final bumpRadius = bumpRise;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Soft ambient shadow under the whole dock
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 4,
                    height: barHeight * 0.7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.45 : 0.12),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dock shell with center bump
                  CustomPaint(
                    size: Size(width, contentHeight),
                    painter: _DockBumpPainter(
                      color: surface,
                      borderColor: borderColor,
                      bumpRadius: bumpRadius,
                      barHeight: barHeight,
                      isDark: isDark,
                    ),
                  ),

                  // Side actions row (sits on the flat bar)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: barHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          for (final action in left)
                            Expanded(
                              child: _BarItem(
                                action: action,
                                isDark: isDark,
                                onTap: () => _onActionTap(context, action),
                              ),
                            ),
                          SizedBox(width: fabSize + 16),
                          for (final action in right)
                            Expanded(
                              child: _BarItem(
                                action: action,
                                isDark: isDark,
                                onTap: () => _onActionTap(context, action),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Elevated primary (Billing) centered on the bump crest
                  if (primary != null)
                    Positioned(
                      top: bumpRise - fabSize / 2,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _PrimaryFab(
                          action: primary,
                          size: fabSize,
                          isDark: isDark,
                          onTap: () => _onActionTap(context, primary),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DockBumpPainter extends CustomPainter {
  _DockBumpPainter({
    required this.color,
    required this.borderColor,
    required this.bumpRadius,
    required this.barHeight,
    required this.isDark,
  });

  final Color color;
  final Color borderColor;
  final double bumpRadius;
  final double barHeight;
  final bool isDark;

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final barTop = h - barHeight;
    final cx = w / 2;
    const corner = AppTheme.radiusXl;
    final r = bumpRadius;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, barTop + corner)
      ..quadraticBezierTo(0, barTop, corner, barTop)
      ..lineTo(cx - r, barTop)
      // Convex bump — arc rises above the bar top to y ≈ 0.
      ..arcToPoint(
        Offset(cx + r, barTop),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(w - corner, barTop)
      ..quadraticBezierTo(w, barTop, w, barTop + corner)
      ..lineTo(w, h)
      ..close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
      isDark ? 14 : 10,
      true,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Subtle highlight along the bump crest
    final barTop = size.height - barHeight;
    final cx = size.width / 2;
    final r = bumpRadius;
    final highlight = Path()
      ..moveTo(cx - r + 6, barTop - 1)
      ..arcToPoint(
        Offset(cx + r - 6, barTop - 1),
        radius: Radius.circular(r - 4),
        clockwise: false,
      );
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white.withValues(alpha: isDark ? 0.07 : 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DockBumpPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.bumpRadius != bumpRadius ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.isDark != isDark;
  }
}

class _PrimaryFab extends StatefulWidget {
  const _PrimaryFab({
    required this.action,
    required this.size,
    required this.isDark,
    required this.onTap,
  });

  final HomeRadialAction action;
  final double size;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_PrimaryFab> createState() => _PrimaryFabState();
}

class _PrimaryFabState extends State<_PrimaryFab>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = widget.action;
    final enabled = action.enabled;
    final accent = action.accentColor;
    final size = widget.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = enabled ? 0.28 + (_pulse.value * 0.14) : 0.0;
          return AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Soft accent ring glow
                      if (enabled)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: glow),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(
                        width: size,
                        height: size,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: enabled
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(accent, Colors.white, 0.18)!,
                                      accent,
                                      Color.lerp(accent, Colors.black, 0.12)!,
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  )
                                : null,
                            color: enabled
                                ? null
                                : (widget.isDark
                                    ? AppColors.slate600
                                    : AppColors.slate200),
                            border: Border.all(
                              color: widget.isDark
                                  ? AppColors.slate800
                                  : Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: widget.isDark ? 0.45 : 0.16,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                              if (enabled)
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              action.icon,
                              size: 28,
                              color: enabled
                                  ? Colors.white
                                  : (widget.isDark
                                      ? Colors.white38
                                      : AppColors.slate500),
                            ),
                          ),
                        ),
                      ),
                      if (!enabled)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? AppColors.slate600
                                  : AppColors.slate500,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isDark
                                    ? AppColors.slate800
                                    : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.label,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1,
                    letterSpacing: -0.2,
                    color: enabled
                        ? accent
                        : (widget.isDark
                            ? Colors.white38
                            : AppColors.slate400),
                  ),
                ),
              ],
            ),
          );
        },
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
    final muted =
        isDark ? Colors.white.withValues(alpha: 0.32) : AppColors.slate400;
    final labelColor = enabled
        ? (isDark ? Colors.white.withValues(alpha: 0.88) : AppColors.slate700)
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: isDark ? 0.2 : 0.14),
                              accent.withValues(alpha: isDark ? 0.08 : 0.05),
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
                    size: 19,
                    color: enabled ? accent : muted,
                  ),
                ),
                if (!enabled)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
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
            const SizedBox(height: 4),
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
