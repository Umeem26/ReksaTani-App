import 'dart:async';
import 'dart:io';

import 'package:reksatani_app/services/mongodb_service.dart';

/// Pesan penanda: bila muncul di log, ada tes yang lupa menyuntik `FakeRemote`.
const String penandaSambungDiblokir = '[tes] Upaya sambung ke jaringan diblokir';

/// Dijalankan `flutter test` sebelum setiap file tes.
///
/// `MasterDataService` memakai `MongoRemote` asli bila engine tidak disuntik, dan
/// kredensial di `env.g.dart` adalah kredensial sungguhan. Tanpa penjaga ini, satu
/// tes yang lupa menyuntik akan menulis ke Atlas dan mengunggah ke Cloudinary.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MongoDatabase.pembuka = () async {
    stderr.writeln(penandaSambungDiblokir);
    throw StateError(penandaSambungDiblokir);
  };
  HttpOverrides.global = _HttpDiblokir();
  await testMain();
}

class _HttpDiblokir extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    stderr.writeln(penandaSambungDiblokir);
    throw StateError(penandaSambungDiblokir);
  }
}
