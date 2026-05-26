import 'package:flutter/foundation.dart';

/// Status hasil validasi confidence dari ML model.
///
/// State machine sederhana:
///   confidence >= threshold  →  [accepted]
///   confidence < threshold && retryCount < maxRetry  →  [needsRetry]
///   confidence < threshold && retryCount >= maxRetry  →  [manualOverride]
enum ConfidenceState {
  /// Confidence memenuhi atau melebihi threshold. Hasil grading diterima otomatis.
  accepted,

  /// Confidence di bawah threshold, tetapi masih ada sisa percobaan retry.
  needsRetry,

  /// Batas retry habis. User dipaksa melakukan input manual.
  manualOverride,
}

/// Hasil validasi confidence yang dikembalikan oleh [ConfidenceValidator.validate].
///
/// Membungkus [state], [confidence], [grade], dan metadata retry
/// dalam satu objek immutable agar mudah dikonsumsi oleh UI.
class ConfidenceResult {
  final ConfidenceState state;
  final double confidence;
  final String grade;
  final int retryCount;
  final int maxRetry;
  final double thresholdUsed;

  const ConfidenceResult({
    required this.state,
    required this.confidence,
    required this.grade,
    required this.retryCount,
    required this.maxRetry,
    required this.thresholdUsed,
  });

  /// Persentase confidence (0–100) untuk ditampilkan di UI.
  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  /// Label teks ringkas yang ramah pengguna, contoh: "87% yakin Grade A".
  String get label => '$confidencePercent% yakin Grade $grade';

  /// Sisa percobaan retry yang tersisa.
  int get retriesRemaining => (maxRetry - retryCount).clamp(0, maxRetry);

  @override
  String toString() =>
      'ConfidenceResult(state: $state, confidence: $confidence, '
      'grade: $grade, retry: $retryCount/$maxRetry, threshold: $thresholdUsed)';
}

/// Service untuk memvalidasi confidence score dari hasil inferensi ML grading.
///
/// Mendukung:
/// - Threshold default yang dapat dikonfigurasi (default `0.75`).
/// - Threshold kustom per-grade (misal Grade A lebih ketat di `0.80`).
/// - Retry counter dengan batas maksimal (default `3`).
/// - Transisi state yang atomik dan deterministik.
///
/// Contoh penggunaan:
/// ```dart
/// final validator = ConfidenceValidator(
///   defaultThreshold: 0.75,
///   thresholdsPerGrade: {'A': 0.80, 'B': 0.75, 'C': 0.70},
///   maxRetry: 3,
/// );
///
/// final result = validator.validate(confidence: 0.68, grade: 'A');
/// // result.state == ConfidenceState.needsRetry
/// ```
class ConfidenceValidator {
  /// Threshold default jika grade-specific threshold tidak ditemukan.
  final double defaultThreshold;

  /// Threshold kustom per-grade. Key = nama grade (e.g. 'A', 'B', 'C').
  final Map<String, double> thresholdsPerGrade;

  /// Jumlah maksimal percobaan retry sebelum force manual override.
  final int maxRetry;

  /// Counter internal yang melacak berapa kali user sudah retry.
  int _retryCount = 0;

  /// Constructor untuk [ConfidenceValidator].
  ///
  /// [defaultThreshold] harus berada di rentang 0.0 – 1.0.
  /// [maxRetry] harus bernilai positif (>= 1).
  ConfidenceValidator({
    this.defaultThreshold = 0.75,
    this.thresholdsPerGrade = const {},
    this.maxRetry = 3,
  })  : assert(defaultThreshold >= 0.0 && defaultThreshold <= 1.0,
            'Threshold harus berada di rentang 0.0 – 1.0'),
        assert(maxRetry >= 1, 'maxRetry harus minimal 1');

  /// Jumlah retry yang sudah dilakukan saat ini.
  int get retryCount => _retryCount;

  /// Mendapatkan threshold yang berlaku untuk grade tertentu.
  /// Jika grade memiliki threshold kustom, gunakan itu; kalau tidak, pakai default.
  double getThresholdForGrade(String grade) {
    return thresholdsPerGrade[grade] ?? defaultThreshold;
  }

  /// Memvalidasi confidence score terhadap threshold yang berlaku.
  ///
  /// Mengembalikan [ConfidenceResult] yang berisi state, metadata,
  /// dan informasi retry untuk dikonsumsi oleh UI layer.
  ///
  /// **Penting**: Setiap panggilan `validate` dengan confidence rendah
  /// akan otomatis menaikkan retry counter (efek samping atomik).
  ConfidenceResult validate({
    required double confidence,
    required String grade,
  }) {
    final threshold = getThresholdForGrade(grade);

    // ─── CASE 1: Confidence memenuhi threshold → ACCEPTED ───
    if (confidence >= threshold) {
      debugPrint(
        '✅ [ConfidenceValidator] Grade $grade diterima '
        '(confidence: ${(confidence * 100).toStringAsFixed(1)}% >= '
        'threshold: ${(threshold * 100).toStringAsFixed(1)}%)',
      );
      return ConfidenceResult(
        state: ConfidenceState.accepted,
        confidence: confidence,
        grade: grade,
        retryCount: _retryCount,
        maxRetry: maxRetry,
        thresholdUsed: threshold,
      );
    }

    // ─── CASE 2: Confidence rendah, cek sisa retry ───
    _retryCount++;

    if (_retryCount >= maxRetry) {
      // Batas retry habis → MANUAL OVERRIDE
      debugPrint(
        '🚫 [ConfidenceValidator] Batas retry tercapai ($_retryCount/$maxRetry). '
        'Force manual override untuk Grade $grade '
        '(confidence: ${(confidence * 100).toStringAsFixed(1)}%)',
      );
      return ConfidenceResult(
        state: ConfidenceState.manualOverride,
        confidence: confidence,
        grade: grade,
        retryCount: _retryCount,
        maxRetry: maxRetry,
        thresholdUsed: threshold,
      );
    }

    // Masih ada sisa retry → NEEDS RETRY
    debugPrint(
      '🔄 [ConfidenceValidator] Confidence rendah untuk Grade $grade '
      '(${(confidence * 100).toStringAsFixed(1)}% < ${(threshold * 100).toStringAsFixed(1)}%). '
      'Retry $_retryCount/$maxRetry',
    );
    return ConfidenceResult(
      state: ConfidenceState.needsRetry,
      confidence: confidence,
      grade: grade,
      retryCount: _retryCount,
      maxRetry: maxRetry,
      thresholdUsed: threshold,
    );
  }

  /// Mereset retry counter kembali ke 0.
  /// Dipanggil ketika user memulai sesi grading baru atau berpindah komoditas.
  void reset() {
    _retryCount = 0;
    debugPrint('🔃 [ConfidenceValidator] Retry counter di-reset.');
  }
}
