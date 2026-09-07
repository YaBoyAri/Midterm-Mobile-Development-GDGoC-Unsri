import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bill_model.dart';
import '../../data/repositories/bill_provider.dart';
import '../../data/services/notification_service.dart';

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
        color: AppTheme.primaryLight,
        backgroundColor: AppTheme.surfaceVariant,
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
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.receipt_text,
                          size: 48, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text('Belum ada tagihan',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 4),
                    const Text('Tambahkan tagihan rutin kamu',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ).animate().fadeIn();
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                if (unpaid.isNotEmpty) ...[
                  // Unpaid summary pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.warning.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.warning_2,
                            size: 16, color: AppTheme.warning),
                        const SizedBox(width: 6),
                        Text(
                          '${unpaid.length} tagihan belum dibayar',
                          style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 16),
                  ...unpaid.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BillItem(
                          bill: entry.value,
                          formatter: formatter,
                          onToggle: () async {
                            await ref
                                .read(billServiceProvider)
                                .togglePaid(entry.value.id, true);
                            ref.invalidate(billsProvider);
                            // Refresh bill notifications
                            final updatedBills = await ref.read(billServiceProvider).getBills();
                            await NotificationService().checkBillsAndNotify(updatedBills);
                          },
                          onDelete: () async {
                            await ref
                                .read(billServiceProvider)
                                .deleteBill(entry.value.id);
                            ref.invalidate(billsProvider);
                          },
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(
                                  milliseconds: 100 + (entry.key * 80)),
                              duration: 400.ms,
                            )
                            .slideX(begin: 0.05, curve: Curves.easeOut),
                      )),
                  const SizedBox(height: 20),
                ],
                if (paid.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.income.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.income.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.tick_circle,
                                size: 16, color: AppTheme.income),
                            const SizedBox(width: 6),
                            Text(
                              '${paid.length} sudah dibayar',
                              style: const TextStyle(
                                color: AppTheme.income,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...paid.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BillItem(
                          bill: entry.value,
                          formatter: formatter,
                          onToggle: () async {
                            await ref
                                .read(billServiceProvider)
                                .togglePaid(entry.value.id, false);
                            ref.invalidate(billsProvider);
                            // Refresh bill notifications
                            final updatedBills = await ref.read(billServiceProvider).getBills();
                            await NotificationService().checkBillsAndNotify(updatedBills);
                          },
                          onDelete: () async {
                            await ref
                                .read(billServiceProvider)
                                .deleteBill(entry.value.id);
                            ref.invalidate(billsProvider);
                          },
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(
                                  milliseconds: 100 + (entry.key * 80)),
                              duration: 400.ms,
                            )
                            .slideX(begin: 0.05, curve: Curves.easeOut),
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
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 80),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddBillDialog(context, ref),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Iconsax.add, color: Colors.white),
        ),
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
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppTheme.border.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tambah Tagihan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Tagihan',
                  hintText: 'Contoh: Listrik, Netflix, dll',
                  prefixIcon: Icon(Iconsax.note),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Iconsax.money),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            surface: AppTheme.surfaceVariant,
                            onSurface: AppTheme.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) setState(() => dueDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar_1,
                          color: AppTheme.primaryLight, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Jatuh tempo: ${DateFormat('dd MMMM yyyy', 'id_ID').format(dueDate)}',
                        style: const TextStyle(
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          amountController.text.isEmpty) return;
                      final bill = BillModel(
                        id: '',
                        userId: Supabase
                            .instance.client.auth.currentUser!.id,
                        name: nameController.text,
                        amount:
                            double.parse(amountController.text),
                        dueDate: dueDate,
                        isPaid: false,
                      );
                      await ref
                          .read(billServiceProvider)
                          .addBill(bill);
                      ref.invalidate(billsProvider);
                      // Send notification for upcoming/overdue bills
                      final allBills = await ref.read(billServiceProvider).getBills();
                      await NotificationService().checkBillsAndNotify(allBills);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Simpan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
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

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.expense.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.expense.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.expense.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.expenseGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.expense.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.trash,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hapus Tagihan?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tagihan "${bill.name}" sebesar ${formatter.format(bill.amount)} akan dihapus secara permanen.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.expenseGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.expense.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        onDelete();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppTheme.expense,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        !bill.isPaid && bill.dueDate.isBefore(DateTime.now());
    final daysLeft =
        bill.dueDate.difference(DateTime.now()).inDays;

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOverdue
                ? AppTheme.expense.withOpacity(0.4)
                : AppTheme.border.withOpacity(0.5),
            width: isOverdue ? 1 : 0.5,
          ),
          boxShadow: isOverdue
              ? [
                  BoxShadow(
                    color: AppTheme.expense.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Status indicator
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: bill.isPaid
                      ? AppTheme.incomeGradient
                      : null,
                  color: bill.isPaid
                      ? null
                      : Colors.transparent,
                  border: bill.isPaid
                      ? null
                      : Border.all(
                          color: isOverdue
                              ? AppTheme.expense
                              : AppTheme.textSecondary,
                          width: 2,
                        ),
                  boxShadow: bill.isPaid
                      ? [
                          BoxShadow(
                            color: AppTheme.income.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      decoration: bill.isPaid
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Iconsax.calendar_1,
                        size: 12,
                        color: isOverdue
                            ? AppTheme.expense
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy')
                            .format(bill.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue
                              ? AppTheme.expense
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (!bill.isPaid && !isOverdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: daysLeft <= 3
                                ? AppTheme.warning.withOpacity(0.15)
                                : AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$daysLeft hari lagi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: daysLeft <= 3
                                  ? AppTheme.warning
                                  : AppTheme.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '⚠️ Lewat ${-daysLeft} hari!',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.expense,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatter.format(bill.amount),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
            // Delete button
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showDeleteConfirmation(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.expense.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.expense.withOpacity(0.2),
                  ),
                ),
                child: const Icon(
                  Iconsax.trash,
                  size: 16,
                  color: AppTheme.expense,
                ),
              ),
            ),
          ],
        ),
    );
  }
}