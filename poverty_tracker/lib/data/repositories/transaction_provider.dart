import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

final transactionServiceProvider =
    Provider<TransactionService>((ref) => TransactionService());

final transactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  return ref.watch(transactionServiceProvider).getTransactions();
});

final summaryProvider = FutureProvider<Map<String, double>>((ref) async {
  return ref.watch(transactionServiceProvider).getSummary();
});