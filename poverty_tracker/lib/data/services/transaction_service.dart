import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<TransactionModel>> getTransactions() async {
    final data = await _client
        .from('transactions')
        .select()
        .eq('user_id', _userId)
        .order('date', ascending: false);

    return (data as List).map((e) => TransactionModel.fromJson(e)).toList();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _client.from('transactions').insert(transaction.toJson());
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _client
        .from('transactions')
        .update(transaction.toJson())
        .eq('id', transaction.id);
  }

  Future<Map<String, double>> getSummary() async {
    final data = await _client
        .from('transactions')
        .select()
        .eq('user_id', _userId);

    double income = 0;
    double expense = 0;

    for (final item in data as List) {
      final amount = (item['amount'] as num).toDouble();
      if (item['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }
}