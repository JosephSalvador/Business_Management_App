/// Typed failures surfaced by [ApiClient]. Every HTTP problem the backend can
/// return (ProblemDetails envelope) or transport failure maps to exactly one
/// of these, so UI code never inspects raw responses.
sealed class AppException implements Exception {
  AppException(this.message);

  /// Safe, user-presentable message. Never contains tokens or stack traces.
  final String message;

  @override
  String toString() => message;
}

/// Device has no usable connection to the API (offline, DNS failure, etc.).
class NetworkException extends AppException {
  NetworkException([super.message = 'Hakuna muunganisho wa intaneti.']);
}

/// Request timed out.
class TimeoutException extends AppException {
  TimeoutException([super.message = 'Muunganisho umechukua muda mrefu.']);
}

/// 401 — session missing, expired, or refresh failed.
class UnauthorizedException extends AppException {
  UnauthorizedException([super.message = 'Kipindi kimeisha. Tafadhali ingia tena.']);
}

/// 403 — authenticated but not allowed to do this.
class ForbiddenException extends AppException {
  ForbiddenException([super.message = 'Hauna ruhusa ya kitendo hiki.']);
}

/// 404 — resource does not exist (or is not visible to this tenant).
class NotFoundException extends AppException {
  NotFoundException([super.message = 'Taarifa hazipatikani.']);
}

/// 409 — conflict with existing data (duplicate SKU, replayed idempotency key…).
class ConflictException extends AppException {
  ConflictException(super.message);
}

/// 400 — validation failed. [fieldErrors] maps field → messages when provided.
class ValidationException extends AppException {
  ValidationException(super.message, {this.fieldErrors = const {}});

  final Map<String, List<String>> fieldErrors;
}

/// 429 — rate limited.
class RateLimitException extends AppException {
  RateLimitException([super.message = 'Unaombi mno. Subiri kidogo ujaribu tena.']);
}

/// 5xx — backend failure. Message is generic; details stay in logs.
class ServerException extends AppException {
  ServerException([super.message = 'Hitilafu ya mfumo. Jaribu tena baadaye.']);
}

/// Anything unexpected (decode errors, unknown status codes…).
class UnknownException extends AppException {
  UnknownException([super.message = 'Hitilafu isiyotarajiwa. Jaribu tena.']);
}