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
import '../../data/models/transaction_model.dart';
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
        builder: (c, s) => const AddTransactionScreen(),
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
            case 2:
              context.go('/report');
              break;
            case 3:
              context.go('/bill');
              break;
          }
        },
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Iconsax.home_2, activeIcon: Iconsax.home_25, label: 'Home'),
      _NavItem(icon: Iconsax.chart, activeIcon: Iconsax.chart_1, label: 'Budget'),
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.asMap().entries.map((e) {
                final isActive = e.key == currentIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
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
                          isActive ? e.value.activeIcon : e.value.icon,
                          color: isActive
                              ? AppTheme.primaryLight
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value.label,
                          style: TextStyle(
                            color: isActive
                                ? AppTheme.primaryLight
                                : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
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