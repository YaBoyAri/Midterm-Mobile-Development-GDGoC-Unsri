import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _selectedMonth;
  String _selectedFilter = 'expense';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _showMonthPicker() {
    final now = DateTime.now();
    // Generate 12 bulan terakhir
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
              // Handle bar
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
    final formatter = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: transactionsAsync.when(
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
          final totalDifference = totalIncome - totalExpense;

          final expenseByCategory = <String, double>{};
          for (final t in thisMonth.where((t) => t.type == 'expense')) {
            expenseByCategory[t.category] =
                (expenseByCategory[t.category] ?? 0) + t.amount;
          }

          final weeklyExpense = _getWeeklyData(thisMonth, 'expense');
          final weeklyIncome = _getWeeklyData(thisMonth, 'income');

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month indicator — tappable
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

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pemasukan',
                        amount: formatter.format(totalIncome),
                        color: AppTheme.income,
                        gradient: AppTheme.incomeGradient,
                        icon: Iconsax.arrow_down,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pengeluaran',
                        amount: formatter.format(totalExpense),
                        color: AppTheme.expense,
                        gradient: AppTheme.expenseGradient,
                        icon: Iconsax.arrow_up_1,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 500.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOut),
                const SizedBox(height: 24),

                // ── Grafik Selisih Pemasukan vs Pengeluaran ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassCard(borderRadius: 20),
                  child: Column(
                    children: [
                      // Top: Pemasukan | Pengeluaran amounts
                      Row(
                        children: [
                          // Pemasukan column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.income,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Pemasukan',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatter.format(totalIncome),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Vertical divider
                          Container(
                            width: 1,
                            height: 45,
                            color: AppTheme.border.withOpacity(0.5),
                          ),
                          // Pengeluaran column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.expense,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Pengeluaran',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatter.format(totalExpense),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Selisih text
                      Text.rich(
                        TextSpan(
                          text: 'Selisih ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: '${totalDifference < 0 ? '-' : ''}${formatter.format(totalDifference.abs())}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: totalDifference >= 0
                                    ? AppTheme.income
                                    : AppTheme.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Simple 2-bar chart
                      SizedBox(
                        height: 200,
                        child: (totalIncome == 0 && totalExpense == 0)
                            ? const Center(
                                child: Text(
                                  'Belum ada data',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              )
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceEvenly,
                                  maxY: (totalIncome > totalExpense
                                          ? totalIncome
                                          : totalExpense) *
                                      1.25,
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      tooltipRoundedRadius: 10,
                                      getTooltipItem:
                                          (group, groupIndex, rod, rodIndex) {
                                        final label = groupIndex == 0
                                            ? 'Pemasukan'
                                            : 'Pengeluaran';
                                        return BarTooltipItem(
                                          '$label\n',
                                          const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: formatter.format(rod.toY),
                                              style: TextStyle(
                                                color: groupIndex == 0
                                                    ? AppTheme.income
                                                    : AppTheme.expense,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (value, meta) {
                                          final labels = [
                                            'Pemasukan',
                                            'Pengeluaran'
                                          ];
                                          if (value.toInt() >= 0 &&
                                              value.toInt() < labels.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 10),
                                              child: Text(
                                                labels[value.toInt()],
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      AppTheme.textSecondary,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval:
                                        ((totalIncome > totalExpense
                                                    ? totalIncome
                                                    : totalExpense) *
                                                1.25) /
                                            4,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color:
                                            AppTheme.border.withOpacity(0.2),
                                        strokeWidth: 0.8,
                                        dashArray: [5, 5],
                                      );
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: [
                                    // Pemasukan bar
                                    BarChartGroupData(
                                      x: 0,
                                      barRods: [
                                        BarChartRodData(
                                          toY: totalIncome,
                                          color: AppTheme.income,
                                          width: 48,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          backDrawRodData:
                                              BackgroundBarChartRodData(
                                            show: true,
                                            toY: (totalIncome > totalExpense
                                                    ? totalIncome
                                                    : totalExpense) *
                                                1.25,
                                            color: AppTheme.income
                                                .withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Pengeluaran bar
                                    BarChartGroupData(
                                      x: 1,
                                      barRods: [
                                        BarChartRodData(
                                          toY: totalExpense,
                                          color: AppTheme.expense,
                                          width: 48,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          backDrawRodData:
                                              BackgroundBarChartRodData(
                                            show: true,
                                            toY: (totalIncome > totalExpense
                                                    ? totalIncome
                                                    : totalExpense) *
                                                1.25,
                                            color: AppTheme.expense
                                                .withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle buttons: Pemasukan / Pengeluaran
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedFilter = 'income');
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == 'income'
                                      ? AppTheme.income.withOpacity(0.18)
                                      : AppTheme.surfaceLight.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: _selectedFilter == 'income'
                                        ? AppTheme.income.withOpacity(0.4)
                                        : AppTheme.border.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _selectedFilter == 'income'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _selectedFilter == 'income'
                                          ? AppTheme.income
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedFilter = 'expense');
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == 'expense'
                                      ? AppTheme.expense.withOpacity(0.18)
                                      : AppTheme.surfaceLight.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: _selectedFilter == 'expense'
                                        ? AppTheme.expense.withOpacity(0.4)
                                        : AppTheme.border.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _selectedFilter == 'expense'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _selectedFilter == 'expense'
                                          ? AppTheme.expense
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Detail List of filtered transactions ──
                      Builder(
                        builder: (context) {
                          final filteredTransactions = thisMonth
                              .where((t) => t.type == _selectedFilter)
                              .toList()
                            ..sort((a, b) => b.date.compareTo(a.date));

                          final isIncome = _selectedFilter == 'income';
                          final accentColor = isIncome
                              ? AppTheme.income
                              : AppTheme.expense;

                          if (filteredTransactions.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      isIncome ? Iconsax.arrow_down : Iconsax.arrow_up_1,
                                      size: 32,
                                      color: AppTheme.textMuted.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isIncome
                                          ? 'Belum ada pemasukan bulan ini'
                                          : 'Belum ada pengeluaran bulan ini',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              const SizedBox(height: 16),
                              // Divider
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      accentColor.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Header
                              Row(
                                children: [
                                  Icon(
                                    isIncome ? Iconsax.arrow_down : Iconsax.arrow_up_1,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Detail ${isIncome ? 'Pemasukan' : 'Pengeluaran'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${filteredTransactions.length} transaksi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Transaction list
                              ...filteredTransactions.asMap().entries.map((entry) {
                                final index = entry.key;
                                final t = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.border.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Category icon
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: accentColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              _getCategoryIcon(t.category),
                                              color: accentColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Category + Note + Date
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.category,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              if (t.note != null &&
                                                  t.note!.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    t.note!,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.textMuted,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('dd MMM yyyy', 'id_ID')
                                                    .format(t.date),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Amount
                                        Text(
                                          '${isIncome ? '+' : '-'}${formatter.format(t.amount)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(
                                      delay: Duration(milliseconds: 50 * index),
                                      duration: 300.ms,
                                    )
                                    .slideX(
                                      begin: 0.05,
                                      delay: Duration(milliseconds: 50 * index),
                                      duration: 300.ms,
                                      curve: Curves.easeOut,
                                    );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 500.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOut),
                const SizedBox(height: 24),

                // Bar Chart Mingguan (Pengeluaran only — existing)
                const Text(
                  'Pengeluaran Mingguan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassCard(borderRadius: 20),
                  height: 220,
                  child: weeklyExpense.every((v) => v == 0)
                      ? const Center(
                          child: Text('Belum ada data',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: weeklyExpense.reduce(
                                    (a, b) => a > b ? a : b) *
                                1.3,
                            barTouchData:
                                BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const weeks = [
                                      'Mg 1', 'Mg 2', 'Mg 3', 'Mg 4'
                                    ];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(top: 8),
                                      child: Text(
                                        weeks[value.toInt()],
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppTheme.textSecondary),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(
                              4,
                              (i) => BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: weeklyExpense[i],
                                    gradient: AppTheme.primaryGradient,
                                    width: 28,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    backDrawRodData:
                                        BackgroundBarChartRodData(
                                      show: true,
                                      toY: weeklyExpense.reduce(
                                              (a, b) =>
                                                  a > b ? a : b) *
                                          1.3,
                                      color: AppTheme.surfaceLight
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 500.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOut),
                const SizedBox(height: 24),

                // Pie Chart Kategori
                if (expenseByCategory.isNotEmpty) ...[
                  const Text(
                    'Pengeluaran per Kategori',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCard(borderRadius: 20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: _getPieSections(
                                  expenseByCategory, totalExpense),
                              centerSpaceRadius: 45,
                              sectionsSpace: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Legend
                        ...expenseByCategory.entries
                            .toList()
                            .asMap()
                            .entries
                            .map((e) {
                          final percentage =
                              (e.value.value / totalExpense * 100);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _pieColors[
                                        e.key % _pieColors.length],
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.value.key,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Text(
                                  formatter.format(e.value.value),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _pieColors[
                                            e.key % _pieColors.length]
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _pieColors[
                                          e.key % _pieColors.length],
                                    ),
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
                      .fadeIn(delay: 550.ms, duration: 500.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOut),
                ],
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<double> _getWeeklyData(
      List<TransactionModel> transactions, String type) {
    final weekly = [0.0, 0.0, 0.0, 0.0];
    for (final t in transactions.where((t) => t.type == type)) {
      final week = ((t.date.day - 1) / 7).floor().clamp(0, 3);
      weekly[week] += t.amount;
    }
    return weekly;
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

  static const _pieColors = [
    Color(0xFF818CF8), // Indigo
    Color(0xFFF43F5E), // Rose
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF06B6D4), // Cyan
    Color(0xFFA78BFA), // Violet
    Color(0xFFFB923C), // Orange
  ];

  List<PieChartSectionData> _getPieSections(
      Map<String, double> data, double total) {
    final entries = data.entries.toList();
    return List.generate(entries.length, (i) {
      final percentage = (entries[i].value / total * 100);
      return PieChartSectionData(
        value: entries[i].value,
        color: _pieColors[i % _pieColors.length],
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final LinearGradient gradient;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCardColored(
        color: color,
        borderRadius: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(amount,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}