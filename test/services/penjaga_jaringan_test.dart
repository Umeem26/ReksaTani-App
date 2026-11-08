import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/services/mongodb_service.dart';

/// Memastikan `flutter_test_config.dart` benar-benar aktif, karena tanpanya tes
/// yang lupa menyuntik engine akan menulis ke Atlas sungguhan.
void main() {
  test('ping tanpa pembuka suntikan tidak bisa menyambung', () async {
    expect(await MongoDatabase.ping(), isFalse);
  });

  test('HTTP diblokir', () {
    expect(HttpClient.new, throwsStateError);
  });
}
