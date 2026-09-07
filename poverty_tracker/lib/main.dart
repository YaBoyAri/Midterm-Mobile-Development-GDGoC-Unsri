import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/services/notification_service.dart';
import 'data/services/biometric_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', '');

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // Initialize local notifications
  await NotificationService().initialize();

  // Check if biometric lock is enabled
  final biometricService = BiometricService();
  final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
  if (isLoggedIn) {
    final biometricEnabled = await biometricService.isBiometricEnabled();
    final biometricAvailable = await biometricService.isAvailable();
    BiometricState.needsBiometric = biometricEnabled && biometricAvailable;
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Pov-Track',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}