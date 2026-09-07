import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';

  // ─── Platform check ───────────────────────────────────────────────
  /// Returns true only on Android/iOS. Web & Desktop don't support biometric.
  bool get _isMobilePlatform {
    // kIsWeb is true when running in a browser
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // ─── Check device capability ──────────────────────────────────────
  /// Check if the device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    if (!_isMobilePlatform) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('[BiometricService] Device support check error: $e');
      return false;
    }
  }

  /// Check if biometrics are enrolled on the device
  Future<bool> canCheckBiometrics() async {
    if (!_isMobilePlatform) return false;
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('[BiometricService] Can check biometrics error: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (!_isMobilePlatform) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] Get biometrics error: $e');
      return [];
    }
  }

  /// Check if biometric auth is available (mobile + device supported + enrolled)
  Future<bool> isAvailable() async {
    if (!_isMobilePlatform) return false;
    final supported = await isDeviceSupported();
    final canCheck = await canCheckBiometrics();
    return supported && canCheck;
  }

  // ─── Authenticate ─────────────────────────────────────────────────
  /// Trigger biometric authentication prompt
  /// Returns true if authentication succeeded
  Future<bool> authenticate({
    String reason = 'Verifikasi identitas untuk membuka Pov-Track',
  }) async {
    if (!_isMobilePlatform) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('[BiometricService] Auth error: $e');
      return false;
    }
  }

  // ─── Preference Management ────────────────────────────────────────
  /// Check if user has enabled biometric lock
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('[BiometricService] Read preference error: $e');
      return false;
    }
  }

  /// Set biometric lock preference
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
    debugPrint('[BiometricService] Biometric enabled: $enabled');
  }

  /// Clear biometric preference (used on logout)
  Future<void> clearPreference() async {
    await _storage.delete(key: _biometricEnabledKey);
  }
}
