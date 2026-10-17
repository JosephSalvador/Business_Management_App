import 'package:web/web.dart' as web;

/// Checks if the client is running inside Mobile Safari on iOS (and not already in standalone mode).
bool isIosSafariBrowser() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isIos = userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
  final isSafari = userAgent.contains('safari') &&
      !userAgent.contains('crios') &&
      !userAgent.contains('fxios') &&
      !userAgent.contains('chrome') &&
      !userAgent.contains('android');

  if (!isIos || !isSafari) return false;

  return !isStandalonePwa();
}

/// Checks if the current web app is operating as a full-screen installed PWA.
bool isStandalonePwa() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}
