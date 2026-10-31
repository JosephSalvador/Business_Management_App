import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web implementation using HTMLInputElement (type="file", accept="image/*").
Future<String?> pickImageBase64FromDevice() async {
  final completer = Completer<String?>();
  try {
    final input =
        web.document.createElement('input') as web.HTMLInputElement
          ..type = 'file'
          ..accept = 'image/png,image/jpeg,image/webp';

    input.onchange = ((web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final reader = web.FileReader();
      reader.onload = ((web.Event _) {
        final result = reader.result;
        if (result != null && result.isA<JSString>()) {
          final dataUrl = (result as JSString).toDart;
          final commaIdx = dataUrl.indexOf(',');
          final rawBase64 =
              commaIdx >= 0 ? dataUrl.substring(commaIdx + 1) : dataUrl;
          if (!completer.isCompleted) completer.complete(rawBase64.trim());
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      }).toJS;
      reader.onerror = ((web.Event _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;
      reader.readAsDataURL(file);
    }).toJS;

    input.click();
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

Future<String?> readImageBase64FromFilePath(String filePath) async => null;
