import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/budget_model.dart';
import '../services/budget_service.dart';

final budgetServiceProvider =
    Provider<BudgetService>((ref) => BudgetService());

final currentMonthProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM').format(DateTime.now());
});

final budgetsProvider = FutureProvider<List<BudgetModel>>((ref) async {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(budgetServiceProvider).getBudgets(month);
});

final spendingByCategoryProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(budgetServiceProvider).getSpendingByCategory(month);
});