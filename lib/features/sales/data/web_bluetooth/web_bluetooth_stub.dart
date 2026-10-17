import 'dart:typed_data';

/// Common interface for Web Bluetooth thermal printing.
abstract class WebBluetoothPrinterPlatform {
  bool get isSupported;
  Future<bool> printBytes(Uint8List bytes);
}

/// Stub implementation for non-web platforms.
class WebBluetoothPrinterStub implements WebBluetoothPrinterPlatform {
  @override
  bool get isSupported => false;

  @override
  Future<bool> printBytes(Uint8List bytes) async => false;
}

WebBluetoothPrinterPlatform createWebBluetoothPrinter() =>
    WebBluetoothPrinterStub();
