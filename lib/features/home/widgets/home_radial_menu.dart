import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class HomeRadialAction {
  const HomeRadialAction({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
}

/// Bottom-center 3D hub that expands into a floating action dock.
class HomeRadialMenu extends StatefulWidget {
  const HomeRadialMenu({
    super.key,
    required this.actions,
  });

  final List<HomeRadialAction> actions;

  @override
  State<HomeRadialMenu> createState() => _HomeRadialMenuState();
}

class _HomeRadialMenuState extends State<HomeRadialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;

  static const double _hubSize = 64;
  static const double _dockGap = 18;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _expand = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isAnimating) return;
    HapticFeedback.lightImpact();
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _close() {
    if (_controller.value > 0) _controller.reverse();
  }

  void _onActionTap(HomeRadialAction action) {
    HapticFeedback.selectionClick();
    _controller.reverse();
    action.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final t = _expand.value.clamp(0.0, 1.0);
        final open = t > 0.001;
        // easeOutBack can overshoot slightly — clamp visual scale.
        final dockT = t.clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.38 * dockT),
                  ),
                ),
              ),
            // Hub stays anchored at bottom-center; dock floats above it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 12 + bottomPad,
              height: _hubSize,
              child: Center(
                child: _HubButton(
                  size: _hubSize,
                  progress: dockT,
                  onTap: _toggle,
                ),
              ),
            ),
            if (open)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12 + bottomPad + _hubSize + _dockGap,
                child: IgnorePointer(
                  ignoring: dockT < 0.55,
                  child: Opacity(
                    opacity: Curves.easeOut.transform(dockT),
                    child: Transform.translate(
                      offset: Offset(0, (1 - dockT) * 24),
                      child: Transform.scale(
                        scale: 0.9 + (0.1 * dockT),
                        alignment: Alignment.bottomCenter,
                        child: _ActionDock(
                          actions: widget.actions,
                          isDark: isDark,
                          progress: dockT,
                          onActionTap: _onActionTap,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.actions,
    required this.isDark,
    required this.progress,
    required this.onActionTap,
  });

  final List<HomeRadialAction> actions;
  final bool isDark;
  final double progress;
  final ValueChanged<HomeRadialAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF334155).withValues(alpha: 0.92),
                      const Color(0xFF1E293B).withValues(alpha: 0.96),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.94),
                      const Color(0xFFF1F5F9).withValues(alpha: 0.96),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppColors.indigo.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              // Top edge specular — fake 3D rim light.
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.55),
                blurRadius: 0,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++)
                Expanded(
                  child: _DockAction(
                    action: actions[i],
                    isDark: isDark,
                    // Stagger each orb popping in.
                    localProgress: ((progress - (i * 0.06)) / 0.7)
                        .clamp(0.0, 1.0),
                    onTap: () => onActionTap(actions[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.action,
    required this.isDark,
    required this.localProgress,
    required this.onTap,
  });

  final HomeRadialAction action;
  final bool isDark;
  final double localProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = 0.65 + (0.35 * Curves.easeOutBack.transform(localProgress));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: localProgress.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale.clamp(0.0, 1.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AccentOrb(
                icon: action.icon,
                accent: action.accentColor,
                size: 44,
              ),
              const SizedBox(height: 7),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.1,
                  letterSpacing: -0.1,
                  color: isDark ? Colors.white : AppColors.slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentOrb extends StatelessWidget {
  const _AccentOrb({
    required this.icon,
    required this.accent,
    required this.size,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, accent, 0.18)!,
            accent,
            Color.lerp(accent, Colors.black, 0.22)!,
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Specular highlight for 3D gloss.
          Positioned(
            top: 5,
            left: 8,
            child: Container(
              width: size * 0.38,
              height: size * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Icon(icon, color: Colors.white, size: size * 0.42),
        ],
      ),
    );
  }
}

class _HubButton extends StatefulWidget {
  const _HubButton({
    required this.size,
    required this.progress,
    required this.onTap,
  });

  final double size;
  final double progress;
  final VoidCallback onTap;

  @override
  State<_HubButton> createState() => _HubButtonState();
}

class _HubButtonState extends State<_HubButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.progress;
    final open = t > 0.5;
    final pressScale = _pressed ? 0.92 : 1.0;
    // Slight grow when open so the close affordance feels intentional.
    final openScale = 1.0 + (0.04 * t);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: pressScale * openScale,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    AppColors.indigoLight,
                    const Color(0xFF22D3EE),
                    t,
                  )!,
                  Color.lerp(AppColors.indigo, const Color(0xFF0891B2), t)!,
                  Color.lerp(
                    const Color(0xFF4338CA),
                    AppColors.indigo,
                    t,
                  )!,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 8,
                  left: 12,
                  child: Container(
                    width: widget.size * 0.42,
                    height: widget.size * 0.24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.125 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    open ? Icons.close_rounded : Icons.apps_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
