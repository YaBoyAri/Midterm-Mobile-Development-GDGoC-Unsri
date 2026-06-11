import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bill_model.dart';
import '../../data/repositories/bill_provider.dart';

class BillScreen extends ConsumerWidget {
  const BillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);
    final formatter = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(billsProvider),
        child: billsAsync.when(
          data: (bills) {
            final unpaid = bills.where((b) => !b.isPaid).toList();
            final paid = bills.where((b) => b.isPaid).toList();

            if (bills.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 64,
                        color: AppTheme.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text('Belum ada tagihan',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (unpaid.isNotEmpty) ...[
                  const Text(
                    'Belum Dibayar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unpaid.map((bill) => _BillItem(
                        bill: bill,
                        formatter: formatter,
                        onToggle: () async {
                          await ref
                              .read(billServiceProvider)
                              .togglePaid(bill.id, true);
                          ref.invalidate(billsProvider);
                        },
                        onDelete: () async {
                          await ref
                              .read(billServiceProvider)
                              .deleteBill(bill.id);
                          ref.invalidate(billsProvider);
                        },
                      )),
                  const SizedBox(height: 24),
                ],
                if (paid.isNotEmpty) ...[
                  const Text(
                    'Sudah Dibayar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...paid.map((bill) => _BillItem(
                        bill: bill,
                        formatter: formatter,
                        onToggle: () async {
                          await ref
                              .read(billServiceProvider)
                              .togglePaid(bill.id, false);
                          ref.invalidate(billsProvider);
                        },
                        onDelete: () async {
                          await ref
                              .read(billServiceProvider)
                              .deleteBill(bill.id);
                          ref.invalidate(billsProvider);
                        },
                      )),
                ],
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBillDialog(context, ref),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddBillDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Tagihan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Tagihan',
                  hintText: 'Contoh: Listrik, Netflix, dll',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => dueDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Jatuh tempo: ${DateFormat('dd MMMM yyyy', 'id_ID').format(dueDate)}',
                        style:
                            const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        amountController.text.isEmpty) return;
                    final bill = BillModel(
                      id: '',
                      userId: Supabase.instance.client.auth.currentUser!.id,
                      name: nameController.text,
                      amount: double.parse(amountController.text),
                      dueDate: dueDate,
                      isPaid: false,
                    );
                    await ref.read(billServiceProvider).addBill(bill);
                    ref.invalidate(billsProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillItem extends StatelessWidget {
  final BillModel bill;
  final NumberFormat formatter;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _BillItem({
    required this.bill,
    required this.formatter,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        !bill.isPaid && bill.dueDate.isBefore(DateTime.now());

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Tagihan'),
            content: const Text('Yakin ingin menghapus tagihan ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.expense),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            onDelete();
            return true;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal menghapus: $e'),
                  backgroundColor: AppTheme.expense,
                ),
              );
            }
            return false;
          }
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isOverdue
              ? Border.all(color: AppTheme.expense.withOpacity(0.5))
              : null,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bill.isPaid
                      ? AppTheme.income
                      : Colors.transparent,
                  border: Border.all(
                    color: bill.isPaid
                        ? AppTheme.income
                        : AppTheme.textSecondary,
                    width: 2,
                  ),
                ),
                child: bill.isPaid
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      decoration: bill.isPaid
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Text(
                    'Jatuh tempo: ${DateFormat('dd MMM yyyy').format(bill.dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? AppTheme.expense
                          : AppTheme.textSecondary,
                    ),
                  ),
                  if (isOverdue)
                    const Text(
                      '⚠️ Sudah lewat jatuh tempo!',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.expense),
                    ),
                ],
              ),
            ),
            Text(
              formatter.format(bill.amount),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}