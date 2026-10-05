import 'package:flutter/material.dart';
import '../design_system/responsive.dart';

/// Provides mobile/tablet/desktop layout switching.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (Responsive.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Constrains content width on large screens, centers it.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? Responsive.getPagePadding(context);
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? Responsive.getContentWidth(context),
        ),
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

/// Shows different widgets based on screen size, with a shared constrained width.
class ResponsiveScaffold extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? centerTitle;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;

  const ResponsiveScaffold({
    super.key,
    this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.centerTitle,
    this.appBar,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAppBar = appBar ??
        (title != null
            ? AppBar(
                title: Text(title!),
                actions: actions,
                centerTitle: centerTitle,
              )
            : null);

    return Scaffold(
      appBar: effectiveAppBar,
      body: ResponsiveContainer(
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
    );
  }
}
