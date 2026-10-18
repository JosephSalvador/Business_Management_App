import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

enum DetectedOs {
  android,
  ios,
  windows,
  macos,
  linux,
  unknown;

  bool get isMobile => this == DetectedOs.android || this == DetectedOs.ios;
  bool get isDesktop =>
      this == DetectedOs.windows ||
      this == DetectedOs.macos ||
      this == DetectedOs.linux;
}

/// Detects the client operating system by parsing the browser user-agent and platform capabilities.
DetectedOs detectDeviceOs() {
  try {
    final nav = web.window.navigator;
    final ua = nav.userAgent.toLowerCase();

    // 1. Android mobile / tablet
    if (ua.contains('android')) {
      return DetectedOs.android;
    }

    // 2. iOS (iPhone, iPod, iPad including iPadOS desktop Safari mode)
    final isIosDevice = ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        (ua.contains('macintosh') && nav.maxTouchPoints > 1);
    if (isIosDevice) {
      return DetectedOs.ios;
    }

    // 3. Windows PC
    if (ua.contains('windows') || ua.contains('win32') || ua.contains('win64')) {
      return DetectedOs.windows;
    }

    // 4. macOS
    if (ua.contains('macintosh') || ua.contains('mac os x')) {
      return DetectedOs.macos;
    }

    // 5. Linux desktop
    if (ua.contains('linux') || ua.contains('x11')) {
      return DetectedOs.linux;
    }
  } catch (_) {
    // Fallback if browser navigator is restricted
  }

  // Fallback to Flutter's compile-time platform heuristic
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return DetectedOs.android;
    case TargetPlatform.iOS:
      return DetectedOs.ios;
    case TargetPlatform.windows:
      return DetectedOs.windows;
    case TargetPlatform.macOS:
      return DetectedOs.macos;
    case TargetPlatform.linux:
      return DetectedOs.linux;
    default:
      return DetectedOs.unknown;
  }
}

/// Checks if currently running as an installed standalone PWA.
bool isAppInstalledPwa() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

/// Triggers direct download or navigation to the external download URL in the browser.
void openExternalDownloadUrl(String url) {
  try {
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = '';
    anchor.target = '_blank';
    anchor.rel = 'noopener noreferrer';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {
    web.window.open(url, '_blank');
  }
}
