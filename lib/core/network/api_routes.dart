/// Single source of truth for backend API paths.
///
/// CONVENTION (matches `MapGroup("/api/v{version:apiVersion}")` in
/// `backend/src/API`):
/// - [ApiClient] baseUrl points at the server ROOT (no path suffix).
/// - Versioned business endpoints are addressed via [v1]:
///   `ApiRoutes.v1('/branches')` → `/api/v1/branches`.
/// - Infrastructure probes (health) live OUTSIDE the versioned prefix and
///   use their own constants below.
abstract final class ApiRoutes {
  static const String apiPrefix = '/api/v1';

  /// Builds a versioned API path: [path] must start with '/'.
  static String v1(String path) {
    assert(path.startsWith('/'), 'API paths must start with /');
    return '$apiPrefix$path';
  }

  // Infrastructure endpoints (unversioned, unauthenticated by design).
  static const String healthLive = '/health/live';
  static const String healthReady = '/health/ready';
}
