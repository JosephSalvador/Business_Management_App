import 'package:flutter/material.dart';

/// Responsive layout utilities.
///
/// Breakpoints:
/// - Mobile:  0 – 599px
/// - Tablet:  600 – 1023px
/// - Desktop: 1024px+
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;
  static const double desktopContentMax = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1440;

  /// Screen width.
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// Screen height.
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Navigation type for current context.
  static NavigationType navigationType(BuildContext context) {
    if (isDesktop(context)) return NavigationType.side;
    if (isTablet(context)) return NavigationType.side;
    return NavigationType.bottom;
  }

  /// Columns for dashboard/grid usage.
  static int gridColumns(BuildContext context) {
    if (isWideDesktop(context)) return 5;
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }

  /// Cross-axis count for product/item grids.
  static int itemCountCrossAxis(BuildContext context) {
    if (isWideDesktop(context)) return 6;
    if (isDesktop(context)) return 5;
    if (isTablet(context)) return 4;
    return 3;
  }

  /// Constrain content width on large screens.
  static double getContentWidth(BuildContext context) {
    if (isWideDesktop(context)) return 1400;
    if (isDesktop(context)) return desktopContentMax;
    if (isTablet(context)) return 900;
    return double.infinity;
  }

  /// Page padding.
  static EdgeInsets getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
    if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
  }

  /// Standard gap between elements.
  static double gap(BuildContext context) {
    if (isMobile(context)) return 12;
    if (isTablet(context)) return 16;
    return 20;
  }

  /// Card padding.
  static EdgeInsets getCardPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
  }
}

enum NavigationType { bottom, side, rail }
