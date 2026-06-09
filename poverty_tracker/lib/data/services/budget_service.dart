import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/budget_model.dart';

class BudgetService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  Future<List<BudgetModel>> getBudgets(String month) async {
    final data = await _client
        .from('budgets')
        .select()
        .eq('user_id', _userId)
        .eq('month', month);

    return (data as List).map((e) => BudgetModel.fromJson(e)).toList();
  }

  Future<void> addBudget(BudgetModel budget) async {
    await _client.from('budgets').insert(budget.toJson());
  }

  Future<void> deleteBudget(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }

  Future<Map<String, double>> getSpendingByCategory(String month) async {
    final start = '$month-01';
    final lastDay = DateTime(
      int.parse(month.split('-')[0]),
      int.parse(month.split('-')[1]) + 1,
      0,
    ).day;
    final end = '$month-$lastDay';

    final data = await _client
        .from('transactions')
        .select()
        .eq('user_id', _userId)
        .eq('type', 'expense')
        .gte('date', start)
        .lte('date', end);

    final Map<String, double> spending = {};
    for (final item in data as List) {
      final cat = item['category'] as String;
      final amount = (item['amount'] as num).toDouble();
      spending[cat] = (spending[cat] ?? 0) + amount;
    }
    return spending;
  }
}