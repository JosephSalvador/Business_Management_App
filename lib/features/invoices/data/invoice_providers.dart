import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart'
    show
        deviceIdentityProvider,
        localDatabaseProvider,
        offlineCacheDaoProvider;
import '../../../core/storage/sync_queue_dao.dart';
import '../../authentication/data/auth_providers.dart';
import '../../sales/data/sales_providers.dart'
    show posBranchIdProvider, sessionContextProvider;
import 'delivery_note_repository.dart';
import 'document_template_repository.dart';
import 'invoice_repository.dart';

final syncQueueDaoProvider = Provider<SyncQueueDao>(
  (ref) => SyncQueueDao(ref.watch(localDatabaseProvider)),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) {
    SyncQueueDao? queue;
    try {
      queue = ref.watch(syncQueueDaoProvider);
    } catch (_) {}
    return InvoiceRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: ref.watch(offlineCacheDaoProvider),
      queue: queue,
      tenantIdOf: () async => ref.read(sessionContextProvider).$1,
      branchIdOf: () => ref.read(posBranchIdProvider)(),
      deviceIdOf: () => ref.read(deviceIdentityProvider).get(),
    );
  },
);

final deliveryNoteRepositoryProvider = Provider<DeliveryNoteRepository>(
  (ref) {
    SyncQueueDao? queue;
    try {
      queue = ref.watch(syncQueueDaoProvider);
    } catch (_) {}
    return DeliveryNoteRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: ref.watch(offlineCacheDaoProvider),
      queue: queue,
      tenantIdOf: () async => ref.read(sessionContextProvider).$1,
      branchIdOf: () => ref.read(posBranchIdProvider)(),
      deviceIdOf: () => ref.read(deviceIdentityProvider).get(),
    );
  },
);

final documentTemplateRepositoryProvider = Provider<DocumentTemplateRepository>(
  (ref) => DocumentTemplateRepository(
    apiClient: ref.watch(apiClientProvider),
  ),
);
