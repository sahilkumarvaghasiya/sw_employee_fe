import 'package:flutter/material.dart';

/// Responsive design utilities for the RetailAgent app.
///
/// This utility class provides responsive sizing and breakpoints
/// to ensure consistent layouts across all phone sizes.
class ResponsiveDesign {
  /// Screen breakpoints (in logical pixels)
  static const double smallPhoneMaxWidth = 360;
  static const double mediumPhoneMaxWidth = 480;
  static const double largePhoneMaxWidth = 600;
  static const double tabletMinWidth = 600;

  /// Standard padding and spacing values
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingDefault = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  /// Get the appropriate padding for screen width
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallPhoneMaxWidth) {
      return paddingSmall; // Extra small phones (320dp)
    } else if (width < mediumPhoneMaxWidth) {
      return paddingDefault; // Small phones (360dp)
    } else if (width < largePhoneMaxWidth) {
      return paddingDefault; // Medium phones (480dp)
    } else {
      return paddingLarge; // Large phones and tablets (600dp+)
    }
  }

  /// Determine if layout should be single or multi-column
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < smallPhoneMaxWidth;
  }

  /// Determine if screen is medium sized (phones)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= smallPhoneMaxWidth && width < tabletMinWidth;
  }

  /// Determine if screen is large (tablets and large phones)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMinWidth;
  }

  /// Get responsive font scale factor
  static double getFontScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallPhoneMaxWidth) {
      return 0.9; // Slightly smaller fonts for tiny screens
    } else if (width < mediumPhoneMaxWidth) {
      return 1.0; // Standard size
    } else {
      return 1.1; // Slightly larger for bigger screens
    }
  }

  /// Get responsive grid column count
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallPhoneMaxWidth) {
      return 2; // 2 columns on very small phones
    } else if (width < mediumPhoneMaxWidth) {
      return 2; // 2 columns on small phones
    } else if (width < largePhoneMaxWidth) {
      return 3; // 3 columns on medium phones
    } else {
      return 4; // 4 columns on tablets
    }
  }

  /// Get responsive child aspect ratio for grid
  static double getGridChildAspectRatio(
    BuildContext context, {
    double defaultRatio = 1.2,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallPhoneMaxWidth) {
      return 0.9; // More square on small screens
    } else {
      return defaultRatio; // Standard ratio on larger screens
    }
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get safe area padding considering system UI (notches, etc)
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final media = MediaQuery.of(context);
    return EdgeInsets.only(
      top: media.padding.top,
      bottom: media.padding.bottom,
      left: media.padding.left,
      right: media.padding.right,
    );
  }

  /// Get maximum content width for better readability on large screens
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // On large screens, limit content width to improve readability
    if (width > largePhoneMaxWidth) {
      return largePhoneMaxWidth - (paddingDefault * 2);
    }
    return width - (paddingDefault * 2);
  }

  /// Calculate responsive field width for forms
  static double getFormFieldWidth(BuildContext context, {int columns = 2}) {
    final maxWidth = getMaxContentWidth(context);
    final spacing = paddingMedium * (columns - 1);
    return (maxWidth - spacing) / columns;
  }
}

/// Extension methods for easier access to responsive values
extension ResponsiveContext on BuildContext {
  /// Get the width of the screen
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get the height of the screen
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if small screen
  bool get isSmallScreen => ResponsiveDesign.isSmallScreen(this);

  /// Check if medium screen
  bool get isMediumScreen => ResponsiveDesign.isMediumScreen(this);

  /// Check if large screen
  bool get isLargeScreen => ResponsiveDesign.isLargeScreen(this);

  /// Check if landscape
  bool get isLandscape => ResponsiveDesign.isLandscape(this);

  /// Get horizontal padding
  double get horizontalPadding => ResponsiveDesign.getHorizontalPadding(this);

  /// Get grid columns
  int get gridColumns => ResponsiveDesign.getGridColumns(this);

  /// Get device pixel ratio
  double get devicePixelRatio => MediaQuery.of(this).devicePixelRatio;

  /// Get safe area padding
  EdgeInsets get safeAreaPadding => ResponsiveDesign.getSafeAreaPadding(this);
}
