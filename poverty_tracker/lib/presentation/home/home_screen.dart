import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_provider.dart';
import '../../data/repositories/transaction_provider.dart';
import '../../data/repositories/budget_provider.dart';
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
                        const SizedBox(height: 20),

                        // ── Spending Insight Card (month-over-month) ──
                        _buildSpendingInsight(
                          transactions, totalExpense, formatter),
                        const SizedBox(height: 16),

                        // ── Weekly Spending Trend (mini chart) ──
                        _buildWeeklyTrend(thisMonth),
                        const SizedBox(height: 16),

                        // ── Top Categories ──
                        _buildTopCategories(
                          thisMonth, totalExpense, formatter),
                        const SizedBox(height: 16),

                        // ── Budget Alert Banner ──
                        _buildBudgetAlerts(ref, formatter),
                        const SizedBox(height: 24),

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

  // ═══════════════════════════════════════════════════════════════════
  //  NEW INSIGHT SECTIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Spending Insight Card — compares this month's expense to last month
  Widget _buildSpendingInsight(
    List<TransactionModel> allTransactions,
    double currentExpense,
    NumberFormat formatter,
  ) {
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final prevExpense = allTransactions
        .where((t) =>
            t.type == 'expense' &&
            t.date.month == prevMonth.month &&
            t.date.year == prevMonth.year)
        .fold(0.0, (sum, t) => sum + t.amount);

    // Calculate percentage change
    double pctChange = 0;
    bool isDown = true;
    if (prevExpense > 0) {
      pctChange = ((currentExpense - prevExpense) / prevExpense * 100).abs();
      isDown = currentExpense <= prevExpense;
    } else if (currentExpense > 0) {
      pctChange = 100;
      isDown = false;
    }

    final prevMonthName = DateFormat('MMMM', 'id_ID').format(prevMonth);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCardColored(
        color: isDown ? AppTheme.income : AppTheme.expense,
        borderRadius: 20,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDown ? AppTheme.income : AppTheme.expense)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDown ? Iconsax.trend_down : Iconsax.trend_up,
              color: isDown ? AppTheme.income : AppTheme.expense,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insight Pengeluaran',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (isDown ? AppTheme.income : AppTheme.expense)
                        .withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                    children: prevExpense == 0 && currentExpense == 0
                        ? [
                            const TextSpan(
                                text: 'Belum ada data pengeluaran bulan ini dan bulan lalu')
                          ]
                        : [
                            TextSpan(
                              text: '${pctChange.toStringAsFixed(0)}% ',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDown
                                    ? AppTheme.income
                                    : AppTheme.expense,
                              ),
                            ),
                            TextSpan(
                              text: isDown
                                  ? 'lebih hemat '
                                  : 'lebih banyak ',
                            ),
                            TextSpan(
                              text: 'dari $prevMonthName',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 250.ms, duration: 500.ms)
        .slideY(begin: 0.1, curve: Curves.easeOut);
  }

  /// Weekly Spending Trend — mini sparkline chart for daily expenses
  Widget _buildWeeklyTrend(List<TransactionModel> thisMonth) {
    // Group expenses by day
    final expenses = thisMonth.where((t) => t.type == 'expense').toList();
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    // Build daily totals
    final dailyTotals = List<double>.filled(daysInMonth, 0);
    for (final t in expenses) {
      final dayIndex = t.date.day - 1;
      if (dayIndex >= 0 && dayIndex < daysInMonth) {
        dailyTotals[dayIndex] += t.amount;
      }
    }

    // Determine which days to show (up to today if current month)
    final now = DateTime.now();
    int showDays = daysInMonth;
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
      showDays = now.day;
    }

    final visibleTotals = dailyTotals.sublist(0, showDays);
    final maxVal = visibleTotals.isEmpty
        ? 1.0
        : visibleTotals.reduce((a, b) => a > b ? a : b);

    final spots = visibleTotals
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Iconsax.chart_2,
                    size: 14, color: AppTheme.primaryLight),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tren Pengeluaran Harian',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxVal * 1.2,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final day = s.x.toInt() + 1;
                      final formatter = NumberFormat.compact(locale: 'id_ID');
                      return LineTooltipItem(
                        'Hari $day\nRp ${formatter.format(s.y)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.primaryLight,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) {
                        // Only show dot on max day
                        final isMax = spot.y == maxVal && maxVal > 0;
                        return FlDotCirclePainter(
                          radius: isMax ? 4 : 0,
                          color: AppTheme.expense,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryLight.withOpacity(0.25),
                          AppTheme.primaryLight.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.textMuted.withOpacity(0.6)),
              ),
              Text(
                '${(showDays / 2).round()}',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.textMuted.withOpacity(0.6)),
              ),
              Text(
                '$showDays',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.textMuted.withOpacity(0.6)),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 350.ms, duration: 500.ms)
        .slideY(begin: 0.1, curve: Curves.easeOut);
  }

  /// Top Categories — shows top 3 expense categories with progress bars
  Widget _buildTopCategories(
    List<TransactionModel> thisMonth,
    double totalExpense,
    NumberFormat formatter,
  ) {
    final expenses = thisMonth.where((t) => t.type == 'expense').toList();
    if (expenses.isEmpty) return const SizedBox.shrink();

    // Group by category
    final Map<String, double> categoryTotals = {};
    for (final t in expenses) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // Sort descending and take top 3
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    final categoryColors = [
      AppTheme.expense,
      AppTheme.warning,
      AppTheme.primaryLight,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.expense.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Iconsax.chart_1,
                    size: 14, color: AppTheme.expense),
              ),
              const SizedBox(width: 8),
              const Text(
                'Kategori Pengeluaran Terbesar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            final pct = totalExpense > 0 ? cat.value / totalExpense : 0.0;
            final color = categoryColors[index % categoryColors.length];

            return Padding(
              padding: EdgeInsets.only(bottom: index < top.length - 1 ? 14 : 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIconStatic(cat.key),
                          size: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatter.format(cat.value),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 450.ms, duration: 500.ms)
        .slideY(begin: 0.1, curve: Curves.easeOut);
  }

  /// Budget Alert Banner — shows when any budget is near or over limit
  Widget _buildBudgetAlerts(WidgetRef ref, NumberFormat formatter) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final spendingAsync = ref.watch(spendingByCategoryProvider);

    return budgetsAsync.when(
      data: (budgets) => spendingAsync.when(
        data: (spending) {
          // Find budgets that are >= 80% used
          final alerts = <Map<String, dynamic>>[];
          for (final budget in budgets) {
            final spent = spending[budget.category] ?? 0;
            final progress = budget.limitAmount > 0
                ? spent / budget.limitAmount
                : 0.0;
            if (progress >= 0.8) {
              alerts.add({
                'category': budget.category,
                'spent': spent,
                'limit': budget.limitAmount,
                'progress': progress,
                'isOver': progress >= 1.0,
              });
            }
          }

          if (alerts.isEmpty) return const SizedBox.shrink();

          // Sort: over-limit first, then by progress descending
          alerts.sort((a, b) {
            if (a['isOver'] != b['isOver']) {
              return a['isOver'] ? -1 : 1;
            }
            return (b['progress'] as double)
                .compareTo(a['progress'] as double);
          });

          return Column(
            children: alerts.map((alert) {
              final isOver = alert['isOver'] as bool;
              final progress =
                  (alert['progress'] as double).clamp(0.0, 1.0);
              final color = isOver ? AppTheme.expense : AppTheme.warning;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.glassCardColored(
                    color: color,
                    borderRadius: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isOver
                              ? Iconsax.danger
                              : Iconsax.warning_2,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOver
                                  ? 'Budget ${alert['category']} melebihi limit!'
                                  : 'Budget ${alert['category']} hampir habis',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatter.format(alert['spent'])} / ${formatter.format(alert['limit'])}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor:
                                    color.withOpacity(0.1),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 550.ms, duration: 400.ms)
                    .slideX(begin: 0.05, curve: Curves.easeOut),
              );
            }).toList(),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Helper to get category icon (static version for use outside _TransactionItem)
  IconData _getCategoryIconStatic(String category) {
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