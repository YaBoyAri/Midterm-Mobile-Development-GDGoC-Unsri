import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/receipt_scanner_service.dart';

/// Riverpod provider for ReceiptScannerService.
final receiptScannerProvider = Provider<ReceiptScannerService>((ref) {
  final service = ReceiptScannerService();
  ref.onDispose(() => service.dispose());
  return service;
});
