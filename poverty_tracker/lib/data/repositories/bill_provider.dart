import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_model.dart';
import '../services/bill_service.dart';

final billServiceProvider =
    Provider<BillService>((ref) => BillService());

final billsProvider = FutureProvider<List<BillModel>>((ref) async {
  return ref.watch(billServiceProvider).getBills();
});