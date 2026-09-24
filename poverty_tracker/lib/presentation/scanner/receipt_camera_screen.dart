import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/receipt_data.dart';
import '../../data/services/receipt_scanner_service.dart';

/// Custom camera screen for scanning receipts.
/// Features: live camera preview, flash toggle, gallery picker.
/// Returns [ReceiptData] via Navigator.pop when user confirms scan results.
class ReceiptCameraScreen extends StatefulWidget {
  const ReceiptCameraScreen({super.key});

  @override
  State<ReceiptCameraScreen> createState() => _ReceiptCameraScreenState();
}

class _ReceiptCameraScreenState extends State<ReceiptCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.off;

  final _receiptScanner = ReceiptScannerService();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _receiptScanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[ReceiptCamera] No cameras available');
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('[ReceiptCamera] Init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka kamera: $e'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    }
  }

  // ─── Flash Control ────────────────────────────────────────────────
  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    final newMode = _flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;

    try {
      await _controller!.setFlashMode(newMode);
      setState(() => _flashMode = newMode);
    } catch (e) {
      debugPrint('[ReceiptCamera] Flash error: $e');
    }
  }

  // ─── Capture Photo ────────────────────────────────────────────────
  Future<void> _capturePhoto() async {
    if (_controller == null || _isCapturing || _isProcessing) return;

    setState(() => _isCapturing = true);

    try {
      // Turn off torch before capture (use flash.auto or flash.off for capture)
      if (_flashMode == FlashMode.torch) {
        await _controller!.setFlashMode(FlashMode.auto);
      }

      final xFile = await _controller!.takePicture();

      // Restore flash mode
      if (_flashMode == FlashMode.torch) {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      await _processImage(File(xFile.path));
    } catch (e) {
      debugPrint('[ReceiptCamera] Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // ─── Pick from Gallery ────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (xFile == null) return;
      await _processImage(File(xFile.path));
    } catch (e) {
      debugPrint('[ReceiptCamera] Gallery error: $e');
    }
  }

  // ─── Process Image with OCR ───────────────────────────────────────
  Future<void> _processImage(File imageFile) async {
    setState(() => _isProcessing = true);

    try {
      final result = await _receiptScanner.scanReceipt(imageFile);
      if (!mounted) return;

      setState(() => _isProcessing = false);
      _showScanResult(result, imageFile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses gambar: $e'),
          backgroundColor: AppTheme.expense,
        ),
      );
    }
  }

  // ─── Show Scan Results ────────────────────────────────────────────
  void _showScanResult(ReceiptData result, File imageFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: result.hasData
                          ? AppTheme.incomeGradient
                          : AppTheme.expenseGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      result.hasData ? Iconsax.scan : Iconsax.warning_2,
                      color: Colors.white, size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.hasData ? 'Hasil Scan Struk' : 'Data Tidak Terdeteksi',
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          result.hasData
                              ? 'Review data sebelum digunakan'
                              : 'Coba foto ulang dengan lebih jelas',
                          style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Image preview (tap to view full-screen)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Image.file(imageFile),
                            ),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close, color: Colors.white, size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 220,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: 220,
                          ),
                        ),
                      ),
                      // "Tap to zoom" hint
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.search_zoom_in,
                                  color: Colors.white70, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Tap untuk zoom',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Result rows
              _buildResultRow(
                Iconsax.money_recive, 'Nominal',
                result.amount != null ? _formatAmount(result.amount!) : null,
                AppTheme.income,
              ),
              const SizedBox(height: 10),
              _buildResultRow(
                Iconsax.calendar_1, 'Tanggal',
                result.date != null
                    ? DateFormat('dd MMMM yyyy', 'id_ID').format(result.date!)
                    : null,
                AppTheme.primaryLight,
              ),
              const SizedBox(height: 10),
              _buildResultRow(
                Iconsax.shop, 'Merchant',
                result.merchantName,
                AppTheme.warning,
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Iconsax.refresh, size: 18),
                      label: const Text('Foto Ulang'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (result.hasData) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx); // close bottom sheet
                            Navigator.pop(context, result); // return to caller
                          },
                          icon: const Icon(Iconsax.tick_circle, size: 18),
                          label: const Text('Gunakan Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String? value, Color color) {
    final detected = value != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: detected ? color.withOpacity(0.08) : AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: detected ? color.withOpacity(0.2) : AppTheme.border.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: detected ? color : AppTheme.textMuted, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(
            fontSize: 13,
            color: detected ? AppTheme.textSecondary : AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          )),
          const Spacer(),
          Flexible(
            child: Text(
              value ?? 'Tidak terdeteksi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: detected ? FontWeight.w700 : FontWeight.w400,
                color: detected ? AppTheme.textPrimary : AppTheme.textMuted,
                fontStyle: detected ? FontStyle.normal : FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final intValue = amount.toInt();
    final formatted = intValue.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  // ─── Build UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            Center(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryLight),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16, right: 16, bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Iconsax.arrow_left,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Struk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 42), // Balance the back button
                ],
              ),
            ),
          ),

          // Guide text
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 40, right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Arahkan kamera ke struk belanja',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 32, right: 32, top: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Flash toggle
                  GestureDetector(
                    onTap: _toggleFlash,
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: _flashMode == FlashMode.torch
                            ? AppTheme.warning.withOpacity(0.3)
                            : Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _flashMode == FlashMode.torch
                              ? AppTheme.warning
                              : Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _flashMode == FlashMode.torch
                            ? Iconsax.flash_15
                            : Iconsax.flash_slash,
                        color: _flashMode == FlashMode.torch
                            ? AppTheme.warning
                            : Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),

                  // Capture button
                  GestureDetector(
                    onTap: _isCapturing ? null : _capturePhoto,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white, width: 4,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                        ),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                  strokeWidth: 3,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Gallery button
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Iconsax.gallery,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Iconsax.scan_barcode,
                        color: Colors.white, size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Membaca struk...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ML Kit sedang memproses gambar',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryLight,
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
