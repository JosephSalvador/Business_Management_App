import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/features/auth/presentation/widgets/password_field.dart';

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
}
