import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Maps transport-level [DioException]s plus backend ProblemDetails envelopes
/// onto the typed [AppException] hierarchy.
///
/// Backend failure contract (see `backend/src/API/Http/ResultExtensions.cs`):
/// `{ "title": "<Code>", "detail": "<message>", "status": <int>, "code": "<Code>",
///    "errors": { "<field>": ["<message>"] } }`
AppException mapDioException(DioException error) {
  final response = error.response;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
      return NetworkException();
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return TimeoutException();
    case DioExceptionType.badCertificate:
      return NetworkException('Muunganisho si salama.');
    case DioExceptionType.cancel:
      return UnknownException('Ombi limefutwa.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  if (response == null) {
    return NetworkException();
  }
  return mapErrorResponse(response.statusCode, response.data);
}

AppException mapErrorResponse(int? statusCode, dynamic data) {
  final parsed = _ProblemDetails.parse(data);
  final message = parsed.detail;
  final status = statusCode ?? 0;

  switch (status) {
    case 400:
      return ValidationException(
        message ?? 'Taarifa zilizoingizwa si sahihi.',
        fieldErrors: parsed.errors,
      );
    case 401:
      return UnauthorizedException(
        message ?? 'Barua pepe au neno la siri si sahihi.',
      );
    case 403:
      return ForbiddenException();
    case 404:
      return NotFoundException();
    case 409:
      return ConflictException(message ?? 'Kuna mgongano na taarifa zilizopo.');
    case 429:
      return RateLimitException();
    case >= 500:
      return ServerException();
    default:
      return UnknownException(message ?? 'Hitilafu isiyotarajiwa. Jaribu tena.');
  }
}

class _ProblemDetails {
  const _ProblemDetails(this.detail, this.errors);

  final String? detail;
  final Map<String, List<String>> errors;

  static _ProblemDetails parse(dynamic data) {
    if (data is! Map) {
      return const _ProblemDetails(null, {});
    }

    final detail = data['detail'] is String ? data['detail'] as String : null;

    final rawErrors = data['errors'];
    final errors = <String, List<String>>{};
    if (rawErrors is Map) {
      rawErrors.forEach((key, value) {
        if (key is String && value is List) {
          errors[key] = value.whereType<String>().toList();
        }
      });
    }

    return _ProblemDetails(detail, errors);
  }
}
