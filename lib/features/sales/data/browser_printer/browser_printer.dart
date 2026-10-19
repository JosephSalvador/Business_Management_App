import 'browser_printer_stub.dart'
    if (dart.library.js_interop) 'browser_printer_web.dart';

export 'browser_printer_platform.dart';

final BrowserPrinterPlatform browserPrinter = createBrowserPrinter();
