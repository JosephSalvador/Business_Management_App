import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Hardware-backed biometric gate for offline credential access.
///
/// On Android this uses [BiometricPrompt] backed by TEE/StrongBox.
/// On iOS this uses [LAContext] backed by the Secure Enclave.
/// On web/desktop without biometrics, [isAvailable] returns false and
/// [authenticate] returns false — callers must handle gracefully.
class BiometricAuthGate {
  BiometricAuthGate({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether the device has biometric hardware AND enrolled credentials.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Prompts the user for fingerprint/face authentication.
  ///
  /// [reason] is shown in the system prompt (e.g. "Thibitisha utambulisho
  /// ili kuuza nje ya mtandao").
  ///
  /// Returns true only on a genuine biometric match. On platforms without
  /// biometrics or when the user cancels, returns false.
  Future<bool> authenticate({required String reason}) async {
    try {
      final available = await isAvailable();
      if (!available) return false;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types (fingerprint, face, iris).
  Future<List<BiometricType>> enrolledTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Returns user-friendly biometric label adapted to the device's hardware.
  Future<String> biometricLabel() async {
    final types = await enrolledTypes();
    if (types.contains(BiometricType.face)) {
      return 'Utambuzi wa Uso (Face ID)';
    }
    if (types.contains(BiometricType.fingerprint)) {
      return 'Alama ya Kidole (Fingerprint)';
    }
    if (types.contains(BiometricType.iris)) {
      return 'Utambuzi wa Jicho (Iris)';
    }
    return 'Alama ya Kidole au Uso';
  }
}

