/// Model data hasil scan struk menggunakan ML Kit OCR.
class ReceiptData {
  /// Nominal terbesar yang terdeteksi dari struk
  final double? amount;

  /// Tanggal yang terdeteksi dari struk
  final DateTime? date;

  /// Nama merchant/toko (biasanya baris pertama struk)
  final String? merchantName;

  /// Teks mentah hasil OCR (untuk debugging/review)
  final String rawText;

  /// Semua nominal yang terdeteksi (untuk review jika nominal utama salah)
  final List<String> allAmounts;

  const ReceiptData({
    this.amount,
    this.date,
    this.merchantName,
    required this.rawText,
    this.allAmounts = const [],
  });

  /// Apakah ada data yang berhasil di-extract
  bool get hasData => amount != null || date != null || merchantName != null;

  @override
  String toString() {
    return 'ReceiptData(amount: $amount, date: $date, merchant: $merchantName, '
        'allAmounts: $allAmounts, rawText: ${rawText.length} chars)';
  }
}
