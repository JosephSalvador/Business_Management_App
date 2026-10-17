import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'web_bluetooth_stub.dart';

@JS('window')
external JSObject get _window;

/// Known thermal printer BLE Service UUIDs (Standard, Xprinter, ISSC, Generic)
const _printerServiceUuids = [
  '000018f0-0000-1000-8000-00805f9b34fb',
  '0000ffe0-0000-1000-8000-00805f9b34fb',
  '49535343-fe7d-4ae5-8fa9-9fafd205e455',
  'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
];

/// Known write characteristic UUIDs
const _printerCharacteristicUuids = [
  '00002af1-0000-1000-8000-00805f9b34fb',
  '0000ffe1-0000-1000-8000-00805f9b34fb',
  '49535343-8841-43f4-a8d4-ecbe34729bb3',
  'bef8d6c9-9c21-4c9e-b632-bd58c1009f9f',
];

class WebBluetoothPrinterWeb implements WebBluetoothPrinterPlatform {
  @override
  bool get isSupported {
    try {
      if (!_window.has('navigator')) return false;
      final nav = _window.getProperty('navigator'.toJS) as JSObject?;
      return nav != null && nav.has('bluetooth');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> printBytes(Uint8List bytes) async {
    if (!isSupported) return false;

    try {
      final nav = _window.getProperty('navigator'.toJS) as JSObject;
      final bluetooth = nav.getProperty('bluetooth'.toJS) as JSObject;

      // 1. Build options: acceptAllDevices with optionalServices
      final options = JSObject();
      options.setProperty('acceptAllDevices'.toJS, true.toJS);

      final servicesList =
          [for (final uuid in _printerServiceUuids) uuid.toJS].toJS;
      options.setProperty('optionalServices'.toJS, servicesList);

      // 2. Request device (user picks their thermal printer in browser dialog)
      final requestPromise = bluetooth.callMethod(
        'requestDevice'.toJS,
        options,
      ) as JSPromise<JSObject>;
      final device = await requestPromise.toDart;

      // 3. Connect to GATT Server
      final gatt = device.getProperty('gatt'.toJS) as JSObject;
      final connectPromise = gatt.callMethod('connect'.toJS) as JSPromise<JSObject>;
      final server = await connectPromise.toDart;

      // 4. Discover the printer primary service
      JSObject? targetService;
      for (final uuid in _printerServiceUuids) {
        try {
          final getServicePromise = server.callMethod(
            'getPrimaryService'.toJS,
            uuid.toJS,
          ) as JSPromise<JSObject>;
          targetService = await getServicePromise.toDart;
          break;
        } catch (_) {}
      }

      if (targetService == null) {
        // Fallback: try getting all services
        final getServicesPromise =
            server.callMethod('getPrimaryServices'.toJS) as JSPromise<JSArray>;
        final allServices = await getServicesPromise.toDart;
        if (allServices.toDart.isNotEmpty) {
          targetService = allServices.toDart.first as JSObject;
        }
      }

      if (targetService == null) return false;

      // 5. Discover write characteristic
      JSObject? targetCharacteristic;
      for (final charUuid in _printerCharacteristicUuids) {
        try {
          final getCharPromise = targetService.callMethod(
            'getCharacteristic'.toJS,
            charUuid.toJS,
          ) as JSPromise<JSObject>;
          targetCharacteristic = await getCharPromise.toDart;
          break;
        } catch (_) {}
      }

      if (targetCharacteristic == null) {
        final getCharsPromise = targetService
            .callMethod('getCharacteristics'.toJS) as JSPromise<JSArray>;
        final allChars = await getCharsPromise.toDart;
        for (final charObj in allChars.toDart) {
          final char = charObj as JSObject;
          final properties = char.getProperty('properties'.toJS) as JSObject?;
          if (properties != null) {
            final canWrite = properties.getProperty('write'.toJS).dartify() == true ||
                properties.getProperty('writeWithoutResponse'.toJS).dartify() == true;
            if (canWrite) {
              targetCharacteristic = char;
              break;
            }
          }
        }
      }

      if (targetCharacteristic == null) return false;

      // 6. MTU chunking: Send in 40-byte slices with 20ms pause
      const chunkSize = 40;
      final total = bytes.length;
      var offset = 0;

      while (offset < total) {
        final end = (offset + chunkSize < total) ? offset + chunkSize : total;
        final chunk = bytes.sublist(offset, end);
        final jsBuffer = chunk.toJS;

        try {
          if (targetCharacteristic.has('writeValueWithoutResponse')) {
            final writePromise = targetCharacteristic.callMethod(
              'writeValueWithoutResponse'.toJS,
              jsBuffer,
            ) as JSPromise<JSAny?>;
            await writePromise.toDart;
          } else {
            final writePromise = targetCharacteristic.callMethod(
              'writeValue'.toJS,
              jsBuffer,
            ) as JSPromise<JSAny?>;
            await writePromise.toDart;
          }
        } catch (_) {
          // Fallback to writeValue
          final writePromise = targetCharacteristic.callMethod(
            'writeValue'.toJS,
            jsBuffer,
          ) as JSPromise<JSAny?>;
          await writePromise.toDart;
        }

        offset = end;
        if (offset < total) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}

WebBluetoothPrinterPlatform createWebBluetoothPrinter() =>
    WebBluetoothPrinterWeb();
