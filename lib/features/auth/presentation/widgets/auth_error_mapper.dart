import '../../../../core/network/app_exception.dart';

/// Result of translating an [AppException] into per-field form errors.
class AuthFieldErrors {
  AuthFieldErrors({this.fieldErrors = const {}, this.banner});

  /// Field name (backend casing) → first message for that field.
  final Map<String, String> fieldErrors;

  /// Form-wide message when the failure is not tied to one field.
  final String? banner;

  bool get isEmpty => fieldErrors.isEmpty && banner == null;
}

/// Maps backend validation failures onto the auth forms' fields. The API
/// reports PascalCase property names; the lookup accepts any of [candidates]
/// so pages can bind several spellings to one input.
AuthFieldErrors mapAuthError(AppException error) {
  if (error is ValidationException && error.fieldErrors.isNotEmpty) {
    return AuthFieldErrors(
      fieldErrors: {
        for (final entry in error.fieldErrors.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.first,
      },
      banner: error.fieldErrors.isEmpty ? error.message : null,
    );
  }
  if (error is ConflictException) {
    // Duplicate email/phone/business-name arrive as plain 409s.
    final message = error.message.toLowerCase();
    if (message.contains('email')) {
      return AuthFieldErrors(fieldErrors: {'Email': error.message});
    }
    if (message.contains('phone')) {
      return AuthFieldErrors(fieldErrors: {'Phone': error.message});
    }
    if (message.contains('business name') || message.contains('organization')) {
      return AuthFieldErrors(
          fieldErrors: {'OrganizationName': error.message});
    }
  }
  return AuthFieldErrors(banner: error.message);
}

/// Returns the first error message recorded under any of [candidates].
String? errorForField(AuthFieldErrors errors, List<String> candidates) {
  for (final candidate in candidates) {
    final message = errors.fieldErrors[candidate];
    if (message != null) {
      return message;
    }
  }
  return null;
}
