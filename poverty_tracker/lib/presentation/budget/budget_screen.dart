import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budget_provider.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final spendingAsync = ref.watch(spendingByCategoryProvider);
    final formatter = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Iconsax.add, size: 20),
              onPressed: () => _showAddBudgetDialog(context, ref),
              color: AppTheme.primaryLight,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryLight,
        backgroundColor: AppTheme.surfaceVariant,
        onRefresh: () async {
          ref.invalidate(budgetsProvider);
          ref.invalidate(spendingByCategoryProvider);
        },
        child: budgetsAsync.when(
          data: (budgets) => spendingAsync.when(
            data: (spending) => budgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.chart,
                              size: 48, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text('Belum ada budget',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 4),
                        const Text('Tambahkan budget untuk kategorimu',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  ).animate().fadeIn()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: budgets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final budget = budgets[index];
                      final spent = spending[budget.category] ?? 0;
                      final progress =
                          (spent / budget.limitAmount).clamp(0.0, 1.0);
                      final isOver = spent > budget.limitAmount;
                      final remaining = budget.limitAmount - spent;

                      return Dismissible(
                        key: Key(budget.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            gradient: AppTheme.expenseGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Iconsax.trash,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Budget'),
                              content: const Text(
                                  'Yakin ingin menghapus budget ini?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.expense),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await ref
                                  .read(budgetServiceProvider)
                                  .deleteBudget(budget.id);
                              ref.invalidate(budgetsProvider);
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
                          padding: const EdgeInsets.all(18),
                          decoration: AppTheme.glassCard(
                            borderRadius: 20,
                            borderColor: isOver
                                ? AppTheme.expense.withOpacity(0.3)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (isOver
                                                  ? AppTheme.expense
                                                  : AppTheme.primary)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(budget.category),
                                          color: isOver
                                              ? AppTheme.expense
                                              : AppTheme.primaryLight,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(budget.category,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                              fontSize: 15)),
                                    ],
                                  ),
                                  if (isOver)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.expense.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '⚠️ Over',
                                        style: TextStyle(
                                          color: AppTheme.expense,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight
                                            .withOpacity(0.5),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          gradient: isOver
                                              ? AppTheme.expenseGradient
                                              : AppTheme.primaryGradient,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isOver
                                                      ? AppTheme.expense
                                                      : AppTheme.primary)
                                                  .withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${formatter.format(spent)} dipakai',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                                  Text(
                                    isOver
                                        ? 'Lebih ${formatter.format(-remaining)}'
                                        : 'Sisa ${formatter.format(remaining)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOver
                                          ? AppTheme.expense
                                          : AppTheme.income,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 100 + (index * 80)),
                            duration: 400.ms,
                          )
                          .slideX(begin: 0.05, curve: Curves.easeOut);
                    },
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
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
          onPressed: () => _showAddBudgetDialog(context, ref),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Iconsax.add, color: Colors.white),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'makanan':
        return Iconsax.coffee;
      case 'transportasi':
        return Iconsax.car;
      case 'belanja':
        return Iconsax.bag_2;
      case 'hiburan':
        return Iconsax.game;
      case 'kesehatan':
        return Iconsax.health;
      case 'tagihan':
        return Iconsax.receipt_text;
      default:
        return Iconsax.money;
    }
  }

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    String selectedCategory = 'Makanan';
    final categories = [
      'Makanan', 'Transportasi', 'Belanja',
      'Hiburan', 'Kesehatan', 'Tagihan', 'Lainnya'
    ];
    final formatter = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
              const Text('Tambah Budget',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: AppTheme.surfaceVariant,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Iconsax.category),
                ),
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCategory = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Limit Budget',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Iconsax.money),
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
                      if (amountController.text.isEmpty) return;
                      final currentMonth =
                          DateFormat('yyyy-MM').format(DateTime.now());
                      final existingBudgets = await ref
                          .read(budgetServiceProvider)
                          .getBudgets(currentMonth);
                      final isDuplicate = existingBudgets
                          .any((b) => b.category == selectedCategory);
                      if (isDuplicate) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Budget untuk "$selectedCategory" bulan ini sudah ada!'),
                              backgroundColor: AppTheme.warning,
                            ),
                          );
                        }
                        return;
                      }
                      final budget = BudgetModel(
                        id: '',
                        userId:
                            Supabase.instance.client.auth.currentUser!.id,
                        category: selectedCategory,
                        limitAmount:
                            double.parse(amountController.text),
                        month: currentMonth,
                      );
                      await ref
                          .read(budgetServiceProvider)
                          .addBudget(budget);
                      ref.invalidate(budgetsProvider);
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