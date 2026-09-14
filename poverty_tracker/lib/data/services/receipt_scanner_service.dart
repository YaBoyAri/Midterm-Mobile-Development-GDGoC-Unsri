import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/receipt_data.dart';

/// Service for scanning receipts using Google ML Kit Text Recognition.
/// ML Kit runs 100% on-device — no internet required after initial model download.
class ReceiptScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  // ─── Platform check ───────────────────────────────────────────────
  /// Returns true only on Android/iOS. Web & Desktop don't support ML Kit.
  bool get isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // ─── Main scan method ─────────────────────────────────────────────
  /// Scans an image file for receipt data using ML Kit OCR.
  /// Returns [ReceiptData] with extracted amount, date, and merchant.
  Future<ReceiptData> scanReceipt(File imageFile) async {
    if (!isMobilePlatform) {
      throw UnsupportedError(
        'Receipt scanning hanya tersedia di perangkat mobile (Android/iOS)',
      );
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      debugPrint('[ReceiptScanner] Raw text:\n${recognizedText.text}');

      return _parseReceiptText(recognizedText.text);
    } catch (e) {
      debugPrint('[ReceiptScanner] Scan error: $e');
      return ReceiptData(rawText: '', allAmounts: []);
    }
  }

  // ─── Text parsing ─────────────────────────────────────────────────
  /// Parse raw OCR text to extract amount, date, and merchant name.
  ReceiptData _parseReceiptText(String rawText) {
    if (rawText.trim().isEmpty) {
      return ReceiptData(rawText: rawText, allAmounts: []);
    }

    final lines = rawText.split('\n').map((l) => l.trim()).toList();

    final amount = _extractAmount(rawText);
    final allAmounts = _extractAllAmounts(rawText);
    final date = _extractDate(rawText);
    final merchant = _extractMerchant(lines);

    debugPrint('[ReceiptScanner] Parsed → '
        'amount: $amount, date: $date, merchant: $merchant, '
        'allAmounts: $allAmounts');

    return ReceiptData(
      amount: amount,
      date: date,
      merchantName: merchant,
      rawText: rawText,
      allAmounts: allAmounts,
    );
  }

  // ─── Amount extraction ────────────────────────────────────────────
  /// Extract the "Total" amount from the receipt.
  /// Priority: Grand Total > Total > Jumlah > fallback to largest number.
  /// Excludes: Tunai, Cash, Kembalian, Payment (those are payment amounts,
  /// not the actual total — e.g. Tunai 200.000 vs Total 191.475).
  double? _extractAmount(String text) {
    // Split into lines for line-by-line analysis
    final lines = text.split('\n');

    // Priority 1: "Grand Total" — highest priority
    final grandTotalResult = _findAmountByKeyword(lines, [
      'grand total', 'grand_total', 'grandtotal',
    ]);
    if (grandTotalResult != null) return grandTotalResult;

    // Priority 2: "Total" — but NOT "Subtotal"
    final totalResult = _findTotalAmount(lines);
    if (totalResult != null) return totalResult;

    // Priority 3: "Jumlah" keyword
    final jumlahResult = _findAmountByKeyword(lines, ['jumlah']);
    if (jumlahResult != null) return jumlahResult;

    // Fallback: return the largest number found (with thousand separators)
    return _findLargestAmount(text);
  }

  /// Find amount on a line containing "Total" but NOT "Subtotal".
  double? _findTotalAmount(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase().trim();
      // Must contain "total" but NOT "subtotal"
      if (lower.contains('total') && !lower.contains('subtotal')) {
        final amount = _extractNumberFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }
    return null;
  }

  /// Find amount on a line matching any of the given keywords.
  double? _findAmountByKeyword(List<String> lines, List<String> keywords) {
    for (final line in lines) {
      final lower = line.toLowerCase().trim();
      for (final keyword in keywords) {
        if (lower.contains(keyword)) {
          final amount = _extractNumberFromLine(line);
          if (amount != null && amount > 0) return amount;
        }
      }
    }
    return null;
  }

  /// Extract a number (with Rp prefix or thousand separators) from a single line.
  double? _extractNumberFromLine(String line) {
    // Try "Rp" prefixed number first
    final rpMatch = RegExp(
      r'[Rr][Pp]\.?\s*([\d]+(?:[.,]\d{3})*)',
    ).firstMatch(line);
    if (rpMatch != null) {
      return _parseNumber(rpMatch.group(1)!);
    }

    // Try number with thousand separators
    final numMatch = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)').firstMatch(line);
    if (numMatch != null) {
      return _parseNumber(numMatch.group(1)!);
    }

    // Try plain number (for cases like "43500")
    final plainMatch = RegExp(r'(\d{4,})').firstMatch(line);
    if (plainMatch != null) {
      return double.tryParse(plainMatch.group(1)!);
    }

    return null;
  }

  /// Fallback: find the largest amount in the entire text.
  double? _findLargestAmount(String text) {
    final amounts = <double>[];
    final numPattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)');
    for (final match in numPattern.allMatches(text)) {
      final value = _parseNumber(match.group(1)!);
      if (value != null && value > 0) amounts.add(value);
    }
    if (amounts.isEmpty) return null;
    amounts.sort((a, b) => b.compareTo(a));
    return amounts.first;
  }

  /// Extract all amounts found in text (for user review).
  List<String> _extractAllAmounts(String text) {
    final amounts = <String>{};

    final numPattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)');
    for (final match in numPattern.allMatches(text)) {
      final value = _parseNumber(match.group(1)!);
      if (value != null && value >= 100) {
        amounts.add(_formatCurrency(value));
      }
    }

    return amounts.toList()
      ..sort((a, b) {
        final aVal = _parseNumber(a.replaceAll('Rp ', '').replaceAll('.', '')) ?? 0;
        final bVal = _parseNumber(b.replaceAll('Rp ', '').replaceAll('.', '')) ?? 0;
        return bVal.compareTo(aVal);
      });
  }

  /// Parse a number string, handling both . and , as thousand separators.
  double? _parseNumber(String text) {
    // Remove common thousand separators
    String cleaned = text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  /// Format a number as Indonesian currency string.
  String _formatCurrency(double value) {
    final intValue = value.toInt();
    final formatted = intValue
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }

  // ─── Date extraction ──────────────────────────────────────────────
  /// Extract date from text. Supports multiple Indonesian date formats.
  DateTime? _extractDate(String text) {
    // Pattern 1: dd/MM/yyyy or dd-MM-yyyy
    final datePattern1 = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{4})');
    final match1 = datePattern1.firstMatch(text);
    if (match1 != null) {
      try {
        final day = int.parse(match1.group(1)!);
        final month = int.parse(match1.group(2)!);
        final year = int.parse(match1.group(3)!);
        if (_isValidDate(day, month, year)) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    // Pattern 2: dd/MM/yy (2-digit year)
    final datePattern2 = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{2})(?!\d)');
    final match2 = datePattern2.firstMatch(text);
    if (match2 != null) {
      try {
        final day = int.parse(match2.group(1)!);
        final month = int.parse(match2.group(2)!);
        final year = 2000 + int.parse(match2.group(3)!);
        if (_isValidDate(day, month, year)) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    // Pattern 3: yyyy-MM-dd (ISO format)
    final datePattern3 = RegExp(r'(\d{4})[/\-](\d{2})[/\-](\d{2})');
    final match3 = datePattern3.firstMatch(text);
    if (match3 != null) {
      try {
        final year = int.parse(match3.group(1)!);
        final month = int.parse(match3.group(2)!);
        final day = int.parse(match3.group(3)!);
        if (_isValidDate(day, month, year)) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    return null;
  }

  /// Validate a date.
  bool _isValidDate(int day, int month, int year) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    if (year < 2000 || year > 2100) return false;
    try {
      final date = DateTime(year, month, day);
      return date.day == day && date.month == month && date.year == year;
    } catch (_) {
      return false;
    }
  }

  // ─── Merchant extraction ──────────────────────────────────────────
  /// Known POS system brand names — these are NOT the merchant.
  /// e.g. "BEEPOS" is the POS software, "Cafe Bee" is the actual merchant.
  static final _posSystemNames = RegExp(
    r'^(beepos|moka\s*pos|pawoon|majoo|gobiz|qasir|olsera|ireap|vend|'
    r'toast|clover|square|lightspeed|pos\s*system|kasir\s*pintar)',
    caseSensitive: false,
  );

  /// Patterns that indicate a line is an address, not a merchant name.
  static final _addressPattern = RegExp(
    r'(^jl[.\s]|^jln[.\s]|^jalan\s|no\.?\s*\d|^ruko\s|^gedung\s|'
    r'^komplek|^blok\s|\d{5})',  // postal code
    caseSensitive: false,
  );

  /// Patterns that indicate a line is a phone number.
  static final _phonePattern = RegExp(
    r'^[\d\s\-()]{7,}$|^\(?0\d{2,3}\)?[\s\-]?\d',
  );

  /// Patterns for URLs, emails, and other non-merchant lines.
  static final _skipPattern = RegExp(
    r'(www\.|http|\.com|\.id|@|struk|receipt|nota|invoice|faktur|'
    r'kwitansi|supported\s*by|powered\s*by|\*{2,}|\-{3,}|={3,})',
    caseSensitive: false,
  );

  /// Tagline patterns (slogans, mottos — not merchant names).
  static final _taglinePattern = RegExp(
    r'(belanja\s*puas|harga\s*pas|pasti\s*hemat|lebih\s*hemat|'
    r'selalu\s*ada|setiap\s*hari|terima\s*kasih|thank\s*you)',
    caseSensitive: false,
  );

  /// Extract merchant name from receipt.
  ///
  /// Strategy based on real Indonesian receipt patterns:
  /// - Line 1 = usually the logo/POS brand (e.g. "BEEPOS", "Alfamart")
  /// - Line 2-4 = actual merchant/store name + address
  /// - Exception: sometimes the logo IS the merchant (e.g. "BreadTalk")
  ///
  /// We look for the first "name-like" line after the logo,
  /// skipping addresses, phones, URLs, and taglines.
  /// If no candidate found after logo, fall back to line 1 itself.
  String? _extractMerchant(List<String> lines) {
    // Get the first 6 non-empty lines (header area of receipt)
    final headerLines = lines
        .where((l) => l.trim().length > 2)
        .take(6)
        .toList();

    if (headerLines.isEmpty) return null;

    final firstLine = headerLines[0].trim();
    final isFirstLinePosSystem = _posSystemNames.hasMatch(firstLine);

    // Look for merchant name in lines after the first line
    // (since first line is usually the logo)
    for (int i = 1; i < headerLines.length; i++) {
      final line = headerLines[i].trim();

      // Stop searching once we hit transaction data area
      if (_isTransactionDataLine(line)) break;

      // Skip non-merchant lines
      if (_addressPattern.hasMatch(line)) continue;
      if (_phonePattern.hasMatch(line)) continue;
      if (_skipPattern.hasMatch(line)) continue;
      if (_taglinePattern.hasMatch(line)) continue;
      if (RegExp(r'^\d+[/\-.,:\s\d]*$').hasMatch(line)) continue;

      // This line looks like a merchant name!
      return _cleanMerchantName(line);
    }

    // Fallback: if first line is NOT a POS system, it's likely the
    // merchant itself (e.g. "BreadTalk", "McDonald's")
    if (!isFirstLinePosSystem && firstLine.length >= 3) {
      return _cleanMerchantName(firstLine);
    }

    return null;
  }

  /// Check if a line looks like transaction data (items, amounts, dates)
  /// which means we've passed the header area.
  bool _isTransactionDataLine(String line) {
    final lower = line.toLowerCase();
    // Lines like "Tanggal:", "Kasir:", "No Trx:", item listings
    return lower.startsWith('tanggal') ||
        lower.startsWith('kasir') ||
        lower.startsWith('no trx') ||
        lower.startsWith('no.') ||
        lower.startsWith('check') ||
        lower.startsWith('member') ||
        lower.startsWith('channel') ||
        RegExp(r'^\d+\s*(x|X)\s*\d').hasMatch(line); // "2 x 12,000"
  }

  /// Clean up merchant name: trim length, remove trailing symbols.
  String _cleanMerchantName(String name) {
    // Remove trailing special characters
    String cleaned = name.replaceAll(RegExp(r'[®™©]+'), '').trim();
    // Limit length
    if (cleaned.length > 40) cleaned = cleaned.substring(0, 40).trim();
    return cleaned;
  }

  // ─── Cleanup ──────────────────────────────────────────────────────
  /// Dispose the text recognizer to free resources.
  void dispose() {
    _textRecognizer.close();
  }
}
