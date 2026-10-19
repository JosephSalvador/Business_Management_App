import 'browser_printer_platform.dart';

export 'browser_printer_platform.dart';

/// Stub implementation for non-web platforms.
class BrowserPrinterStub implements BrowserPrinterPlatform {
  @override
  bool get isSupported => false;

  @override
  Future<bool> printHtml(String html) async => false;
}

BrowserPrinterPlatform createBrowserPrinter() => BrowserPrinterStub();
