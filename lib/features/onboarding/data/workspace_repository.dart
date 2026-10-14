import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/workspace.dart';

/// Payload for completing tenant onboarding.
class OnboardingDraft {
  const OnboardingDraft({
    required this.name,
    required this.businessType,
    required this.countryCode,
    required this.currency,
    this.contactPhone,
    this.taxId,
  });

  final String name;
  final String businessType;
  final String countryCode;
  final String currency;
  final String? contactPhone;
  final String? taxId;

  Map<String, dynamic> toBody() => {
        'name': name.trim(),
        'businessType': businessType.trim().toLowerCase(),
        'countryCode': countryCode.trim().toUpperCase(),
        'currency': currency.trim().toUpperCase(),
        if (contactPhone != null && contactPhone!.trim().isNotEmpty)
          'contactPhone': contactPhone!.trim(),
        if (taxId != null && taxId!.trim().isNotEmpty) 'taxId': taxId!.trim(),
      };
}

/// Reads and completes the signed-in user's workspaces against
/// `/api/v1/workspaces/mine` and `/api/v1/organization/onboarding`.
class WorkspaceRepository {
  WorkspaceRepository({
    required ApiClient apiClient,
    FlutterSecureStorage? storage,
  })  : _apiClient = apiClient,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  static const _cachedWorkspaceKey = 'jolinx.workspace.cached_selected';

  /// Returns locally cached workspace for instant cold start hydration.
  Future<Workspace?> getCachedWorkspace() async {
    try {
      final raw = await _storage.read(key: _cachedWorkspaceKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return Workspace.fromJson(map);
      }
    } catch (_) {
      // Corrupt or outdated cache is non-fatal
    }
    return null;
  }

  /// Persists selected workspace locally for optimistic startup.
  Future<void> saveCachedWorkspace(Workspace workspace) async {
    try {
      final encoded = jsonEncode(workspace.toJson());
      await _storage.write(key: _cachedWorkspaceKey, value: encoded);
    } catch (_) {
      // Storage write failures are non-fatal
    }
  }

  /// Clears cached workspace on session loss/logout.
  Future<void> clearCachedWorkspace() async {
    try {
      await _storage.delete(key: _cachedWorkspaceKey);
    } catch (_) {
      // Non-fatal
    }
  }

  /// Workspaces derived from the session's tenant claim. At least one entry
  /// exists for every authenticated user (registration provisions a tenant).
  Future<List<Workspace>> mine() async {
    final response = await _apiClient.get<dynamic>('/api/v1/workspaces/mine');
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Workspace.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  /// Completes tenant onboarding; returns the refreshed workspace.
  Future<Workspace> completeOnboarding(OnboardingDraft draft) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/organization/onboarding',
      body: draft.toBody(),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Workspace.fromJson(
      Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
    );
  }
}
