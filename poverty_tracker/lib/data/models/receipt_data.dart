/// Model data hasil scan struk menggunakan ML Kit OCR.
class ReceiptData {
  /// Nominal terbesar yang terdeteksi dari struk
  final double? amount;

  /// Tanggal yang terdeteksi dari struk
  final DateTime? date;

  /// Nama merchant/toko (biasanya baris pertama struk)
  final String? merchantName;

  /// Catatan otomatis berdasarkan kategori merchant
  /// e.g. "Belanja kebutuhan sehari-hari" untuk Alfamart
  final String? note;

  /// Teks mentah hasil OCR (untuk debugging/review)
  final String rawText;

  /// Semua nominal yang terdeteksi (untuk review jika nominal utama salah)
  final List<String> allAmounts;

  const ReceiptData({
    this.amount,
    this.date,
    this.merchantName,
    this.note,
    required this.rawText,
    this.allAmounts = const [],
  });

  /// Apakah ada data yang berhasil di-extract
  bool get hasData => amount != null || date != null || merchantName != null;

  @override
  String toString() {
    return 'ReceiptData(amount: $amount, date: $date, merchant: $merchantName, '
        'note: $note, allAmounts: $allAmounts, rawText: ${rawText.length} chars)';
  }
}
