import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/transaction_service.dart';
import '../../data/services/notification_service.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _category = 'Makanan';
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  final _incomeCategories = [
    'Gaji', 'Investasi', 'Bonus', 'Freelance', 'Lainnya'
  ];
  final _expenseCategories = [
    'Makanan', 'Transportasi', 'Belanja', 'Hiburan',
    'Kesehatan', 'Tagihan', 'Lainnya'
  ];

  final _categoryEmojis = {
    'Makanan': '🍔', 'Transportasi': '🚗', 'Belanja': '🛍️',
    'Hiburan': '🎮', 'Kesehatan': '🏥', 'Tagihan': '📄',
    'Gaji': '💼', 'Investasi': '📈', 'Bonus': '🎁',
    'Freelance': '💻', 'Lainnya': '💰',
  };

  List<String> get _categories =>
      _type == 'income' ? _incomeCategories : _expenseCategories;

  Future<void> _submit() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transaction = TransactionModel(
        id: '',
        userId: Supabase.instance.client.auth.currentUser!.id,
        type: _type,
        amount: double.parse(_amountController.text.replaceAll('.', '')),
        category: _category,
        note: _noteController.text,
        date: _date,
      );

      await TransactionService().addTransaction(transaction);

      // Check budget and send notification if expense
      if (_type == 'expense') {
        final month = DateFormat('yyyy-MM').format(_date);
        await NotificationService().checkBudgetAndNotify(month: month);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil ditambahkan! ✅'),
            backgroundColor: AppTheme.income,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Transaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.border.withOpacity(0.5), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'expense';
                        _category = _expenseCategories[0];
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _type == 'expense'
                              ? AppTheme.expenseGradient
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _type == 'expense'
                              ? [
                                  BoxShadow(
                                    color: AppTheme.expense
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.arrow_up_1,
                              size: 18,
                              color: _type == 'expense'
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pengeluaran',
                              style: TextStyle(
                                color: _type == 'expense'
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'income';
                        _category = _incomeCategories[0];
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _type == 'income'
                              ? AppTheme.incomeGradient
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _type == 'income'
                              ? [
                                  BoxShadow(
                                    color: AppTheme.income
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.arrow_down,
                              size: 18,
                              color: _type == 'income'
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pemasukan',
                              style: TextStyle(
                                color: _type == 'income'
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 24),

            // Amount
            const Text('Nominal',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                prefixStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 20),

            // Category
            const Text('Kategori',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map((cat) => GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _category == cat
                                ? AppTheme.primaryGradient
                                : null,
                            color: _category == cat
                                ? null
                                : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: _category == cat
                                ? null
                                : Border.all(
                                    color: AppTheme.border.withOpacity(0.5),
                                    width: 0.5,
                                  ),
                            boxShadow: _category == cat
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primary
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _categoryEmojis[cat] ?? '💰',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat,
                                style: TextStyle(
                                  color: _category == cat
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
            const SizedBox(height: 20),

            // Date
            const Text('Tanggal',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
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
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.border.withOpacity(0.5), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar_1,
                        color: AppTheme.primaryLight, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy', 'id_ID').format(_date),
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
            const SizedBox(height: 20),

            // Note
            const Text('Catatan (opsional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Tambahkan catatan...',
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Simpan Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}