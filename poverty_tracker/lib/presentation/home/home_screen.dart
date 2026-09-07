import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_provider.dart';
import '../../data/repositories/transaction_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/bill_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    // Check overdue/upcoming bills on app open
    _checkBillNotifications();
  }

  Future<void> _checkBillNotifications() async {
    try {
      final bills = await BillService().getBills();
      await NotificationService().checkBillsAndNotify(bills);
    } catch (_) {
      // Silently fail — notifications are non-critical
    }
  }

  void _showMonthPicker() {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final date = DateTime(now.year, now.month - i);
      return DateTime(date.year, date.month);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Bulan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final isSelected = month.year == _selectedMonth.year &&
                        month.month == _selectedMonth.month;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() => _selectedMonth = month);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary.withOpacity(0.4)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary.withOpacity(0.2)
                                        : AppTheme.surfaceLight
                                            .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Iconsax.calendar_1,
                                    size: 18,
                                    color: isSelected
                                        ? AppTheme.primaryLight
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    DateFormat('MMMM yyyy', 'id_ID')
                                        .format(month),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.primaryLight
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    // Watch auth state so display name updates when changed in settings
    ref.watch(authStateProvider);
    final user = ref.read(authServiceProvider).currentUser;
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryLight,
          backgroundColor: AppTheme.surfaceVariant,
          onRefresh: () async {
            ref.invalidate(summaryProvider);
            ref.invalidate(transactionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Halo! 👋',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
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
                                child: Center(
                                  child: Text(
                                    ((user?.userMetadata?['display_name']
                                                    as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? user!.userMetadata!['display_name']
                                            as String
                                        : user?.email?.split('@')[0] ??
                                            'U')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  (user?.userMetadata?['display_name']
                                              as String?)
                                          ?.isNotEmpty ==
                                      true
                                  ? user!.userMetadata!['display_name']
                                      as String
                                  : user?.email?.split('@')[0] ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: AppTheme.glassCard(borderRadius: 14),
                      child: IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Iconsax.setting_2,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideX(
                      begin: -0.1,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 20),

                // Month selector chip
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.calendar_1,
                            size: 16, color: AppTheme.primaryLight),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMMM yyyy', 'id_ID')
                              .format(_selectedMonth),
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Iconsax.arrow_down_1,
                            size: 14, color: AppTheme.primaryLight),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 16),

                // Balance Card — computed from monthly transactions
                transactionsAsync.when(
                  data: (transactions) {
                    final thisMonth = transactions
                        .where((t) =>
                            t.date.month == _selectedMonth.month &&
                            t.date.year == _selectedMonth.year)
                        .toList();

                    final totalIncome = thisMonth
                        .where((t) => t.type == 'income')
                        .fold(0.0, (sum, t) => sum + t.amount);
                    final totalExpense = thisMonth
                        .where((t) => t.type == 'expense')
                        .fold(0.0, (sum, t) => sum + t.amount);
                    final balance = totalIncome - totalExpense;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balance Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.balanceGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Iconsax.wallet_3,
                                        color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Saldo Bulan ${DateFormat('MMMM', 'id_ID').format(_selectedMonth)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                formatter.format(balance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryItem(
                                      label: 'Pemasukan',
                                      amount: formatter.format(totalIncome),
                                      icon: Icons.arrow_downward_rounded,
                                      color: AppTheme.income,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  Expanded(
                                    child: _SummaryItem(
                                      label: 'Pengeluaran',
                                      amount: formatter.format(totalExpense),
                                      icon: Icons.arrow_upward_rounded,
                                      color: AppTheme.expense,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .slideY(begin: 0.15, curve: Curves.easeOut),
                        const SizedBox(height: 28),

                        // Quick Actions
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Iconsax.add,
                                label: 'Tambah',
                                gradient: AppTheme.primaryGradient,
                                onTap: () async {
                                  await context.push('/add-transaction');
                                  ref.invalidate(transactionsProvider);
                                  ref.invalidate(summaryProvider);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAction(
                                icon: Iconsax.chart_1,
                                label: 'Budget',
                                gradient: AppTheme.incomeGradient,
                                onTap: () => context.go('/budget'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAction(
                                icon: Iconsax.graph,
                                label: 'Laporan',
                                gradient: AppTheme.expenseGradient,
                                onTap: () => context.go('/report'),
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 350.ms, duration: 500.ms)
                            .slideY(begin: 0.1, curve: Curves.easeOut),
                        const SizedBox(height: 28),

                        // Transaksi Terakhir (filtered by month)
                        Text(
                          'Transaksi Terakhir',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 14),
                        thisMonth.isEmpty
                            ? Center(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 40),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceVariant
                                            .withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Iconsax.receipt_text,
                                          size: 48,
                                          color: AppTheme.textMuted),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Belum ada transaksi',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Mulai catat pengeluaranmu!',
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 500.ms)
                            : _buildGroupedTransactions(
                                context,
                                ref,
                                thisMonth.length > 10
                                    ? thisMonth.sublist(0, 10)
                                    : thisMonth,
                                formatter,
                              ),
                      ],
                    );
                  },
                  loading: () => Column(
                    children: [
                      _buildShimmerCard(),
                      const SizedBox(height: 28),
                      ...List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildShimmerTile(),
                        ),
                      ),
                    ],
                  ),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: AppTheme.expense)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedTransactions(
    BuildContext context,
    WidgetRef ref,
    List<TransactionModel> transactions,
    NumberFormat formatter,
  ) {
    final incomeList =
        transactions.where((t) => t.type == 'income').toList();
    final expenseList =
        transactions.where((t) => t.type == 'expense').toList();

    int animIndex = 0;

    Widget buildSection({
      required String label,
      required IconData icon,
      required Color color,
      required List<TransactionModel> items,
    }) {
      if (items.isEmpty) return const SizedBox.shrink();
      final header = Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.25),
                      color.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 420 + (animIndex * 60)),
            duration: 400.ms,
          )
          .slideX(begin: -0.05, curve: Curves.easeOut);

      animIndex++;

      final itemWidgets = items.map((transaction) {
        final currentIndex = animIndex++;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TransactionItem(
            transaction: transaction,
            formatter: formatter,
            onTap: () async {
              final result = await context.push<bool>(
                '/edit-transaction',
                extra: transaction,
              );
              if (result == true) {
                ref.invalidate(transactionsProvider);
                ref.invalidate(summaryProvider);
              }
            },
            onDelete: () async {
              try {
                await ref
                    .read(transactionServiceProvider)
                    .deleteTransaction(transaction.id);
                ref.invalidate(transactionsProvider);
                ref.invalidate(summaryProvider);
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
            },
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 450 + (currentIndex * 60)),
                duration: 400.ms,
              )
              .slideX(
                begin: 0.05,
                curve: Curves.easeOut,
              ),
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, ...itemWidgets],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection(
          label: 'Pemasukan',
          icon: Icons.arrow_downward_rounded,
          color: AppTheme.income,
          items: incomeList,
        ),
        if (incomeList.isNotEmpty && expenseList.isNotEmpty)
          const SizedBox(height: 6),
        buildSection(
          label: 'Pengeluaran',
          icon: Icons.arrow_upward_rounded,
          color: AppTheme.expense,
          items: expenseList,
        ),
      ],
    );
  }


  Widget _buildShimmerCard() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: AppTheme.surfaceLight.withOpacity(0.3),
        );
  }

  Widget _buildShimmerTile() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: AppTheme.surfaceLight.withOpacity(0.3),
        );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradient.colors.first.withOpacity(0.15),
              gradient.colors.last.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradient.colors.first.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
              Text(amount,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  final NumberFormat formatter;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  const _TransactionItem({
    required this.transaction,
    required this.formatter,
    required this.onTap,
    required this.onDelete,
  });

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
      case 'gaji':
        return Iconsax.briefcase;
      case 'investasi':
        return Iconsax.chart_2;
      case 'tagihan':
        return Iconsax.receipt_text;
      default:
        return Iconsax.money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final accentColor = isIncome ? AppTheme.income : AppTheme.expense;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: AppTheme.expenseGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Iconsax.trash, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Transaksi'),
            content: const Text('Yakin ingin menghapus transaksi ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    TextButton.styleFrom(foregroundColor: AppTheme.expense),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          return await onDelete();
        }
        return false;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassCard(borderRadius: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getCategoryIcon(transaction.category),
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (transaction.note != null &&
                        transaction.note!.isNotEmpty)
                      Text(
                        transaction.note!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      DateFormat('dd MMM yyyy').format(transaction.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'} ${formatter.format(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}