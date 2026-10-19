/// Common interface for universal browser-based receipt printing.
abstract class BrowserPrinterPlatform {
  bool get isSupported;
  Future<bool> printHtml(String html);
}
