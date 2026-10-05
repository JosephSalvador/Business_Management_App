import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/customers_controller.dart';
import 'customer_repository.dart';

export '../application/customers_controller.dart'
    show CustomersState, CustomersLoading, CustomersLoaded, CustomersFailure;

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(apiClient: ref.watch(apiClientProvider)),
);

final customersControllerProvider =
    NotifierProvider<CustomersController, CustomersState>(
  CustomersController.new,
);
