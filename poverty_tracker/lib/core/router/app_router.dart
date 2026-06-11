import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/transaction/add_transaction_screen.dart';
import '../../presentation/transaction/edit_transaction_screen.dart';
import '../../data/models/transaction_model.dart';
import '../../presentation/budget/budget_screen.dart';
import '../../presentation/report/report_screen.dart';
import '../../presentation/bill/bill_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
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
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_rounded), label: 'Budget'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'Report'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
        ],
      ),
    );
  }
}