import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pcd_scanner/services/confidence_validator.dart';

void main() {
  group('ConfidenceValidator - Logika Dasar', () {
    late ConfidenceValidator validator;

    setUp(() {
      validator = ConfidenceValidator(
        defaultThreshold: 0.75,
        maxRetry: 3,
      );
    });

    test('harus menerima confidence tinggi (>= threshold)', () {
      final result = validator.validate(confidence: 0.85, grade: 'A');

      expect(result.state, ConfidenceState.accepted);
      expect(result.confidence, 0.85);
      expect(result.grade, 'A');
      expect(result.retryCount, 0); // tidak ada retry
    });

    test('harus menerima confidence tepat di threshold', () {
      final result = validator.validate(confidence: 0.75, grade: 'B');

      expect(result.state, ConfidenceState.accepted);
      expect(result.confidence, 0.75);
      expect(result.grade, 'B');
    });

    test('harus menolak confidence rendah dan menyarankan retry', () {
      final result = validator.validate(confidence: 0.60, grade: 'A');

      expect(result.state, ConfidenceState.needsRetry);
      expect(result.confidence, 0.60);
      expect(result.retryCount, 1);
    });

    test('confidence sangat rendah (0.0) harus tetap needsRetry saat retry pertama', () {
      final result = validator.validate(confidence: 0.0, grade: 'C');

      expect(result.state, ConfidenceState.needsRetry);
      expect(result.retryCount, 1);
    });
  });

  group('ConfidenceValidator - Logika Retry Counter', () {
    late ConfidenceValidator validator;

    setUp(() {
      validator = ConfidenceValidator(
        defaultThreshold: 0.75,
        maxRetry: 3,
      );
    });

    test('retry counter harus naik setiap kali confidence rendah', () {
      validator.validate(confidence: 0.50, grade: 'A'); // retry 1
      expect(validator.retryCount, 1);

      validator.validate(confidence: 0.60, grade: 'A'); // retry 2
      expect(validator.retryCount, 2);
    });

    test('retry counter TIDAK naik jika confidence tinggi', () {
      validator.validate(confidence: 0.50, grade: 'A'); // retry 1
      expect(validator.retryCount, 1);

      validator.validate(confidence: 0.90, grade: 'A'); // accepted, counter tetap
      expect(validator.retryCount, 1);
    });

    test('harus force manualOverride setelah maxRetry tercapai', () {
      validator.validate(confidence: 0.50, grade: 'A'); // retry 1
      validator.validate(confidence: 0.60, grade: 'A'); // retry 2
      final result = validator.validate(confidence: 0.55, grade: 'A'); // retry 3 = max

      expect(result.state, ConfidenceState.manualOverride);
      expect(result.retryCount, 3);
      expect(result.retriesRemaining, 0);
    });

    test('setelah manualOverride, panggilan berikutnya tetap manualOverride', () {
      // Habiskan semua retry
      validator.validate(confidence: 0.50, grade: 'A');
      validator.validate(confidence: 0.50, grade: 'A');
      validator.validate(confidence: 0.50, grade: 'A'); // manualOverride

      // Panggilan ke-4 tetap manualOverride
      final result = validator.validate(confidence: 0.50, grade: 'A');
      expect(result.state, ConfidenceState.manualOverride);
      expect(result.retryCount, 4);
    });

    test('accepted masih bisa terjadi walaupun sudah ada retry sebelumnya', () {
      validator.validate(confidence: 0.50, grade: 'A'); // retry 1
      validator.validate(confidence: 0.60, grade: 'A'); // retry 2

      final result = validator.validate(confidence: 0.80, grade: 'A'); // accepted
      expect(result.state, ConfidenceState.accepted);
      expect(result.retryCount, 2); // counter tidak naik
    });
  });

  group('ConfidenceValidator - Reset', () {
    test('reset harus mengembalikan retryCount ke 0', () {
      final validator = ConfidenceValidator(maxRetry: 3);

      validator.validate(confidence: 0.50, grade: 'A');
      validator.validate(confidence: 0.50, grade: 'A');
      expect(validator.retryCount, 2);

      validator.reset();
      expect(validator.retryCount, 0);
    });

    test('setelah reset, validasi baru dimulai dari awal', () {
      final validator = ConfidenceValidator(maxRetry: 3);

      // Habiskan semua retry
      validator.validate(confidence: 0.50, grade: 'A');
      validator.validate(confidence: 0.50, grade: 'A');
      validator.validate(confidence: 0.50, grade: 'A');
      expect(validator.retryCount, 3);

      validator.reset();

      // Setelah reset, retry dimulai dari 1 lagi
      final result = validator.validate(confidence: 0.50, grade: 'A');
      expect(result.state, ConfidenceState.needsRetry);
      expect(result.retryCount, 1);
    });
  });

  group('ConfidenceValidator - Threshold Per Grade', () {
    late ConfidenceValidator validator;

    setUp(() {
      validator = ConfidenceValidator(
        defaultThreshold: 0.75,
        thresholdsPerGrade: {
          'A': 0.85,  // Grade A lebih ketat
          'B': 0.75,
          'C': 0.65,  // Grade C lebih longgar
        },
        maxRetry: 3,
      );
    });

    test('Grade A harus menggunakan threshold 0.85', () {
      expect(validator.getThresholdForGrade('A'), 0.85);

      final rejected = validator.validate(confidence: 0.80, grade: 'A');
      expect(rejected.state, ConfidenceState.needsRetry);
      expect(rejected.thresholdUsed, 0.85);
    });

    test('Grade C harus menggunakan threshold 0.65 yang lebih longgar', () {
      expect(validator.getThresholdForGrade('C'), 0.65);

      final accepted = validator.validate(confidence: 0.70, grade: 'C');
      expect(accepted.state, ConfidenceState.accepted);
      expect(accepted.thresholdUsed, 0.65);
    });

    test('Grade yang tidak terdaftar harus pakai defaultThreshold', () {
      expect(validator.getThresholdForGrade('D'), 0.75);

      final result = validator.validate(confidence: 0.76, grade: 'D');
      expect(result.state, ConfidenceState.accepted);
      expect(result.thresholdUsed, 0.75);
    });
  });

  group('ConfidenceResult - Properti Turunan', () {
    test('confidencePercent harus mengembalikan persentase 0-100', () {
      const result = ConfidenceResult(
        state: ConfidenceState.accepted,
        confidence: 0.873,
        grade: 'A',
        retryCount: 0,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      expect(result.confidencePercent, 87);
    });

    test('label harus mengembalikan format yang benar', () {
      const result = ConfidenceResult(
        state: ConfidenceState.needsRetry,
        confidence: 0.68,
        grade: 'B',
        retryCount: 1,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      expect(result.label, '68% yakin Grade B');
    });

    test('retriesRemaining harus menghitung sisa retry dengan benar', () {
      const result = ConfidenceResult(
        state: ConfidenceState.needsRetry,
        confidence: 0.50,
        grade: 'A',
        retryCount: 2,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      expect(result.retriesRemaining, 1);
    });

    test('retriesRemaining harus 0 saat manualOverride', () {
      const result = ConfidenceResult(
        state: ConfidenceState.manualOverride,
        confidence: 0.50,
        grade: 'A',
        retryCount: 3,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      expect(result.retriesRemaining, 0);
    });

    test('confidencePercent harus di-clamp ke 0-100', () {
      const tooLow = ConfidenceResult(
        state: ConfidenceState.needsRetry,
        confidence: -0.5,
        grade: 'C',
        retryCount: 0,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      expect(tooLow.confidencePercent, 0);

      const tooHigh = ConfidenceResult(
        state: ConfidenceState.accepted,
        confidence: 1.5,
        grade: 'A',
        retryCount: 0,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      expect(tooHigh.confidencePercent, 100);
    });
  });

  group('ConfidenceValidator - Edge Cases', () {
    test('maxRetry = 1 harus langsung manualOverride setelah pertama kali gagal', () {
      final validator = ConfidenceValidator(maxRetry: 1);
      final result = validator.validate(confidence: 0.50, grade: 'A');

      expect(result.state, ConfidenceState.manualOverride);
      expect(result.retryCount, 1);
    });

    test('confidence 1.0 (sempurna) harus selalu accepted', () {
      final validator = ConfidenceValidator();
      final result = validator.validate(confidence: 1.0, grade: 'A');

      expect(result.state, ConfidenceState.accepted);
    });

    test('toString harus menghasilkan representasi yang dapat dibaca', () {
      const result = ConfidenceResult(
        state: ConfidenceState.needsRetry,
        confidence: 0.68,
        grade: 'B',
        retryCount: 1,
        maxRetry: 3,
        thresholdUsed: 0.75,
      );
      final str = result.toString();
      expect(str, contains('ConfidenceResult'));
      expect(str, contains('needsRetry'));
      expect(str, contains('0.68'));
    });
  });
}
