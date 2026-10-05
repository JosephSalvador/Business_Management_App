import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/expenses_controller.dart';
import 'expense_repository.dart';

export '../application/expenses_controller.dart'
    show ExpensesState, ExpensesLoading, ExpensesLoaded, ExpensesFailure;

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(apiClient: ref.watch(apiClientProvider)),
);

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategory>>(
  (ref) => ref.watch(expenseRepositoryProvider).listCategories(),
);

final expensesControllerProvider =
    NotifierProvider<ExpensesController, ExpensesState>(
  ExpensesController.new,
);
