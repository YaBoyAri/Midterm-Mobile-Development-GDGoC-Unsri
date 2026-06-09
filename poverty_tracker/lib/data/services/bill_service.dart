import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill_model.dart';

class BillService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  Future<List<BillModel>> getBills() async {
    final data = await _client
        .from('bills')
        .select()
        .eq('user_id', _userId)
        .order('due_date', ascending: true);

    return (data as List).map((e) => BillModel.fromJson(e)).toList();
  }

  Future<void> addBill(BillModel bill) async {
    await _client.from('bills').insert(bill.toJson());
  }

  Future<void> togglePaid(String id, bool isPaid) async {
    await _client
        .from('bills')
        .update({'is_paid': isPaid})
        .eq('id', id);
  }

  Future<void> deleteBill(String id) async {
    await _client.from('bills').delete().eq('id', id);
  }
}