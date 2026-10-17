import 'dart:typed_data';

/// Common interface for Web Bluetooth thermal printing.
abstract class WebBluetoothPrinterPlatform {
  bool get isSupported;
  Future<bool> printBytes(Uint8List bytes);
}
