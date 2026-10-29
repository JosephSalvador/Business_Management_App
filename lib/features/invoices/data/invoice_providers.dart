import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart' show offlineCacheDaoProvider;
import '../../authentication/data/auth_providers.dart';
import 'invoice_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(
    apiClient: ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheDaoProvider),
  ),
);
