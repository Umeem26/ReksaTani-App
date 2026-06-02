import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reksatani_app/services/master_data_service.dart';

void main() {
  dotenv.loadFromString(envString: 'MONGODB_URI=mongodb://localhost:27017');

  final service = MasterDataService();

  group('MasterDataService - Data Parser Unit Tests', () {
    test('TC-PAR-001: Positive - Parse valid ISO8601 string', () {
      const isoString = "2026-05-26T10:00:00.000Z";
      final result = service.parseDateTime(isoString);
      
      expect(result.year, 2026);
      expect(result.month, 5);
      expect(result.day, 26);
    });

    test('TC-PAR-002: Positive - Parse native DateTime object', () {
      final now = DateTime.now();
      final result = service.parseDateTime(now);
      
      expect(result, equals(now));
    });

    test('TC-PAR-003: Edge Case - Parse null value (should return DateTime.now)', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final result = service.parseDateTime(null);
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(result.isAfter(before), true);
      expect(result.isBefore(after), true);
    });

    test('TC-PAR-004: Negative - Parse invalid scrambled string', () {
      const invalid = "bukan-tanggal-123";
      final result = service.parseDateTime(invalid);
      
      expect(result, isA<DateTime>());
    });

    test('TC-PAR-005: Positive - Nullable parser with null', () {
      final result = service.parseDateTimeNullable(null);
      expect(result, isNull);
    });

    test('TC-PAR-006: Positive - Nullable parser with valid string', () {
      const isoString = "2026-12-31T23:59:59.000";
      final result = service.parseDateTimeNullable(isoString);
      
      expect(result?.year, 2026);
      expect(result?.month, 12);
      expect(result?.day, 31);
    });
  });
}
