import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/authentication/presentation/widgets/password_field.dart';

void main() {
  group('scorePassword', () {
    test('empty input is empty', () {
      expect(scorePassword(''), PasswordStrength.empty);
    });

    test('short single-class password is weak', () {
      expect(scorePassword('abc'), PasswordStrength.weak);
    });

    test('length plus one class is fair', () {
      expect(scorePassword('longpassword'), PasswordStrength.fair);
    });

    test('policy-compliant password is good', () {
      expect(scorePassword('Passw0rd!'), PasswordStrength.good);
    });

    test('long policy-compliant password is strong', () {
      expect(scorePassword('LongerPassw0rd!'), PasswordStrength.strong);
    });
  });

  group('PasswordRequirements', () {
    test('rejects password without special character', () {
      final req = PasswordRequirements.check('Jolinx12345');
      expect(req.hasMinLength, isTrue);
      expect(req.hasUppercase, isTrue);
      expect(req.hasLowercase, isTrue);
      expect(req.hasDigit, isTrue);
      expect(req.hasSpecial, isFalse);
      expect(req.isMet, isFalse);
    });

    test('rejects password without uppercase letter', () {
      final req = PasswordRequirements.check('jolinx12345!');
      expect(req.hasUppercase, isFalse);
      expect(req.isMet, isFalse);
    });

    test('rejects password without lowercase letter', () {
      final req = PasswordRequirements.check('JOLINX12345!');
      expect(req.hasLowercase, isFalse);
      expect(req.isMet, isFalse);
    });

    test('rejects password without number', () {
      final req = PasswordRequirements.check('JolinxPass!');
      expect(req.hasDigit, isFalse);
      expect(req.isMet, isFalse);
    });

    test('rejects short password', () {
      final req = PasswordRequirements.check('J1!a');
      expect(req.hasMinLength, isFalse);
      expect(req.isMet, isFalse);
    });

    test('accepts fully compliant password', () {
      final req = PasswordRequirements.check('Jolinx12345!');
      expect(req.hasMinLength, isTrue);
      expect(req.hasUppercase, isTrue);
      expect(req.hasLowercase, isTrue);
      expect(req.hasDigit, isTrue);
      expect(req.hasSpecial, isTrue);
      expect(req.isMet, isTrue);
    });
  });
}

