import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any screen or view to listen for rapid keystrokes emitted by
/// dedicated USB, Bluetooth HID, or 2.4GHz RF wireless hardware barcode scanners.
///
/// Hardware scanners emit characters with intervals < 50ms followed by an
/// Enter or Tab terminator. This listener captures the sequence without
/// requiring an active text-field focus.
class HardwareScannerListener extends StatefulWidget {
  const HardwareScannerListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.maxCharIntervalMs = 65,
    this.minBarcodeLength = 3,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final int maxCharIntervalMs;
  final int minBarcodeLength;
  final bool enabled;

  @override
  State<HardwareScannerListener> createState() =>
      _HardwareScannerListenerState();
}

class _HardwareScannerListenerState extends State<HardwareScannerListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeystrokeTime;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void didUpdateWidget(HardwareScannerListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        HardwareKeyboard.instance.addHandler(_handleKeyEvent);
      } else {
        HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return false;
    }

    final now = DateTime.now();
    final char = event.character;

    // Check for scanner terminator keys (Enter or Tab)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_buffer.length >= widget.minBarcodeLength &&
          _lastKeystrokeTime != null &&
          now.difference(_lastKeystrokeTime!).inMilliseconds <=
              (widget.maxCharIntervalMs * 2)) {
        final barcode = _buffer.toString().trim();
        _buffer.clear();
        _lastKeystrokeTime = null;
        if (barcode.isNotEmpty) {
          widget.onBarcodeScanned(barcode);
          return true; // Swallow the Enter key event so it doesn't trigger UI buttons
        }
      }
      _buffer.clear();
      _lastKeystrokeTime = null;
      return false;
    }

    if (char != null &&
        char.isNotEmpty &&
        char != '\n' &&
        char != '\r' &&
        char != '\t') {
      if (_lastKeystrokeTime == null) {
        _buffer.clear();
        _buffer.write(char);
      } else {
        final diff = now.difference(_lastKeystrokeTime!).inMilliseconds;
        if (diff <= widget.maxCharIntervalMs) {
          _buffer.write(char);
        } else {
          // Slow human typing or fresh scan sequence
          _buffer.clear();
          _buffer.write(char);
        }
      }
      _lastKeystrokeTime = now;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
