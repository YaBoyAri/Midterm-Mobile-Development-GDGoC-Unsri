import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/auth/biometric_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/transaction/add_transaction_screen.dart';
import '../../presentation/transaction/edit_transaction_screen.dart';
import '../../presentation/scanner/receipt_camera_screen.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/receipt_data.dart';
import '../../presentation/budget/budget_screen.dart';
import '../../presentation/report/report_screen.dart';
import '../../presentation/bill/bill_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../theme/app_theme.dart';

/// Tracks whether biometric has been verified this app session.
/// Reset when the app is restarted or user logs out.
class BiometricState {
  static bool hasVerified = false;
  static bool needsBiometric = false; // Set during app init

  static void reset() {
    hasVerified = false;
    needsBiometric = false;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isBiometricRoute = state.matchedLocation == '/biometric';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';

      // Biometric check: if logged in, biometric enabled, and not yet verified
      if (isLoggedIn &&
          BiometricState.needsBiometric &&
          !BiometricState.hasVerified &&
          !isBiometricRoute &&
          !isAuthRoute) {
        return '/biometric';
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/budget', builder: (c, s) => const BudgetScreen()),
          GoRoute(path: '/report', builder: (c, s) => const ReportScreen()),
          GoRoute(path: '/bill', builder: (c, s) => const BillScreen()),
        ],
      ),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/biometric', builder: (c, s) => const BiometricScreen()),
      GoRoute(
        path: '/add-transaction',
        builder: (c, s) {
          final extra = s.extra;
          ReceiptData? receiptData;
          if (extra is Map) {
            receiptData = extra['receiptData'] as ReceiptData?;
          }
          return AddTransactionScreen(initialReceiptData: receiptData);
        },
      ),
      GoRoute(
        path: '/edit-transaction',
        builder: (c, s) => EditTransactionScreen(
          transaction: s.extra as TransactionModel,
        ),
      ),
    ],
  );
});


class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location == '/budget') currentIndex = 1;
    if (location == '/report') currentIndex = 2;
    if (location == '/bill') currentIndex = 3;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/budget');
              break;
            // index 2 = scan button (handled separately in navbar)
            case 3:
              context.go('/report');
              break;
            case 4:
              context.go('/bill');
              break;
          }
        },
        onScanTap: () async {
          // Open custom camera screen and get ReceiptData back
          final result = await Navigator.push<ReceiptData>(
            context,
            MaterialPageRoute(builder: (_) => const ReceiptCameraScreen()),
          );
          if (result != null && context.mounted) {
            // Navigate to add-transaction with scanned data
            context.push('/add-transaction', extra: {'receiptData': result});
          }
        },
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final leftItems = [
      _NavItem(icon: Iconsax.home_2, activeIcon: Iconsax.home_25, label: 'Home'),
      _NavItem(icon: Iconsax.chart, activeIcon: Iconsax.chart_1, label: 'Budget'),
    ];

    final rightItems = [
      _NavItem(icon: Iconsax.graph, activeIcon: Iconsax.graph, label: 'Report'),
      _NavItem(icon: Iconsax.receipt_text, activeIcon: Iconsax.receipt_text, label: 'Bills'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.border.withOpacity(0.5),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Left items (Home, Budget)
                ...leftItems.asMap().entries.map((e) =>
                    _buildNavItem(e.value, e.key, e.key == currentIndex)),

                // Center scan button
                _buildScanButton(),

                // Right items (Report, Bills) — indices 3 and 4
                ...rightItems.asMap().entries.map((e) {
                  final realIndex = e.key + 3; // 0→3 (Report), 1→4 (Bills)
                  // currentIndex mapping: Report=2, Bills=3
                  // But in the new layout: Report=index3, Bills=index4
                  // Original currentIndex: 0=Home, 1=Budget, 2=Report, 3=Bills
                  final isActive = (e.key == 0 && currentIndex == 2) ||
                      (e.key == 1 && currentIndex == 3);
                  return _buildNavItem(e.value, realIndex, isActive);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isActive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive
                  ? AppTheme.primaryLight
                  : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: isActive
                    ? AppTheme.primaryLight
                    : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: onScanTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Iconsax.scan_barcode,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}