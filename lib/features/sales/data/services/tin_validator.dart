import 'dart:convert';
import 'package:business_management_system/features/sales/data/models/sale_models.dart';
import 'package:http/http.dart' as http;

class TinValidator {
  static const String _testBaseUrl = 'https://vfdtest.tra.go.tz/api/VatCheck';
  static String _accessToken = '';

  static Future<TinValidationResult> validateTin(String tin) async {
    try {
      final response = await http.get(
        Uri.parse('$_testBaseUrl/CheckVatStatusFull/$tin'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return TinValidationResult(
          taxpayerId: data['taxpayerId']?.toString() ?? '',
          firstName: data['firstName'] ?? '',
          middleName: data['middleName'] ?? '',
          lastName: data['lastName'] ?? '',
          tradingName: data['tradingName'] ?? '',
          hasVAT: data['hasVAT'] ?? false,
          vrn: data['vrn'],
          isValid: true,
        );
      } else {
        return TinValidationResult(
          taxpayerId: '',
          firstName: '',
          middleName: '',
          lastName: '',
          tradingName: '',
          hasVAT: false,
          vrn: null,
          isValid: false,
        );
      }
    } catch (e) {
      // For demo purposes, return mock data
      return _getMockTinValidation(tin);
    }
  }

  static TinValidationResult _getMockTinValidation(String tin) {
    // Mock TIN validation for demonstration
    final mockData = {
      '123456789': TinValidationResult(
        taxpayerId: '123456789',
        firstName: 'JOHN',
        middleName: 'DAVID',
        lastName: 'SMITH',
        tradingName: 'SMITH ENTERPRISES LTD',
        hasVAT: true,
        vrn: '123456789001',
        isValid: true,
      ),
      '987654321': TinValidationResult(
        taxpayerId: '987654321',
        firstName: 'MARY',
        middleName: 'ANNE',
        lastName: 'JOHNSON',
        tradingName: 'JOHNSON TRADING',
        hasVAT: false,
        vrn: null,
        isValid: true,
      ),
    };

    return mockData[tin] ?? TinValidationResult(
      taxpayerId: tin,
      firstName: '',
      middleName: '',
      lastName: '',
      tradingName: '',
      hasVAT: false,
      vrn: null,
      isValid: false,
    );
  }

  static void setAccessToken(String token) {
    _accessToken = token;
  }
}