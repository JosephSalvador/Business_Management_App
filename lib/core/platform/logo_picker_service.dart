import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'logo_picker_stub.dart'
    if (dart.library.js_interop) 'logo_picker_web.dart' as platform_picker;

/// Cross-platform service for selecting, decoding, or generating a business logo.
abstract final class LogoPickerService {
  /// Opens the native gallery (Android) or file chooser (Web) and returns Base64 PNG/JPEG.
  static Future<String?> pickFromDevice() =>
      platform_picker.pickImageBase64FromDevice();

  /// Reads an image from a local file path (Desktop / Native fallback).
  static Future<String?> readFromFilePath(String path) =>
      platform_picker.readImageBase64FromFilePath(path);

  /// Decodes a stored Base64 or data-URI string into raw image bytes (`Uint8List`).
  static Uint8List? decodeLogoBytes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      var clean = raw.trim();
      final commaIndex = clean.indexOf(',');
      if (clean.startsWith('data:') && commaIndex >= 0) {
        clean = clean.substring(commaIndex + 1);
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(clean);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Generates a high-resolution, professional PNG monogram logo (240x240)
  /// from the business's initials and chosen brand color.
  /// Works 100% offline on every platform and embeds cleanly into A4 PDFs!
  static Future<String?> generateBrandMonogramBase64({
    required String businessName,
    required Color primaryColor,
    String? customInitials,
    bool roundedSquare = true,
  }) async {
    try {
      const size = 240.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

      final bgPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      if (roundedSquare) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 8, size - 16, size - 16),
            const Radius.circular(48),
          ),
          bgPaint,
        );
      } else {
        canvas.drawCircle(
          const Offset(size / 2, size / 2),
          (size - 16) / 2,
          bgPaint,
        );
      }

      // Subtle inner border ring for executive polish
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..isAntiAlias = true;

      if (roundedSquare) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 18, size - 36, size - 36),
            const Radius.circular(38),
          ),
          borderPaint,
        );
      } else {
        canvas.drawCircle(
          const Offset(size / 2, size / 2),
          (size - 36) / 2,
          borderPaint,
        );
      }

      final initials = (customInitials != null && customInitials.trim().isNotEmpty)
          ? customInitials.trim().toUpperCase()
          : _extractInitials(businessName);

      final textPainter = TextPainter(
        text: TextSpan(
          text: initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: initials.length > 2 ? 72 : 92,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size - 32);

      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static String _extractInitials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'BIZ';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : w;
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
