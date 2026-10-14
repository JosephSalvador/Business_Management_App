/// One business (tenant) the signed-in user belongs to, as returned by
/// `GET /api/v1/workspaces/mine` and `POST /api/v1/organization/onboarding`.
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.currency,
    required this.countryCode,
    required this.businessType,
    required this.onboardingComplete,
    required this.roles,
  });

  final String id;
  final String name;

  /// ISO-4217 code, e.g. `TZS`.
  final String currency;

  /// ISO-3166 alpha-2 code, e.g. `TZ`.
  final String countryCode;
  final String? businessType;
  final bool onboardingComplete;
  final List<String> roles;

  bool get isAdmin => roles.contains('Administrator');

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      businessType: json['businessType'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'countryCode': countryCode,
        'businessType': businessType,
        'onboardingComplete': onboardingComplete,
        'roles': roles,
      };
}
