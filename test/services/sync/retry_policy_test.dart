import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/services/sync/retry_policy.dart';

void main() {
  const p = RetryPolicy();

  test('tanpa jitter mengikuti jadwal', () {
    final jadwal = [for (var i = 1; i <= 6; i++) p.tunda(i, acak: 0.5)];

    expect(jadwal, const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 4),
      Duration(minutes: 8),
      Duration(minutes: 15),
    ]);
  });

  test('percobaan ke-7 dan seterusnya berhenti', () {
    expect(RetryPolicy.batas, 7);
    expect(p.tunda(7), isNull);
    expect(p.tunda(100), isNull);
  });

  test('di luar rentang bawah tidak menjadwalkan', () {
    expect(p.tunda(0), isNull);
    expect(p.tunda(-1), isNull);
  });

  test('jitter tepat ±20%', () {
    expect(p.tunda(1, acak: 0), const Duration(seconds: 24));
    expect(p.tunda(1, acak: 1), const Duration(seconds: 36));
    expect(p.tunda(6, acak: 0), const Duration(minutes: 12));
    expect(p.tunda(6, acak: 1), const Duration(minutes: 18));
  });
}
