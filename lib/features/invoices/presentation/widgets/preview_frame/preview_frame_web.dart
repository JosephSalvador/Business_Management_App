import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'preview_frame_platform.dart';

export 'preview_frame_platform.dart';

class DocumentPreviewFrameWeb implements DocumentPreviewFramePlatform {
  DocumentPreviewFrameWeb() {
    _initIframe();
  }

  web.HTMLIFrameElement? _iframe;
  String _currentViewType = '';
  static int _viewCounter = 0;
  String? _lastHtml;

  void _initIframe() {
    _viewCounter++;
    _currentViewType = 'document-preview-iframe-$_viewCounter';

    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.id = 'print-frame-container';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.border = 'none';
    iframe.style.backgroundColor = '#FFFFFF';
    iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts allow-modals');
    _iframe = iframe;

    ui_web.platformViewRegistry.registerViewFactory(
      _currentViewType,
      (int viewId) => iframe,
    );
  }

  void _injectHtml(String html, bool isThermal) {
    if (_iframe == null) return;
    _lastHtml = html;

    // Inject dedicated cashier print media queries and thermal styling
    final printCss = '''
<style>
@media print {
  body * { visibility: hidden; }
  #print-frame-container, #print-frame-container * { visibility: visible; }
  #print-frame-container { position: absolute; left: 0; top: 0; width: 100%; }
}
${isThermal ? '@page { size: 80mm auto; margin: 0; } body { width: 80mm; margin: 0 auto; }' : '@page { size: A4; margin: 12mm; }'}
</style>
''';

    final fullContent = html.contains('<head>')
        ? html.replaceFirst('<head>', '<head>$printCss')
        : '$printCss$html';

    _iframe!.srcdoc = fullContent.toJS;
  }

  @override
  Widget buildFrame({
    required BuildContext context,
    required String? htmlContent,
    required bool isThermal,
    required bool isLoading,
  }) {
    if (htmlContent != null && htmlContent != _lastHtml) {
      _injectHtml(htmlContent, isThermal);
    }

    // 80mm in CSS pixels at standard 96 DPI is ~302px
    final double targetWidth = isThermal ? 320 : double.infinity;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: targetWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isThermal ? 4 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isThermal ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            width: isThermal ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            HtmlElementView(viewType: _currentViewType),
            if (isLoading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> printDocument(String? htmlContent) async {
    if (_iframe != null && htmlContent != null) {
      try {
        _injectHtml(htmlContent, htmlContent.contains('80mm'));
        _iframe!.contentWindow?.focus();
        _iframe!.contentWindow?.print();
        return;
      } catch (_) {}
    }

    // Fallback if direct contentWindow.print is blocked
    if (htmlContent != null && htmlContent.isNotEmpty) {
      try {
        final printWindow = web.window.open('', '_blank', 'width=800,height=900');
        if (printWindow != null) {
          printWindow.document.open();
          printWindow.document.write(htmlContent.toJS);
          printWindow.document.close();
          printWindow.focus();
          web.window.setTimeout(
            ((JSObject _) {
              printWindow.print();
            }).toJS,
            300.toJS,
          );
        }
      } catch (_) {}
    }
  }
}

DocumentPreviewFramePlatform createDocumentPreviewFrame() =>
    DocumentPreviewFrameWeb();
