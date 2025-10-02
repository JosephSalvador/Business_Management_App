// services/printer_storage_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_model.dart';

class PrinterStorageService {
  static const String _savedPrinterKey = 'saved_printer';
  static const String _defaultPrinterKey = 'default_printer';

  // Save a printer as the default
  static Future<void> saveDefaultPrinter(SavedPrinter printer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printerJson = printer.toJson();
      await prefs.setString(_defaultPrinterKey, json.encode(printerJson));
      print('💾 Saved default printer: ${printer.name}');
    } catch (e) {
      print('❌ Failed to save printer: $e');
    }
  }

  // Get the saved default printer
  static Future<SavedPrinter?> getDefaultPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printerJson = prefs.getString(_defaultPrinterKey);
      
      if (printerJson != null) {
        final Map<String, dynamic> data = json.decode(printerJson);
        return SavedPrinter.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ Failed to load saved printer: $e');
      return null;
    }
  }

  // Clear the saved printer
  static Future<void> clearDefaultPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_defaultPrinterKey);
      print('🗑️ Cleared default printer');
    } catch (e) {
      print('❌ Failed to clear printer: $e');
    }
  }

  // Check if we have a saved printer
  static Future<bool> hasDefaultPrinter() async {
    final printer = await getDefaultPrinter();
    return printer != null;
  }
}