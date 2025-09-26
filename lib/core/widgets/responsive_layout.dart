import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout(
      {super.key, required this.mobile, this.tablet, this.desktop});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Responsive.isDesktop(context) && desktop != null) {
          return desktop!;
        } else if (Responsive.isTablet(context) && tablet != null) {
          return tablet!;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? Responsive.getContentWidth(context),
        ),
        child: child,
      ),
      
    );
  }
}
