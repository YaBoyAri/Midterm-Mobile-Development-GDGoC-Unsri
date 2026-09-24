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

      return _parseReceiptText(recognizedText);
    } catch (e) {
      debugPrint('[ReceiptScanner] Scan error: $e');
      return ReceiptData(rawText: '', allAmounts: []);
    }
  }

  // ─── Text parsing ─────────────────────────────────────────────────
  /// Parse OCR result to extract amount, date, and merchant name.
  ReceiptData _parseReceiptText(RecognizedText recognizedText) {
    final rawText = recognizedText.text;
    if (rawText.trim().isEmpty) {
      return ReceiptData(rawText: rawText, allAmounts: []);
    }

    // Rebuild rows using each line's bounding box instead of trusting the
    // '\n' order in `.text`. On a two-column receipt (label left, amount
    // right), ML Kit can return the label column and the amount column as
    // separate text blocks, so `.text` may list every label first and
    // every amount after — which silently breaks "Total" ↔ "191.475"
    // pairing and lets the amount extractor fall through to the wrong
    // priority (e.g. picking up "TUNAI 200.000" instead of "Total 191.475").
    final rows = _reconstructRows(recognizedText);

    debugPrint('[ReceiptScanner] === Reconstructed ${rows.length} rows ===');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].trim().isNotEmpty) {
        debugPrint('[ReceiptScanner]   [$i] "${rows[i]}"');
      }
    }

    final amount = _extractAmount(rows);
    final allAmounts = _extractAllAmounts(rawText);
    final date = _extractDate(rawText);
    final merchant = _extractMerchant(rows);
    final note = _inferNote(merchant, rawText);

    debugPrint('[ReceiptScanner] Parsed → '
        'amount: $amount, date: $date, merchant: $merchant, '
        'note: $note, allAmounts: $allAmounts');

    return ReceiptData(
      amount: amount,
      date: date,
      merchantName: merchant,
      note: note,
      rawText: rawText,
      allAmounts: allAmounts,
    );
  }

  // ─── Row reconstruction (fixes column-order OCR bug) ───────────────
  /// Rebuilds receipt text as visual rows using each recognized line's
  /// bounding box, grouping lines that sit on the same vertical band and
  /// ordering them left-to-right by x-position.
  ///
  /// This makes "Total" and its number end up on the same reconstructed
  /// row regardless of which ML Kit text block each one came from —
  /// which is what the old `.text.split('\n')` approach could not
  /// guarantee for two-column receipts.
  List<String> _reconstructRows(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    if (allLines.isEmpty) return [];

    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rows = <List<TextLine>>[];
    for (final line in allLines) {
      final lineTop = line.boundingBox.top.toDouble();
      final lineBottom = line.boundingBox.bottom.toDouble();
      final lineHeight = lineBottom - lineTop;
      // How much vertical overlap counts as "same row" on the receipt.
      final tolerance = lineHeight * 0.6;

      List<TextLine>? matchedRow;
      for (final row in rows) {
        final rowTop = row
            .map((l) => l.boundingBox.top.toDouble())
            .reduce((a, b) => a < b ? a : b);
        final rowBottom = row
            .map((l) => l.boundingBox.bottom.toDouble())
            .reduce((a, b) => a > b ? a : b);
        final overlaps =
            lineTop < rowBottom - tolerance && lineBottom > rowTop + tolerance;
        if (overlaps) {
          matchedRow = row;
          break;
        }
      }

      if (matchedRow != null) {
        matchedRow.add(line);
      } else {
        rows.add([line]);
      }
    }

    return rows.map((row) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      return row.map((l) => l.text.trim()).join('   ');
    }).toList();
  }

  // ─── Amount extraction ────────────────────────────────────────────
  /// Lines that represent customer payment, change, or non-purchase amounts.
  static final _paymentOrChangePattern = RegExp(
    r'\b(tunai|cash|kembali|kembalian|change|kembal1|bayar|dibayar|payment|'
    r'debit|kredit|credit|qris|gopay|ovo|dana|shopeepay|kartu)\b',
    caseSensitive: false,
  );

  /// Extract the "Total" amount from the reconstructed rows.
  ///
  /// Strategy:
  ///  1. Look for "Grand Total" keyword → extract that number
  ///  2. Look for "Total" keyword (not subtotal, not payment) → extract that number
  ///  3. Look for "Jumlah" keyword → extract that number
  ///  4. Math: Tunai - Kembalian (when OCR misreads label or column is separated)
  ///  5. Fallback: largest amount in non-payment rows
  double? _extractAmount(List<String> lines) {
    debugPrint('[ReceiptScanner] === Scanning ${lines.length} rows for amount ===');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        debugPrint('[ReceiptScanner]   [$i] "${lines[i].trim()}"');
      }
    }

    // Priority 1: Grand Total
    final grandTotal = _findTotalLine(lines, ['grand total', 'grand_total', 'grandtotal']);
    if (grandTotal != null) {
      debugPrint('[ReceiptScanner] ✓ Amount from Grand Total: $grandTotal');
      return grandTotal;
    }

    // Priority 2: Total keyword (strict: not subtotal, not payment lines)
    final total = _findTotalLine(lines, ['total']);
    if (total != null) {
      debugPrint('[ReceiptScanner] ✓ Amount from Total: $total');
      return total;
    }

    // Priority 3: Jumlah keyword
    final jumlah = _findTotalLine(lines, ['jumlah']);
    if (jumlah != null) {
      debugPrint('[ReceiptScanner] ✓ Amount from Jumlah: $jumlah');
      return jumlah;
    }

    // Priority 4: Math — Tunai minus Kembalian
    final math = _calculateFromTunaiKembali(lines);
    if (math != null) {
      debugPrint('[ReceiptScanner] ✓ Amount from Tunai-Kembalian math: $math');
      return math;
    }

    // Fallback: largest amount in non-payment lines
    final fallback = _largestExcludingPayment(lines);
    debugPrint('[ReceiptScanner] ✓ Amount from fallback: $fallback');
    return fallback;
  }

  /// Finds the amount from the first row matching any of the keywords,
  /// strictly excluding subtotal, payment, and label-only rows.
  /// If the matching row has no number, looks at the next 1-2 rows.
  double? _findTotalLine(List<String> lines, List<String> keywords) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();

      // Must match at least one keyword
      if (!keywords.any((kw) => lower.contains(kw))) continue;

      // Skip subtotal
      if (lower.contains('subtotal')) continue;

      // Skip payment lines — e.g. "Total Bayar", "Total Tunai"
      if (_paymentOrChangePattern.hasMatch(lower)) continue;

      // Skip lines like "Total Item", "Total Qty", "Total Pcs"
      if (RegExp(r'total\s*(item|qty|pcs|barang)', caseSensitive: false)
          .hasMatch(lower)) {
        continue;
      }

      debugPrint('[ReceiptScanner] _findTotalLine: matched "$line"');

      // Try to get number from the same row (this now succeeds far more
      // often than before, since the row already has label + value merged)
      final amount = _extractNumberFromLine(line);
      // Guard: if amount is suspiciously small (< 500), OCR may have
      // truncated the thousands part (e.g. read "Rp38" instead of "Rp38.000").
      // In that case, treat it as not-found and look ahead for a better match.
      if (amount != null && amount >= 500) {
        debugPrint('[ReceiptScanner]   → same row amount: $amount');
        return amount;
      }
      if (amount != null && amount < 500) {
        debugPrint('[ReceiptScanner]   → same row amount $amount is suspiciously small, trying lookahead');
      }

      // Look ahead for the number (in case it's still on its own row)
      for (int j = i + 1; j <= i + 3 && j < lines.length; j++) {
        final nextLine = lines[j].trim();
        final nextLower = nextLine.toLowerCase();

        // Stop if next row is a payment line
        if (_paymentOrChangePattern.hasMatch(nextLower)) {
          debugPrint('[ReceiptScanner]   → lookahead stopped at payment row: "$nextLine"');
          break;
        }
        // Stop if next row is another total-type label (avoid jumping too far)
        if (RegExp(r'^(subtotal|total|jumlah|pajak|tax|diskon|discount)',
                caseSensitive: false)
            .hasMatch(nextLower)) {
          debugPrint('[ReceiptScanner]   → lookahead stopped at label: "$nextLine"');
          break;
        }

        final nextAmount = _extractNumberFromLine(nextLine);
        if (nextAmount != null && nextAmount > 0) {
          debugPrint('[ReceiptScanner]   → lookahead amount from "$nextLine": $nextAmount');
          return nextAmount;
        }
      }
    }
    return null;
  }

  /// Math / Tunai fallback:
  /// - If Tunai and Kembalian both exist: Total = Tunai - Kembalian
  /// - If Tunai exists but NO Kembalian (e.g. Alfamart "Lunas"): Tunai == Total
  double? _calculateFromTunaiKembali(List<String> lines) {
    double? tunai;
    double? kembali;

    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase().trim();
      if ((lower.contains('tunai') || lower.contains('cash')) && tunai == null) {
        tunai = _extractNumberFromLine(lines[i]);
        if (tunai == null && i + 1 < lines.length) {
          tunai = _extractNumberFromLine(lines[i + 1]);
        }
        debugPrint('[ReceiptScanner] Tunai: $tunai');
      } else if ((lower.contains('kembali') || lower.contains('change')) &&
          kembali == null) {
        kembali = _extractNumberFromLine(lines[i]);
        if (kembali == null && i + 1 < lines.length) {
          kembali = _extractNumberFromLine(lines[i + 1]);
        }
        debugPrint('[ReceiptScanner] Kembalian: $kembali');
      }
    }

    if (tunai != null && kembali != null && tunai > kembali) {
      // Standard case: customer paid more than total (received change)
      return tunai - kembali;
    }
    if (tunai != null && kembali == null && tunai >= 500) {
      // "Lunas" / exact payment case: no kembalian, Tunai = Total
      debugPrint('[ReceiptScanner] No kembalian found, using Tunai directly: $tunai');
      return tunai;
    }
    return null;
  }

  /// Largest amount in receipt, excluding payment/change rows and phone numbers.
  double? _largestExcludingPayment(List<String> lines) {
    final candidates = <double>[];
    // Phone numbers pattern: 8+ consecutive digits not in a thousand-group format
    final phoneNumPattern = RegExp(r'\b0\d{7,}\b|\b\d{8,}\b');
    for (final line in lines) {
      if (_paymentOrChangePattern.hasMatch(line)) continue;
      // Skip lines that look like phone numbers
      if (phoneNumPattern.hasMatch(line.replaceAll(RegExp(r'[\s\-()]'), ''))) {
        // Only skip if the big number IS the phone number (no Rp prefix)
        if (!RegExp(r'[Rr][Pp]').hasMatch(line)) continue;
      }
      // Only match numbers with proper thousand grouping (not raw phone digits)
      final numMatch = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)').firstMatch(line);
      if (numMatch != null) {
        final val = _parseNumber(numMatch.group(1)!);
        if (val != null && val >= 500) candidates.add(val);
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  /// Extract a number (with Rp prefix or thousand separators) from a single row.
  /// Also handles the split OCR case where "Rp38" and ".000" are adjacent tokens.
  double? _extractNumberFromLine(String line) {
    // Pre-process: rejoin common OCR split patterns like "Rp38 .000", "Rp38. 000", "38 .000"
    // These occur when the font on thermal printers causes the printer to split a number
    final normalized = _normalizeNumberSpacing(line);

    // Try "Rp" prefixed number first (allows spaces around dots/commas)
    final rpMatch = RegExp(
      r'[Rr][Pp]\.?\s*([\d]+(?:\s*[.,]?\s*\d{3})*)',
    ).firstMatch(normalized);
    if (rpMatch != null) {
      final val = _parseNumber(rpMatch.group(1)!);
      if (val != null && val >= 1) return val;
    }

    // Try number with thousand separators (e.g. "191,475", "191.475", "191 475")
    final numMatch = RegExp(r'(\d{1,3}(?:\s*[.,]?\s*\d{3})+)').firstMatch(normalized);
    if (numMatch != null) return _parseNumber(numMatch.group(1)!);

    // Try plain large number (for cases like "43500")
    final plainMatch = RegExp(r'(\d{4,})').firstMatch(normalized);
    if (plainMatch != null) return double.tryParse(plainMatch.group(1)!);

    return null;
  }

  /// Normalize number spacing: collapses patterns like "38 .000", "38. 000", "38 000"
  /// back into "38.000" so the regex can parse them correctly.
  String _normalizeNumberSpacing(String line) {
    // Pattern: digits followed by space(s) then optional dot/comma then digits{3}
    // e.g. "38 .000" → "38.000", "38 000" → "38.000", "38. 000" → "38.000"
    return line
        .replaceAllMapped(
          RegExp(r'(\d)\s+([.,])(\d{3})'),
          (m) => '${m[1]}${m[2]}${m[3]}',
        )
        .replaceAllMapped(
          RegExp(r'(\d)([.,])\s+(\d{3})'),
          (m) => '${m[1]}${m[2]}${m[3]}',
        )
        .replaceAllMapped(
          RegExp(r'(\d)\s+(\d{3})(?!\d)'),
          (m) => '${m[1]}.${m[2]}',
        );
  }

  /// Extract all amounts found in text (for user review).
  List<String> _extractAllAmounts(String text) {
    final amounts = <String>{};

    final numPattern = RegExp(r'(\d{1,3}(?:\s*[.,]?\s*\d{3})+)');
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

  /// Parse a number string, handling both . and , and spaces as thousand separators.
  double? _parseNumber(String text) {
    String cleaned = text.replaceAll('.', '').replaceAll(',', '').replaceAll(' ', '');
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
    // Pattern 1: d.M.yyyy or dd.MM.yyyy (dot separator — Alfamart, Indomaret)
    // Also handles spaces after dots: "03. 08. 21", "18. 7. 2024"
    final datePatternDot4 = RegExp(r'(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})');
    for (final m in datePatternDot4.allMatches(text)) {
      try {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final year = int.parse(m.group(3)!);
        if (_isValidDate(day, month, year)) return DateTime(year, month, day);
      } catch (_) {}
    }

    // Pattern 2: dd/MM/yyyy or dd-MM-yyyy (slash or dash, 4-digit year)
    final datePattern1 = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})');
    for (final m in datePattern1.allMatches(text)) {
      try {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final year = int.parse(m.group(3)!);
        if (_isValidDate(day, month, year)) return DateTime(year, month, day);
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
        if (_isValidDate(day, month, year)) return DateTime(year, month, day);
      } catch (_) {}
    }

    // Pattern 4: d.M.yy or dd.MM.yy (dot separator, 2-digit year)
    // Also handles spaces after dots: "03. 08. 21"
    final datePatternDot2 = RegExp(r'(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2})(?!\d)');
    for (final m in datePatternDot2.allMatches(text)) {
      try {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final year = 2000 + int.parse(m.group(3)!);
        // Sanity check: year should be between 2000 and 2099, and must be plausible
        if (year >= 2000 && year <= 2099 && _isValidDate(day, month, year)) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    // Pattern 5: dd/MM/yy or dd-MM-yy (slash or dash, 2-digit year)
    final datePattern2 = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{2})(?!\d)');
    final match2 = datePattern2.firstMatch(text);
    if (match2 != null) {
      try {
        final day = int.parse(match2.group(1)!);
        final month = int.parse(match2.group(2)!);
        final year = 2000 + int.parse(match2.group(3)!);
        if (_isValidDate(day, month, year)) return DateTime(year, month, day);
      } catch (_) {}
    }

    // Pattern 4: "dd MonthName yyyy" or "dd MonthName yy" (e.g. "24 Mei 2023", "10 May 19")
    final monthNames = {
      'jan': 1, 'january': 1, 'januari': 1,
      'feb': 2, 'february': 2, 'februari': 2,
      'mar': 3, 'march': 3, 'maret': 3,
      'apr': 4, 'april': 4,
      'may': 5, 'mei': 5,
      'jun': 6, 'june': 6, 'juni': 6,
      'jul': 7, 'july': 7, 'juli': 7,
      'aug': 8, 'august': 8, 'agustus': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10, 'oktober': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12, 'desember': 12,
    };

    final datePattern4 = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})',
    );
    for (final match in datePattern4.allMatches(text)) {
      try {
        final day = int.parse(match.group(1)!);
        final monthStr = match.group(2)!.toLowerCase();
        final yearStr = match.group(3)!;
        final month = monthNames[monthStr];
        if (month == null) continue;
        final year = yearStr.length == 2
            ? 2000 + int.parse(yearStr)
            : int.parse(yearStr);
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
  static final _posSystemNames = RegExp(
    r'^(beepos|moka\s*pos|pawoon|majoo|gobiz|qasir|olsera|ireap|vend|'
    r'toast|clover|square|lightspeed|pos\s*system|kasir\s*pintar)',
    caseSensitive: false,
  );

  /// Patterns that indicate a line is an address, not a merchant name.
  /// Handles OCR variations like "J1.", "JI.", cities, postal codes.
  static final _addressPattern = RegExp(
    r'(^j[l1i|/\\][.\s]|^jln[.\s]|^jalan\s|\bno\.?\s*\d|\bn0\.?\s*\d|'
    r'^ruko\s|^gedung\s|^komplek|^blok\s|\b\d{5}\b|'
    r'\b(jakarta|surabaya|bandung|medan|semarang|palembang|yogyakarta|jogja|'
    r'depok|tangerang|bekasi|bogor|bali|denpasar|malang|solo|makassar|'
    r'lampung|padang|pekanbaru|batam|balikpapan|samarinda)\b)',
    caseSensitive: false,
  );

  /// Patterns that indicate a line is a phone number.
  static final _phonePattern = RegExp(
    r'(\b(telp|telepon|phone|hp|wa|whatsapp|fax)[.:\s]|[\d\s\-()]{7,}$|^\(?0\d{2,3}\)?[\s\-]?\d)',
    caseSensitive: false,
  );

  /// Patterns for URLs, emails, and other non-merchant lines.
  static final _skipPattern = RegExp(
    r'(www\.|http|\.com|\.id|\.co|@|struk|receipt|nota|invoice|faktur|'
    r'kwitansi|supported\s*by|powered\s*by|\*{2,}|\-{3,}|={3,})',
    caseSensitive: false,
  );

  /// Tagline patterns (slogans, mottos — not merchant names).
  static final _taglinePattern = RegExp(
    r'(belanja\s*puas|harga\s*pas|pasti\s*hemat|lebih\s*hemat|'
    r'selalu\s*ada|setiap\s*hari|terima\s*kasih|thank\s*you|'
    r'selamat\s*datang|welcome|please\s*come|kami\s*hadir|'
    r'kepuasan\s*anda|melayani\s*dengan|terbaik\s*untuk|'
    r'belanja\s*hemat|hemat\s*lebih|maju\s*bersama)',
    caseSensitive: false,
  );

  bool _isAddress(String line) => _addressPattern.hasMatch(line);
  bool _isPhone(String line) => _phonePattern.hasMatch(line);
  bool _isSkip(String line) => _skipPattern.hasMatch(line);
  bool _isTagline(String line) => _taglinePattern.hasMatch(line);

  /// Extract merchant name from receipt.
  ///
  /// Strategy: Score-based candidate selection across first 10 rows.
  /// Uses bounding-box-sorted rows so header lines are always at the top.
  String? _extractMerchant(List<String> lines) {
    final headerLines = lines
        .where((l) => l.trim().length >= 3)
        .take(10)
        .toList();

    if (headerLines.isEmpty) return null;

    // City-only address pattern (no street markers like Jl./Ruko/postal code)
    final cityPattern = RegExp(
      r'\b(jakarta|surabaya|bandung|medan|semarang|palembang|yogyakarta|jogja|'
      r'depok|tangerang|bekasi|bogor|bali|denpasar|malang|solo|makassar|'
      r'lampung|padang|pekanbaru|batam|balikpapan|samarinda|lamongan|'
      r'pontianak|manado|ambon|jayapura|kupang|mataram|cirebon|kediri|'
      r'jawa|timur|selatan|barat|tengah|tengah|kalimantan|sulawesi|sumatra|'
      r'sumatera|kota|kabupaten)\b',
      caseSensitive: false,
    );
    final streetPattern = RegExp(
      r'(^j[l1i|/\\][.\s]|^jln[.\s]|^jalan\s|\bno\.?\s*\d|\bn0\.?\s*\d|'
      r'^ruko\s|^gedung\s|^komplek|^blok\s|\b\d{5}\b)',
      caseSensitive: false,
    );

    String? bestCandidate;
    int bestScore = 0;

    for (int i = 0; i < headerLines.length; i++) {
      final line = headerLines[i].trim();

      // Skip POS system names, phones, URLs, taglines (but don't break)
      if (_posSystemNames.hasMatch(line)) continue;
      if (_isPhone(line)) continue;
      if (_isSkip(line)) continue;
      if (_isTagline(line)) continue;

      // Skip lines that are purely numeric / separators
      if (RegExp(r'^[\d\s\-\./,:=\*\_]+$').hasMatch(line)) continue;

      // Skip POS operator lines: e.g. "1 POS1   1506551 WINDA APRIANI P"
      if (RegExp(r'^\d+\s+pos\d', caseSensitive: false).hasMatch(line)) continue;

      // Transaction data lines (Tanggal, Kasir, No Trx, item lines) — skip
      if (_isTransactionDataLine(line)) continue;

      // ── Handle address lines ──────────────────────────────────────────
      if (_isAddress(line)) {
        // Special case: "BrandName CityName" (e.g. "Alfamart Jogja").
        // The line is address-filtered only because of the city name.
        // Try to extract the word(s) before the city as merchant prefix.
        if (!streetPattern.hasMatch(line) && cityPattern.hasMatch(line)) {
          final prefix = line
              .replaceAll(cityPattern, '')
              .replaceAll(RegExp(r'[,;:\s]+$'), '')
              .trim();
          if (prefix.length >= 3 &&
              !RegExp(r'^[\d\s]+$').hasMatch(prefix) &&
              !_isPhone(prefix) &&
              !_isTagline(prefix)) {
            // Score the prefix as a merchant candidate (with position penalty
            // since it's extracted, not a clean line)
            final prefixScore = (10 - i) * 5 + 15;
            debugPrint('[ReceiptScanner] Branch prefix candidate[$i] "$prefix" score=$prefixScore');
            if (prefixScore > bestScore) {
              bestScore = prefixScore;
              bestCandidate = prefix;
            }
          }
        }
        continue;
      }

      int score = 0;

      // ── Position bonus: earlier rows = more likely header ──
      score += (10 - i) * 5;

      // ── Length: merchant names are typically 3–35 chars ──
      final len = line.length;
      if (len >= 3 && len <= 20) {
        score += 20;
      } else if (len <= 35) {
        score += 10;
      } else {
        score -= 5;
      }

      // ── All uppercase with no digits: strong merchant signal ──
      if (RegExp(r'^[A-Z][A-Z\s\-&\.]+$').hasMatch(line)) score += 15;

      // ── Mixed case / Title case / camelCase: strong signal ──
      if (RegExp(r'^[A-Z][a-z]').hasMatch(line) ||
          RegExp(r'[A-Z][a-z][A-Z]').hasMatch(line)) {
        score += 20;
      }

      // ── Contains quotes: very strong signal ("Kencana Swalayan") ──
      if (line.startsWith('"') || line.startsWith('\u201c') || line.startsWith("'")) {
        score += 25;
      }

      // ── Has brand suffix (® ™) ──
      if (RegExp(r'[®™©]').hasMatch(line)) score += 10;

      // ── Contains numbers: lower confidence ──
      if (RegExp(r'\d').hasMatch(line)) score -= 10;

      // ── Word count: 1–4 words typical for merchant names ──
      final wordCount = line.split(RegExp(r'\s+')).length;
      if (wordCount >= 1 && wordCount <= 4) {
        score += 5;
      } else if (wordCount > 5) {
        score -= 10;
      }

      if (score <= 0) continue;

      debugPrint('[ReceiptScanner] Merchant candidate[$i] "$line" score=$score');

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = line;
      }
    }

    if (bestCandidate != null) {
      return _cleanMerchantName(bestCandidate);
    }
    return null;
  }

  /// Check if a line looks like transaction data (items, amounts, dates).
  bool _isTransactionDataLine(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('tanggal') ||
        lower.startsWith('kasir') ||
        lower.startsWith('no trx') ||
        lower.startsWith('no.') ||
        lower.startsWith('check') ||
        lower.startsWith('member') ||
        lower.startsWith('channel') ||
        RegExp(r'^\d+\s*(x|X)\s*\d').hasMatch(line);
  }

  /// Clean up merchant name: trim length, remove trailing symbols.
  String _cleanMerchantName(String name) {
    String cleaned = name.replaceAll(RegExp(r'[®™©]+'), '').trim();
    if (cleaned.length > 40) cleaned = cleaned.substring(0, 40).trim();
    return cleaned;
  }

  // ─── Note inference ────────────────────────────────────────────
  /// Infer a descriptive note from the merchant name and/or raw OCR text.
  /// Returns a human-friendly description like "Belanja kebutuhan sehari-hari"
  /// instead of the raw store name. Falls back to the merchant name itself.
  String? _inferNote(String? merchant, String rawText) {
    // Build a combined search string from merchant name + first few lines of receipt
    final firstLines = rawText.split('\n').take(10).join(' ');
    final haystack = '${merchant ?? ''} $firstLines'.toLowerCase();

    // ── Category rules (checked in priority order) ──────────────────
    // Each entry: (list of keywords to match, note to return)
    final rules = <(List<String>, String)>[
      // Minimarket & Supermarket / Swalayan
      (
        ['alfamart', 'indomaret', 'alfamidi', 'superindo', 'giant',
         'carrefour', 'hypermart', 'lottemart', 'transmart', 'hero',
         'yogya', 'borma', 'freshmart', 'tip top', 'swalayan',
         'minimarket', 'toko sembako', 'toko kelontong', 'toserba'],
        'Belanja kebutuhan sehari-hari',
      ),
      // Fast food & restoran
      (
        ['mcdonald', 'mcdonalds', 'kfc', 'pizza hut', 'domino',
         'burger king', 'wendy', 'a&w', 'texas chicken', 'popeyes',
         'hokben', 'hoka hoka', 'marugame', 'yoshinoya', 'ramen',
         'restoran', 'restaurant', 'warung makan', 'rm ', 'rumah makan'],
        'Makan di restoran',
      ),
      // Café & minuman
      (
        ['starbucks', 'kopi kenangan', 'fore coffee', 'janji jiwa',
         'j.co', 'jco', 'chatime', 'gong cha', 'boba', 'teh tarik',
         'cafe', 'kafe', 'coffee', 'kopi', 'espresso', 'milktea',
         'minuman', 'beverage', 'drinks'],
        'Beli minuman/kopi',
      ),
      // Bakeri & kue
      (
        ['breadtalk', 'bread talk', 'holland bakery', 'dunkin',
         'dunkin donuts', 'krispy kreme', 'roti', 'bakeri', 'bakery',
         'patisserie', 'pastry', 'donut', 'cake', 'kue'],
        'Beli roti/kue',
      ),
      // Apotek, kecantikan & produk kebutuhan wanita
      (
        ['apotek', 'apotik', 'kimia farma', 'guardian', 'century',
         'k24', 'watsons', 'watson', 'klinik', 'rumah sakit', 'rs ',
         'puskesmas', 'dokter', 'optik', 'dental',
         // Produk kebutuhan wanita & perawatan diri
         'softies', 'pembalut', 'softex', 'charm', 'laurier',
         'masker wajah', 'skincare', 'serum', 'moisturizer', 'toner',
         'shampoo', 'conditioner', 'sabun mandi', 'body lotion',
         'lipstik', 'makeup', 'kosmetik', 'handbody'],
        'Beli obat / perawatan diri',
      ),
      // SPBU & BBM
      (
        ['pertamina', 'spbu', 'shell', 'bp ', 'total energies',
         'bensin', 'pertalite', 'pertamax', 'solar', 'bbm'],
        'Isi bahan bakar',
      ),
      // Transportasi
      (
        ['grab', 'gojek', 'go-jek', 'maxim', 'indriver', 'bluebird',
         'blue bird', 'taksi', 'taxi', 'ojek', 'parkir', 'tol',
         'kereta', 'commuter', 'busway', 'transjakarta', 'damri'],
        'Transportasi',
      ),
      // Hiburan
      (
        // Note: '21' removed — too ambiguous (matches years, addresses, etc.)
        // Use 'bioskop 21', 'cinema 21', or 'xxi' which are already here
        ['cinema', 'bioskop', 'cgv', 'cinepolis', 'xxi', 'cinema21',
         'karaoke', 'timezone', 'wahana', 'taman hiburan', 'tiket bioskop'],
        'Hiburan',
      ),
      // Elektronik & gadget
      (
        ['ibox', 'samsung store', 'erafone', 'iphone', 'laptop',
         'komputer', 'elektronik', 'electric', 'digital'],
        'Beli elektronik',
      ),
      // Pakaian & fashion
      (
        ['zara', 'h&m', 'uniqlo', 'matahari', 'ramayana',
         'sport station', 'nike', 'adidas', 'converse',
         'baju', 'pakaian', 'fashion', 'distro', 'butik'],
        'Beli pakaian / fashion',
      ),
      // Pendidikan
      (
        ['gramedia', 'toko buku', 'kinokuniya', 'buku', 'alat tulis',
         'stationery', 'kursus', 'les ', 'sekolah'],
        'Pendidikan / perlengkapan belajar',
      ),
    ];

    for (final (keywords, note) in rules) {
      if (keywords.any((kw) => haystack.contains(kw))) {
        debugPrint('[ReceiptScanner] Note inferred: "$note" (matched merchant/text)');
        return note;
      }
    }

    // Default fallback: use merchant name as note if available
    if (merchant != null && merchant.isNotEmpty) {
      debugPrint('[ReceiptScanner] Note fallback to merchant: "$merchant"');
      return 'Belanja di $merchant';
    }

    return null;
  }

  // ─── Cleanup ──────────────────────────────────────────────────────
  /// Dispose the text recognizer to free resources.
  void dispose() {
    _textRecognizer.close();
  }
}
