import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'browser_printer_platform.dart';

export 'browser_printer_platform.dart';

class BrowserPrinterWeb implements BrowserPrinterPlatform {
  @override
  bool get isSupported => true;

  @override
  Future<bool> printHtml(String html) async {
    final completer = Completer<bool>();

    try {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.position = 'fixed';
      iframe.style.right = '0';
      iframe.style.bottom = '0';
      iframe.style.width = '0';
      iframe.style.height = '0';
      iframe.style.border = '0';

      iframe.srcdoc = html.toJS;

      iframe.addEventListener(
        'load',
        ((web.Event _) {
          try {
            iframe.contentWindow?.focus();
            iframe.contentWindow?.print();
            if (!completer.isCompleted) completer.complete(true);
          } catch (_) {
            if (!completer.isCompleted) {
              completer.complete(_fallbackPrint(html));
            }
          } finally {
            web.window.setTimeout(
              ((JSObject _) {
                iframe.remove();
              }).toJS,
              3000.toJS,
            );
          }
        }).toJS,
      );

      web.document.body?.appendChild(iframe);

      // Fallback timeout in case 'load' event doesn't fire
      web.window.setTimeout(
        ((JSObject _) {
          if (!completer.isCompleted) {
            completer.complete(_fallbackPrint(html));
          }
        }).toJS,
        1500.toJS,
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(_fallbackPrint(html));
      }
    }

    return completer.future;
  }

  bool _fallbackPrint(String html) {
    try {
      final printWindow = web.window.open('', '_blank', 'width=420,height=600');
      if (printWindow != null) {
        printWindow.document.open();
        printWindow.document.write(html.toJS);
        printWindow.document.close();
        printWindow.focus();
        web.window.setTimeout(
          ((JSObject _) {
            printWindow.print();
          }).toJS,
          400.toJS,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}

BrowserPrinterPlatform createBrowserPrinter() => BrowserPrinterWeb();
