import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../data/services/biometric_service.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric prompt on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await BiometricService().authenticate();

      if (success && mounted) {
        BiometricState.hasVerified = true;
        context.go('/');
      } else if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Verifikasi gagal. Coba lagi.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Terjadi kesalahan. Coba lagi.';
        });
      }
    }
  }

  void _skipToLogin() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surface,
              Color(0xFF0A0F1E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.wallet_3,
                  color: Colors.white,
                  size: 40,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 24),

              // Title
              const Text(
                'Pov-Track',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 8),

              const Text(
                'Verifikasi identitas untuk melanjutkan',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

              const Spacer(flex: 1),

              // Fingerprint Icon with pulse animation
              GestureDetector(
                onTap: _isAuthenticating ? null : _authenticate,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Iconsax.finger_scan,
                    size: 44,
                    color: _isAuthenticating
                        ? AppTheme.primaryLight
                        : AppTheme.textSecondary,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.08, 1.08),
                    duration: 1500.ms,
                    curve: Curves.easeInOut,
                  )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 500.ms),

              const SizedBox(height: 20),

              // Status text
              if (_isAuthenticating)
                const Text(
                  'Memverifikasi...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(duration: 300.ms)
              else
                Text(
                  _errorMessage ?? 'Sentuh sensor sidik jari',
                  style: TextStyle(
                    fontSize: 14,
                    color: _errorMessage != null
                        ? AppTheme.expense
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 16),

              // Retry button (shown when not authenticating)
              if (!_isAuthenticating)
                TextButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Iconsax.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryLight,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

              const Spacer(flex: 2),

              // Fallback: use password
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: TextButton(
                  onPressed: _skipToLogin,
                  child: const Text(
                    'Gunakan Password',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.textMuted,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
