import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';

void main() {
  group('AppConfig', () {
    test('accepts http only in dev environment', () {
      final config = AppConfig.forTest(
        environment: AppEnvironment.dev,
        apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
      );
      expect(config.isDev, isTrue);
    });

    test('rejects plain http outside dev', () {
      expect(
        () => AppConfig.forTest(
          environment: AppEnvironment.production,
          apiBaseUrl: Uri.parse('http://api.jolinx.example'),
        ),
        throwsStateError,
      );
    });

    test('accepts https in production', () {
      final config = AppConfig.forTest(
        environment: AppEnvironment.production,
        apiBaseUrl: Uri.parse('https://api.jolinx.example'),
      );
      expect(config.apiBaseUrl.scheme, 'https');
    });
  });

  group('ApiClient redaction helpers', () {
    test('redacts Authorization headers before logging', () {
      final redacted = ApiClient.redactHeaders({
        'Authorization': 'Bearer super-secret-token',
        'Accept': 'application/json',
      });
      expect(redacted['Authorization'], '<redacted>');
      expect(redacted['Accept'], 'application/json');
      expect(redacted.values.any((v) => v.contains('super-secret')), isFalse);
    });
  });

  group('AppException messages', () {
    test('are user-presentable Swahili strings without internals', () {
      final exceptions = <AppException>[
        NetworkException(),
        TimeoutException(),
        UnauthorizedException(),
        ForbiddenException(),
        NotFoundException(),
        RateLimitException(),
        ServerException(),
      ];
      for (final exception in exceptions) {
        expect(exception.message, isNotEmpty);
        expect(exception.toString(), exception.message);
        // Never leak English stack/technical detail in the message.
        expect(
          exception.message.toLowerCase().contains('exception'),
          isFalse,
        );
      }
    });
  });
}
