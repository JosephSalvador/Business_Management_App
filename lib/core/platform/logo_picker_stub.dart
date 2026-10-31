import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _mediaPickerChannel =
    MethodChannel('com.jolinx.app/media_picker');

/// Native implementation for picking an image from gallery (Android) or local filesystem.
Future<String?> pickImageBase64FromDevice() async {
  try {
    if (Platform.isAndroid) {
      final base64 =
          await _mediaPickerChannel.invokeMethod<String>('pickImageBase64');
      if (base64 != null && base64.trim().isNotEmpty) {
        return base64.trim();
      }
      return null;
    }
  } catch (_) {
    // Fallback if channel not available
  }
  return null;
}

/// Reads an image file from a local path on desktop/mobile and returns Base64.
Future<String?> readImageBase64FromFilePath(String filePath) async {
  try {
    final file = File(filePath.trim());
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return base64Encode(bytes);
  } catch (_) {
    return null;
  }
}
