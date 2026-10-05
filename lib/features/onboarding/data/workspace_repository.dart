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
  WorkspaceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

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
