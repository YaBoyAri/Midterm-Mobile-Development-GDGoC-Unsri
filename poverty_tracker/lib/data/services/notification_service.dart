import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../models/bill_model.dart';
import '../services/budget_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Notification Channel IDs ─────────────────────────────────────
  static const String _budgetChannelId = 'budget_alerts';
  static const String _budgetChannelName = 'Peringatan Budget';
  static const String _budgetChannelDesc =
      'Notifikasi saat budget hampir habis atau terlampaui';

  static const String _billChannelId = 'bill_reminders';
  static const String _billChannelName = 'Pengingat Tagihan';
  static const String _billChannelDesc =
      'Notifikasi pengingat tagihan yang akan jatuh tempo';

  // ─── Notification ID ranges ───────────────────────────────────────
  // Budget: 1000 - 1999
  // Bill: 2000 - 2999
  static const int _budgetBaseId = 1000;
  static const int _billBaseId = 2000;

  // ─── Initialize ───────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permission for Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized successfully');
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Could navigate to specific screen based on payload
    debugPrint('[NotificationService] Tapped: ${response.payload}');
  }

  // ─── Budget Notifications ────────────────────────────────────────
  /// Check all budgets for the current month and send warnings
  /// Called after a new expense transaction is added
  Future<void> checkBudgetAndNotify({
    required String month,
  }) async {
    try {
      final budgetService = BudgetService();

      // Get budgets for this month
      final budgets = await budgetService.getBudgets(month);
      if (budgets.isEmpty) return;

      // Get actual spending per category
      final spending = await budgetService.getSpendingByCategory(month);

      for (int i = 0; i < budgets.length; i++) {
        final budget = budgets[i];
        final spent = spending[budget.category] ?? 0.0;
        final percentage = (spent / budget.limitAmount * 100).round();

        if (spent > budget.limitAmount) {
          // Over budget!
          final overAmount = spent - budget.limitAmount;
          await _showNotification(
            id: _budgetBaseId + i,
            channelId: _budgetChannelId,
            channelName: _budgetChannelName,
            channelDesc: _budgetChannelDesc,
            title: '🚨 Budget ${budget.category} Terlampaui!',
            body:
                'Pengeluaran ${budget.category} sudah $percentage% dari budget. '
                'Kelebihan Rp ${_formatNumber(overAmount)}',
            payload: 'budget_exceeded_${budget.category}',
          );
        } else if (percentage >= 80) {
          // Budget warning (80%+)
          final remaining = budget.limitAmount - spent;
          await _showNotification(
            id: _budgetBaseId + i,
            channelId: _budgetChannelId,
            channelName: _budgetChannelName,
            channelDesc: _budgetChannelDesc,
            title: '⚠️ Budget ${budget.category} Hampir Habis!',
            body:
                'Sudah terpakai $percentage%. Sisa Rp ${_formatNumber(remaining)}',
            payload: 'budget_warning_${budget.category}',
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Budget check error: $e');
    }
  }

  // ─── Bill Notifications ──────────────────────────────────────────
  /// Check bills and send reminders for upcoming/overdue bills
  /// Called when app opens or when a bill is added
  Future<void> checkBillsAndNotify(List<BillModel> bills) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int notifIndex = 0;
      for (final bill in bills) {
        if (bill.isPaid) continue;

        final dueDay = DateTime(
            bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
        final daysUntilDue = dueDay.difference(today).inDays;

        if (daysUntilDue < 0) {
          // Overdue!
          final daysLate = daysUntilDue.abs();
          await _showNotification(
            id: _billBaseId + notifIndex,
            channelId: _billChannelId,
            channelName: _billChannelName,
            channelDesc: _billChannelDesc,
            title: '❗ Tagihan ${bill.name} Sudah Lewat!',
            body:
                'Rp ${_formatNumber(bill.amount)} sudah lewat $daysLate hari. '
                'Segera bayar!',
            payload: 'bill_overdue_${bill.id}',
          );
          notifIndex++;
        } else if (daysUntilDue == 0) {
          // Due today!
          await _showNotification(
            id: _billBaseId + notifIndex,
            channelId: _billChannelId,
            channelName: _billChannelName,
            channelDesc: _billChannelDesc,
            title: '📄 Tagihan ${bill.name} Jatuh Tempo Hari Ini!',
            body: 'Rp ${_formatNumber(bill.amount)} harus dibayar hari ini.',
            payload: 'bill_due_today_${bill.id}',
          );
          notifIndex++;
        } else if (daysUntilDue == 1) {
          // Due tomorrow
          await _showNotification(
            id: _billBaseId + notifIndex,
            channelId: _billChannelId,
            channelName: _billChannelName,
            channelDesc: _billChannelDesc,
            title: '📄 Tagihan ${bill.name} Jatuh Tempo Besok!',
            body: 'Rp ${_formatNumber(bill.amount)} jatuh tempo besok. '
                'Jangan sampai lupa!',
            payload: 'bill_due_tomorrow_${bill.id}',
          );
          notifIndex++;
        } else if (daysUntilDue <= 3) {
          // Due in 2-3 days
          await _showNotification(
            id: _billBaseId + notifIndex,
            channelId: _billChannelId,
            channelName: _billChannelName,
            channelDesc: _billChannelDesc,
            title: '🔔 Tagihan ${bill.name} Dalam $daysUntilDue Hari',
            body:
                'Rp ${_formatNumber(bill.amount)} jatuh tempo dalam $daysUntilDue hari.',
            payload: 'bill_upcoming_${bill.id}',
          );
          notifIndex++;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Bill check error: $e');
    }
  }

  // ─── Show Notification Helper ─────────────────────────────────────
  Future<void> _showNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      autoCancel: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details, payload: payload);
    debugPrint('[NotificationService] Sent: $title');
  }

  // ─── Cancel Notifications ─────────────────────────────────────────
  Future<void> cancelBillNotification(int index) async {
    await _plugin.cancel(_billBaseId + index);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}jt';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}.000';
    }
    return number.toStringAsFixed(0);
  }
}
