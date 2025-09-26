import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  // Specific web detection
  static bool isWeb(BuildContext context) => kIsWeb;

  static bool isWebMobile(BuildContext context) => 
      kIsWeb && MediaQuery.of(context).size.width < 600;

  static bool isWebTablet(BuildContext context) => 
      kIsWeb && MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isWebDesktop(BuildContext context) => 
      kIsWeb && MediaQuery.of(context).size.width >= 1200;

  static double getContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (isWebDesktop(context)) {
      return 1400; // Wider for web desktop
    } else if (isDesktop(context)) {
      return 1200; // Desktop app
    } else if (isWebTablet(context)) {
      return 800; // Web tablet
    } else if (isTablet(context)) {
      return 800; // App tablet
    } else if (isWebMobile(context)) {
      return screenWidth * 0.95; // Web mobile
    } else {
      return screenWidth; // App mobile - full width
    }
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    if (isWebDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 40, vertical: 20);
    } else if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    } else if (isWebTablet(context) || isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(16);
    }
  }
}