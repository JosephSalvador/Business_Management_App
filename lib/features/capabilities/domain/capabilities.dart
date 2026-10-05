enum WorkspaceModule {
  pos(id: 'pos', featureKey: 'pos.enabled', isBackstop: true),
  inventory(id: 'inventory', featureKey: 'inventory.enabled', isBackstop: true),
  purchasing(
      id: 'purchasing', featureKey: 'purchasing.enabled', isBackstop: false),
  accounting(
      id: 'accounting', featureKey: 'accounting.enabled', isBackstop: false),
  finance(id: 'finance', featureKey: 'finance.enabled', isBackstop: false),
  crm(id: 'crm', featureKey: 'crm.enabled', isBackstop: false),
  credit(id: 'credit', featureKey: 'credit.enabled', isBackstop: false),
  pricing(id: 'pricing', featureKey: 'pricing.enabled', isBackstop: false),
  invoicing(
      id: 'invoicing', featureKey: 'invoicing.enabled', isBackstop: false),
  reports(id: 'reports', featureKey: 'reports.enabled', isBackstop: false);

  const WorkspaceModule({
    required this.id,
    required this.featureKey,
    required this.isBackstop,
  });

  final String id;
  final String featureKey;
  final bool isBackstop;

  static WorkspaceModule? byId(String id) {
    for (final module in values) {
      if (module.id == id) return module;
    }
    return null;
  }
}

abstract final class WorkspaceCapabilityKeys {
  static const multiBranch = 'multi-branch.enabled';

  static const all = <String>{
    'pos.enabled',
    'inventory.enabled',
    'purchasing.enabled',
    'accounting.enabled',
    'finance.enabled',
    'crm.enabled',
    'credit.enabled',
    'pricing.enabled',
    'invoicing.enabled',
    'reports.enabled',
    'multi-branch.enabled',
  };
}

enum CapabilitiesSource { network, cache, fallback }
