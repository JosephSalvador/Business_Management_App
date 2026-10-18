import 'package:flutter/foundation.dart';

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

/// Detects the client operating system on non-web platforms.
DetectedOs detectDeviceOs() {
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
bool isAppInstalledPwa() => false;

/// Triggers direct download or navigation to the external download URL.
void openExternalDownloadUrl(String url) {
  // Stub for non-web environments (handled by native download/launchers if needed)
}
