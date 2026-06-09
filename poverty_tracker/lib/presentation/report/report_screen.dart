import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final formatter = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: transactionsAsync.when(
        data: (transactions) {
          final now = DateTime.now();
          final thisMonth = transactions.where((t) =>
              t.date.month == now.month && t.date.year == now.year).toList();

          final totalIncome = thisMonth
              .where((t) => t.type == 'income')
              .fold(0.0, (sum, t) => sum + t.amount);
          final totalExpense = thisMonth
              .where((t) => t.type == 'expense')
              .fold(0.0, (sum, t) => sum + t.amount);

          final expenseByCategory = <String, double>{};
          for (final t in thisMonth.where((t) => t.type == 'expense')) {
            expenseByCategory[t.category] =
                (expenseByCategory[t.category] ?? 0) + t.amount;
          }

          final weeklyData = _getWeeklyData(thisMonth);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pemasukan',
                        amount: formatter.format(totalIncome),
                        color: AppTheme.income,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pengeluaran',
                        amount: formatter.format(totalExpense),
                        color: AppTheme.expense,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bar Chart Mingguan
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  height: 200,
                  child: weeklyData.every((v) => v == 0)
                      ? const Center(
                          child: Text('Belum ada data',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: weeklyData.reduce(
                                    (a, b) => a > b ? a : b) *
                                1.2,
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
                                      'Mg1', 'Mg2', 'Mg3', 'Mg4'
                                    ];
                                    return Text(
                                      weeks[value.toInt()],
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary),
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
                                    toY: weeklyData[i],
                                    color: AppTheme.primary,
                                    width: 24,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: _getPieSections(
                                  expenseByCategory, totalExpense),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: expenseByCategory.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((e) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _pieColors[e.key %
                                              _pieColors.length],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        e.value.key,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
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

  List<double> _getWeeklyData(List<TransactionModel> transactions) {
    final weekly = [0.0, 0.0, 0.0, 0.0];
    for (final t in transactions.where((t) => t.type == 'expense')) {
      final week = ((t.date.day - 1) / 7).floor().clamp(0, 3);
      weekly[week] += t.amount;
    }
    return weekly;
  }

  static const _pieColors = [
    AppTheme.primary,
    AppTheme.secondary,
    AppTheme.income,
    AppTheme.warning,
    Color(0xFF4FC3F7),
    Color(0xFFCE93D8),
    Color(0xFF80CBC4),
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
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(amount,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}