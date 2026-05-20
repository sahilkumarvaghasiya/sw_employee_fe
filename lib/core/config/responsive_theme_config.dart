import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Responsive theme configuration for consistent styling across screen sizes
class ResponsiveThemeConfig {
  /// Standard border radius values that adapt to screen size
  static BorderRadius getCardBorderRadius(BuildContext context) {
    final radius = context.isSmallScreen ? 12.0 : 16.0;
    return BorderRadius.circular(radius);
  }

  /// Get elevation based on screen size (smaller on small screens)
  static double getCardElevation(BuildContext context) {
    return context.isSmallScreen ? 0 : 1;
  }

  /// Get button height adapted to screen size
  static double getButtonHeight(BuildContext context) {
    return context.isSmallScreen ? 44.0 : 48.0;
  }

  /// Get dialog inset padding for all screen sizes
  static EdgeInsets getDialogInsetPadding(BuildContext context) {
    final width = context.screenWidth;
    final horizontal = ResponsiveDesign.getHorizontalPadding(context) * 2;

    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: ResponsiveDesign.paddingDefault,
    );
  }

  /// Get bottom sheet max width
  static double getBottomSheetMaxWidth(BuildContext context) {
    final width = context.screenWidth;
    if (width >= ResponsiveDesign.tabletMinWidth) {
      return ResponsiveDesign.largePhoneMaxWidth;
    }
    return width;
  }

  /// Get floating action button size
  static Size getFABSize(BuildContext context) {
    return context.isSmallScreen
        ? const Size(48, 48) // Regular FAB on small screens
        : const Size(56, 56); // Extended FAB size on larger screens
  }

  /// Get app bar height
  static double getAppBarHeight(BuildContext context) {
    return context.isSmallScreen ? 56.0 : 64.0;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, IconSize size) {
    if (context.isSmallScreen) {
      return size.value * 0.9;
    }
    return size.value;
  }

  /// Get list tile padding
  static EdgeInsets getListTilePadding(BuildContext context) {
    final horizontal = ResponsiveDesign.paddingDefault;
    final vertical = context.isSmallScreen
        ? ResponsiveDesign.paddingSmall
        : ResponsiveDesign.paddingMedium;

    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  /// Get card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    final padding = context.isSmallScreen
        ? ResponsiveDesign.paddingSmall
        : ResponsiveDesign.paddingDefault;

    return EdgeInsets.all(padding);
  }

  /// Get bottom navigation height
  static double getBottomNavHeight(BuildContext context) {
    return context.isSmallScreen ? 56.0 : 64.0;
  }
}

/// Common icon sizes
enum IconSize {
  small(16),
  medium(24),
  large(32),
  extraLarge(48);

  final double value;
  const IconSize(this.value);
}

/// Responsive text theme extension
class ResponsiveTextTheme {
  static TextStyle getDisplayLarge(BuildContext context, TextTheme textTheme) {
    final baseStyle = textTheme.displayLarge;
    if (context.isSmallScreen) {
      return baseStyle?.copyWith(fontSize: 28) ?? const TextStyle();
    }
    return baseStyle ?? const TextStyle();
  }

  static TextStyle getTitleLarge(BuildContext context, TextTheme textTheme) {
    final baseStyle = textTheme.titleLarge;
    if (context.isSmallScreen) {
      return baseStyle?.copyWith(fontSize: 18) ?? const TextStyle();
    }
    return baseStyle ?? const TextStyle();
  }

  static TextStyle getBodyMedium(BuildContext context, TextTheme textTheme) {
    final baseStyle = textTheme.bodyMedium;
    if (context.isSmallScreen) {
      return baseStyle?.copyWith(fontSize: 12) ?? const TextStyle();
    }
    return baseStyle ?? const TextStyle();
  }
}
