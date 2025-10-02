
import 'package:flutter/material.dart';

class MobileProviderService {
  static final Map<String, MobileProvider> _prefixToProvider = {
    '74': MobileProvider.vodacom,
    '75': MobileProvider.vodacom,
    '76': MobileProvider.vodacom,
    '68': MobileProvider.airtel,
    '78': MobileProvider.airtel,
    '79': MobileProvider.airtel,
    '69': MobileProvider.airtel,
    '71': MobileProvider.tigo,
    '65': MobileProvider.tigo,
    '67': MobileProvider.tigo,
    '62': MobileProvider.halotel,
    '61': MobileProvider.halotel,
  };

  /// Identifies the mobile network provider based on the phone number
  static MobileProviderInfo identifyProvider(String phoneNumber) {
    // Clean the phone number - remove spaces, dashes, and country code
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-+]'), '');
    
    // Remove country code if present
    if (cleanNumber.startsWith('255')) {
      cleanNumber = cleanNumber.substring(3);
    }
    
    // Ensure we have a valid Tanzanian number
    if (cleanNumber.length < 9) {
      return MobileProviderInfo(
        provider: MobileProvider.unknown,
        confidence: 0.0,
        formattedNumber: phoneNumber,
      );
    }
    
    // Extract the prefix (2-3 digits after the leading 0)
    String prefix = cleanNumber;
    if (cleanNumber.startsWith('0')) {
      prefix = cleanNumber.substring(1);
    }
    
    // Try 2-digit prefix first
    if (prefix.length >= 2) {
      String twoDigitPrefix = prefix.substring(0, 2);
      MobileProvider? provider = _prefixToProvider[twoDigitPrefix];
      
      if (provider != null) {
        return MobileProviderInfo(
          provider: provider,
          confidence: 0.9,
          formattedNumber: _formatNumber(cleanNumber),
          prefix: twoDigitPrefix,
        );
      }
    }
    
    // Try 3-digit prefix if 2-digit didn't match
    if (prefix.length >= 3) {
      String threeDigitPrefix = prefix.substring(0, 3);
      MobileProvider? provider = _prefixToProvider[threeDigitPrefix];
      
      if (provider != null) {
        return MobileProviderInfo(
          provider: provider,
          confidence: 0.8,
          formattedNumber: _formatNumber(cleanNumber),
          prefix: threeDigitPrefix,
        );
      }
    }
    
    // Unknown provider
    return MobileProviderInfo(
      provider: MobileProvider.unknown,
      confidence: 0.0,
      formattedNumber: _formatNumber(cleanNumber),
    );
  }

  /// Formats the phone number to Tanzanian standard format
  static String _formatNumber(String cleanNumber) {
    if (cleanNumber.startsWith('0') && cleanNumber.length == 10) {
      return '+255 ${cleanNumber.substring(1, 4)} ${cleanNumber.substring(4, 7)} ${cleanNumber.substring(7)}';
    } else if (cleanNumber.length == 9) {
      return '+255 ${cleanNumber.substring(0, 3)} ${cleanNumber.substring(3, 6)} ${cleanNumber.substring(6)}';
    }
    return cleanNumber;
  }

  /// Gets provider logo/icon
  static IconData getProviderIcon(MobileProvider provider) {
    switch (provider) {
      case MobileProvider.vodacom:
        return Icons.sim_card;
      case MobileProvider.airtel:
        return Icons.signal_cellular_alt;
      case MobileProvider.tigo:
        return Icons.network_cell;
      case MobileProvider.halotel:
        return Icons.phone_android;
      case MobileProvider.unknown:
        return Icons.help_outline;
    }
  }

  /// Gets provider color
  static Color getProviderColor(MobileProvider provider) {
    switch (provider) {
      case MobileProvider.vodacom:
        return Colors.red;
      case MobileProvider.airtel:
        return const Color(0xFFE20074); // Airtel red/pink
      case MobileProvider.tigo:
        return Colors.orange;
      case MobileProvider.halotel:
        return Colors.green;
      case MobileProvider.unknown:
        return Colors.grey;
    }
  }

  /// Gets provider name
  static String getProviderName(MobileProvider provider) {
    switch (provider) {
      case MobileProvider.vodacom:
        return 'Vodacom';
      case MobileProvider.airtel:
        return 'Airtel';
      case MobileProvider.tigo:
        return 'Tigo';
      case MobileProvider.halotel:
        return 'Halotel';
      case MobileProvider.unknown:
        return 'Unknown Provider';
    }
  }
}

enum MobileProvider {
  vodacom,
  airtel,
  tigo,
  halotel,
  unknown,
}

class MobileProviderInfo {
  final MobileProvider provider;
  final double confidence; // 0.0 to 1.0
  final String formattedNumber;
  final String? prefix;

  const MobileProviderInfo({
    required this.provider,
    required this.confidence,
    required this.formattedNumber,
    this.prefix,
  });

  String get providerName => MobileProviderService.getProviderName(provider);
  IconData get providerIcon => MobileProviderService.getProviderIcon(provider);
  Color get providerColor => MobileProviderService.getProviderColor(provider);

  @override
  String toString() {
    return 'MobileProviderInfo(provider: $provider, confidence: $confidence, formattedNumber: $formattedNumber, prefix: $prefix)';
  }
}