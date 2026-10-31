import 'package:flutter/material.dart';

/// Standard breakpoint enum for enterprise POS responsive matrices:
/// - Phone (< 768px)
/// - Tablet (768px – 1023px)
/// - Desktop (>= 1024px)
enum EnterpriseScreenCategory {
  phone,
  tablet,
  desktop;

  bool get isPhone => this == EnterpriseScreenCategory.phone;
  bool get isTablet => this == EnterpriseScreenCategory.tablet;
  bool get isDesktop => this == EnterpriseScreenCategory.desktop;
}

typedef EnterpriseLayoutWidgetBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
  EnterpriseScreenCategory category,
);

/// A structured responsive layout switcher implementing the enterprise POS
/// breakpoint matrix:
/// - Phones: width < 768px
/// - Tablets: 768px <= width < 1024px
/// - Desktop: width >= 1024px
class ResponsiveLayoutBuilder extends StatelessWidget {
  const ResponsiveLayoutBuilder({
    super.key,
    required this.builder,
    this.phone,
    this.tablet,
    this.desktop,
  });

  /// Flexible builder providing the resolved category and box constraints.
  final EnterpriseLayoutWidgetBuilder builder;

  /// Optional direct widget slots.
  final Widget? phone;
  final Widget? tablet;
  final Widget? desktop;

  static const double phoneMax = 768.0;
  static const double tabletMax = 1024.0;

  static EnterpriseScreenCategory resolveCategory(double width) {
    if (width < phoneMax) return EnterpriseScreenCategory.phone;
    if (width < tabletMax) return EnterpriseScreenCategory.tablet;
    return EnterpriseScreenCategory.desktop;
  }

  static EnterpriseScreenCategory of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return resolveCategory(width);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final category = resolveCategory(constraints.maxWidth);

        if (category == EnterpriseScreenCategory.desktop && desktop != null) {
          return desktop!;
        }
        if (category == EnterpriseScreenCategory.tablet && tablet != null) {
          return tablet!;
        }
        if (category == EnterpriseScreenCategory.phone && phone != null) {
          return phone!;
        }

        return builder(context, constraints, category);
      },
    );
  }
}
