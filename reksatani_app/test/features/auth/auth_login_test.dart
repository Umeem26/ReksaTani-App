import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/auth/controllers/auth_controller.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

void main() {
  late FakeRemote remote;
  late Perangkat hp;
  late AuthController auth;

  void tanamAkun(String username, String passwordHash) {
    remote.tanam('users', {
      '_id': 'id-$username',
      'username': username,
      'password_hash': passwordHash,
      'role': 'pengepul',
      'sisa_uang_jalan': 0,
    });
  }

  setUp(() async {
    remote = FakeRemote();
    hp = Perangkat(remote, 'sesi-lama');
    await hp.pasang();
    await hp.hive.usersBox.delete('currentUser');
    auth = AuthController(remote: remote);
  });

  tearDown(() => hp.hancurkan());

  group('pesan gagal tidak membedakan username dan password', () {
    test('username tidak ada dan password salah menghasilkan pesan yang sama', () async {
      tanamAkun('budi', BCrypt.hashpw('rahasia', BCrypt.gensalt()));

      expect(await auth.login('tidak-ada', 'rahasia'), isFalse);
      final pesanUsername = auth.errorMessage.value;

      expect(await auth.login('budi', 'salah'), isFalse);
      final pesanPassword = auth.errorMessage.value;

      expect(pesanUsername, 'Username atau password salah');
      expect(pesanPassword, pesanUsername);
      expect(hp.hive.usersBox.get('currentUser'), isNull);
    });

    test('password plaintext yang salah memakai pesan yang sama', () async {
      tanamAkun('lama', 'kata-sandi-lama');

      expect(await auth.login('lama', 'salah'), isFalse);

      expect(auth.errorMessage.value, AuthController.pesanLoginGagal);
      expect(remote.panggilanTulis('users'), isEmpty);
    });

    test('jaringan putus tetap punya pesan sendiri', () async {
      remote.online = false;

      expect(await auth.login('budi', 'rahasia'), isFalse);

      expect(auth.errorMessage.value, isNot(AuthController.pesanLoginGagal));
      expect(auth.errorMessage.value, contains('Koneksi'));
    });
  });

  group('login berhasil', () {
    test('bcrypt: sesi tersimpan, tidak ada penulisan ke cloud', () async {
      final hash = BCrypt.hashpw('rahasia', BCrypt.gensalt());
      tanamAkun('budi', hash);

      expect(await auth.login('budi', 'rahasia'), isTrue);

      expect(auth.errorMessage.value, isNull);
      expect(auth.isLoading.value, isFalse);
      final sesi = hp.hive.usersBox.get('currentUser')!;
      expect(sesi.id, 'id-budi');
      expect(sesi.passwordHash, hash);
      expect(remote.panggilanTulis('users'), isEmpty);
    });

    test('fallback plaintext masih berlaku dan bermigrasi ke bcrypt', () async {
      tanamAkun('lama', 'kata-sandi-lama');

      expect(await auth.login('lama', 'kata-sandi-lama'), isTrue);

      final diCloud = remote.dokumen('users').single['password_hash'] as String;
      expect(diCloud, isNot('kata-sandi-lama'));
      expect(BCrypt.checkpw('kata-sandi-lama', diCloud), isTrue);
      expect(hp.hive.usersBox.get('currentUser')!.passwordHash, diCloud);
    });
  });
}
