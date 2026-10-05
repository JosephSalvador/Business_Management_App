import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import 'billing_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(apiClient: ref.watch(apiClientProvider));
});
