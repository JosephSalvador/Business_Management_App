// widgets/printer_selection_dialog.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/bluetooth_printer_service.dart';
import '../../data/models/sale_models.dart';

class PrinterSelectionDialog extends StatefulWidget {
  final Sale sale;

  const PrinterSelectionDialog({super.key, required this.sale});

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  BluetoothDevice? _selectedDevice;
  bool _isConnecting = false;
  bool _isPrinting = false;
  String _statusMessage = 'Initializing...';
  StreamSubscription<List<BluetoothDevice>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    BluetoothPrinterService.stopScan();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    setState(() {
      _statusMessage = 'Checking permissions...';
    });

    final hasPermissions = await BluetoothPrinterService.checkPermissions();
    if (!hasPermissions) {
      setState(() {
        _statusMessage = 'Bluetooth permissions required';
      });
      return;
    }

    final isAvailable = await BluetoothPrinterService.isBluetoothAvailable();
    if (!isAvailable) {
      setState(() {
        _statusMessage = 'Bluetooth not available';
      });
      return;
    }

    final isOn = await BluetoothPrinterService.isBluetoothOn();
    if (!isOn) {
      setState(() {
        _statusMessage = 'Please turn on Bluetooth';
      });
      return;
    }

    _startScan();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices = [];
      _statusMessage = 'Scanning for Bluetooth devices...';
    });

    _scanSubscription = BluetoothPrinterService.discoverPrinters().listen(
      (devices) {
        setState(() {
          _devices = devices;
          _statusMessage = 'Found ${devices.length} devices - Try connecting to MPTII or any device';
        });
      },
      onError: (error) {
        setState(() {
          _statusMessage = 'Scan error: $error';
          _isScanning = false;
        });
      },
    );

    // Auto-stop after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          if (_devices.isEmpty) {
            _statusMessage = 'No devices found. Make sure your printer is on and discoverable.';
          } else {
            _statusMessage = 'Scan completed. Select your printer (MPTII)';
          }
        });
        BluetoothPrinterService.stopScan();
      }
    });
  }

  Future<void> _connectAndPrint(BluetoothDevice printer) async {
  setState(() {
    _isConnecting = true;
  });

  try {
    // Connect to printer
    await BluetoothPrinterService.connectToDevice(printer);
    
    // Print using the new chunking method
    await BluetoothPrinterService.printToDevice(printer, widget.sale);
    
    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt printed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isConnecting = false;
        _isPrinting = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.print,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'Select Bluetooth Device',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            if (_isScanning)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Discovering Bluetooth devices...'),
                ],
              )
            else if (_devices.isEmpty)
              Column(
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No Bluetooth devices found',
                    style: GoogleFonts.inter(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure your printer (MPTII) is turned on and in pairing mode',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startScan,
                    child: const Text('Scan Again'),
                  ),
                ],
              )
            else
              SizedBox(
                height: 200,
                child: Column(
                  children: [
                    Text(
                      'Found ${_devices.length} devices - Try MPTII:',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final name = device.platformName.isEmpty 
                              ? 'Unknown Device' 
                              : device.platformName;
                          final isMPTII = name.toLowerCase().contains('mptii');
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isMPTII ? Colors.blue.shade50 : null,
                            child: ListTile(
                              leading: Icon(
                                isMPTII ? Icons.print : Icons.device_unknown,
                                color: isMPTII ? Colors.blue : Colors.grey,
                              ),
                              title: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontWeight: isMPTII ? FontWeight.bold : FontWeight.normal,
                                  color: isMPTII ? Colors.blue : Colors.black,
                                ),
                              ),
                              subtitle: Text(device.remoteId.str),
                              trailing: _isConnecting && _selectedDevice == device
                                  ? const CircularProgressIndicator()
                                  : IconButton(
                                      icon: const Icon(Icons.print),
                                      onPressed: _isPrinting ? null : () => _connectAndPrint(device),
                                      color: isMPTII ? Colors.blue : Colors.grey,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      BluetoothPrinterService.stopScan();
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}