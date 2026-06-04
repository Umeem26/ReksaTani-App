import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';

void main() {
  group('Bcrypt Integration Unit Tests', () {
    test('TC-BCR-001: Positive - Should hash and verify password successfully', () {
      const password = 'mySecurePassword123';
      final salt = BCrypt.gensalt();
      final hash = BCrypt.hashpw(password, salt);
      
      expect(hash, isNotNull);
      expect(hash.startsWith('\$2a\$') || hash.startsWith('\$2b\$') || hash.startsWith('\$2y\$'), true);
      
      final matches = BCrypt.checkpw(password, hash);
      expect(matches, true);
    });

    test('TC-BCR-002: Negative - Should fail verification for wrong password', () {
      const password = 'mySecurePassword123';
      const wrongPassword = 'wrongPassword';
      final salt = BCrypt.gensalt();
      final hash = BCrypt.hashpw(password, salt);
      
      final matches = BCrypt.checkpw(wrongPassword, hash);
      expect(matches, false);
    });

    test('TC-BCR-003: Edge Case - Plaintext validation and detection logic', () {
      const plainTextPassword = 'somePlaintext';
      final salt = BCrypt.gensalt();
      final hashed = BCrypt.hashpw(plainTextPassword, salt);
      
      bool isBcrypt(String stored) => stored.startsWith('\$2a\$') || stored.startsWith('\$2b\$') || stored.startsWith('\$2y\$');
      
      expect(isBcrypt(hashed), true);
      expect(isBcrypt(plainTextPassword), false);
    });
  });
}
