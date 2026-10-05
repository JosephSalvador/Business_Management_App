import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Caches the branch ID locally after the first successful fetch from the API.
///
/// The branch ID is required for creating offline sales. Without caching,
/// the `posBranchIdProvider` makes an API call that fails when the backend
/// is unreachable, blocking offline sales even when the 72h window is open.
///
/// The cache is refreshed every time the API successfully returns branches.
/// On logout, the cache is cleared.
class BranchCache {
  BranchCache({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;
  String? _cached;

  static const _branchIdKey = 'jolinx.sales.branch_id';
  static const _branchNameKey = 'jolinx.sales.branch_name';

  /// Returns the cached branch ID without any network call.
  /// Returns null if no branch has ever been fetched.
  Future<String?> getCached() async {
    if (_cached != null) return _cached;
    _cached = await _storage.read(key: _branchIdKey);
    return _cached;
  }

  /// Returns the cached branch name for display purposes.
  Future<String?> getCachedName() async {
    return _storage.read(key: _branchNameKey);
  }

  /// Stores the branch ID after a successful API fetch.
  Future<void> store({
    required String branchId,
    String? branchName,
  }) async {
    _cached = branchId;
    await Future.wait([
      _storage.write(key: _branchIdKey, value: branchId),
      if (branchName != null)
        _storage.write(key: _branchNameKey, value: branchName),
    ]);
  }

  /// Validates that a cached branch ID still matches what the server reports.
  /// Returns true if the ID is valid, false if it should be refreshed.
  Future<bool> validate(String serverBranchId) async {
    final cached = await getCached();
    return cached == serverBranchId;
  }

  /// Clears the cache (on logout or when the server reports a different branch).
  Future<void> clear() async {
    _cached = null;
    await Future.wait([
      _storage.delete(key: _branchIdKey),
      _storage.delete(key: _branchNameKey),
    ]);
  }
}
