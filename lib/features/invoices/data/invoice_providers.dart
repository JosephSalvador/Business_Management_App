import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart' show offlineCacheDaoProvider;
import '../../authentication/data/auth_providers.dart';
import 'document_template_repository.dart';
import 'invoice_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(
    apiClient: ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheDaoProvider),
  ),
);

final documentTemplateRepositoryProvider = Provider<DocumentTemplateRepository>(
  (ref) => DocumentTemplateRepository(
    apiClient: ref.watch(apiClientProvider),
  ),
);
