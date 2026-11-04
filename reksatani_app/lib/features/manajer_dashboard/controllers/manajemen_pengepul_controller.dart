import 'package:uuid/uuid.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/sync/mongo_id.dart';
import '../../../../services/sync/mongo_remote.dart';
import '../../../../services/sync/sync_remote.dart';
import '../../../../models/hive/user_hive_model.dart';

enum HasilEditPengepul { berhasil, usernameDipakai, tidakDitemukan, gagal }

class ManajemenPengepulController {
  ManajemenPengepulController({SyncRemote? remote})
      : _remote = remote ?? MongoRemote();

  final SyncRemote _remote;
  final _hive = HiveService();

  static const String _dasar = 'saldo_dasar_uang_jalan';
  static const String _sisa = 'sisa_uang_jalan';

  /// Pesan untuk layar bila edit tidak berhasil.
  static String pesanGagalEdit(HasilEditPengepul hasil) => switch (hasil) {
        HasilEditPengepul.tidakDitemukan =>
          'Data agen tidak ditemukan. Muat ulang daftar lalu coba lagi.',
        HasilEditPengepul.usernameDipakai =>
          'Gagal menyimpan data. Username tersebut sudah digunakan. Silakan gunakan username lain.',
        _ => 'Gagal menyimpan data. Periksa koneksi lalu coba lagi.',
      };

  /// Selisih saldo dari isian form.
  ///
  /// Form menampilkan saldo tanpa desimal. Bila angkanya tidak diubah, saldo juga
  /// tidak boleh berubah, misalnya saat hanya mengganti username.
  static double selisihTopUp({
    required double sisaLama,
    required double sisaForm,
  }) =>
      sisaForm == sisaLama.truncateToDouble() ? 0 : sisaForm - sisaLama;

  Future<List<Map<String, dynamic>>> getSemuaPengepul() async {
    try {
      final docs = await _remote.find('users', {'role': 'pengepul'});

      for (final d in docs) {
        final id = MongoId.kanonik(d['_id']);
        final m = UserHiveModel(
          id: id,
          username: d['username'] ?? '',
          passwordHash: d['password_hash'] ?? '',
          role: d['role'] ?? 'pengepul',
          sisaUangJalan: (d[_sisa] ?? 0).toDouble(),
          waktuDibuat: DateTime.tryParse(d['waktu_dibuat']?.toString() ?? '') ?? DateTime.now(),
        );
        if (id != 'currentUser') {
          await _hive.usersBox.put(m.id, m);
        }
      }
      return docs;
    } catch (e) {
      print('Error getSemuaPengepul: ${e.runtimeType}');
      final lokal = _hive.usersBox.values.where((u) => u.role == 'pengepul').toList();
      return lokal.map((u) => {
        '_id': u.id,
        'username': u.username,
        'password_hash': u.passwordHash,
        'role': u.role,
        _sisa: u.sisaUangJalan,
        'waktu_dibuat': u.waktuDibuat.toIso8601String(),
      }).toList();
    }
  }

  Future<bool> tambahPengepul({
    required String username,
    required String password,
    required double sisaUangJalan,
  }) async {
    try {
      if (await _usernameDipakai(username.trim())) {
        return false;
      }

      final id = const Uuid().v4();
      final now = DateTime.now();
      final hashedPassword = BCrypt.hashpw(password.trim(), BCrypt.gensalt());
      final hasil = await _remote.updateOne(
        'users',
        {'_id': id},
        {
          r'$setOnInsert': {
            'username': username.trim(),
            'password_hash': hashedPassword,
            'role': 'pengepul',
            _dasar: sisaUangJalan,
            _sisa: sisaUangJalan,
            'waktu_dibuat': now.toIso8601String(),
          },
        },
        upsert: true,
      );
      if (!hasil.kenaDokumen) {
        return false;
      }

      final m = UserHiveModel(
        id: id,
        username: username.trim(),
        passwordHash: hashedPassword,
        role: 'pengepul',
        sisaUangJalan: sisaUangJalan,
        waktuDibuat: now,
      );
      await _hive.usersBox.put(id, m);

      return true;
    } catch (e) {
      print('Exception tambahPengepul: ${e.runtimeType}');
      return false;
    }
  }

  /// Saldo berubah sebagai selisih pada `saldo_dasar_uang_jalan` dan
  /// `sisa_uang_jalan` sekaligus, atomik dalam satu dokumen. Nilai absolut akan
  /// tertimpa oleh rekonsiliasi di HP agen, dan selisih tetap benar walau agen
  /// menyinkronkan transaksi di antara form dibuka dan disimpan.
  Future<HasilEditPengepul> editPengepul({
    required dynamic id,
    required String username,
    String? password,
    required double sisaUangJalan,
    required double sisaLama,
  }) async {
    try {
      if (await _usernameDipakai(username.trim(), selainId: id)) {
        return HasilEditPengepul.usernameDipakai;
      }

      final data = <String, dynamic>{'username': username.trim()};
      String? passwordHash;
      if (password != null && password.trim().isNotEmpty) {
        passwordHash = BCrypt.hashpw(password.trim(), BCrypt.gensalt());
        data['password_hash'] = passwordHash;
      }

      final selisih = selisihTopUp(sisaLama: sisaLama, sisaForm: sisaUangJalan);

      var hasil = await _remote.updateOne(
        'users',
        {
          ...MongoId.filterId(id),
          _dasar: {r'$exists': true},
        },
        {
          r'$set': data,
          r'$inc': {_dasar: selisih, _sisa: selisih},
        },
      );
      if (!hasil.ok) return HasilEditPengepul.gagal;

      var saldoLokal = (UserHiveModel m) => m.sisaUangJalan + selisih;

      if (hasil.matched == 0) {
        // Dokumen belum dimigrasi: rekonsiliasi belum menulis ke sini, jadi nilai
        // absolut aman. Filternya menjaga dokumen yang baru saja dimigrasi.
        hasil = await _remote.updateOne(
          'users',
          {
            ...MongoId.filterId(id),
            _dasar: {r'$exists': false},
          },
          {
            r'$set': {...data, _sisa: sisaUangJalan},
          },
        );
        if (!hasil.ok) return HasilEditPengepul.gagal;
        // Server menjawab sukses walau filter tidak mengenai dokumen apa pun.
        if (hasil.matched == 0) return HasilEditPengepul.tidakDitemukan;
        saldoLokal = (_) => sisaUangJalan;
      }

      final m = _hive.usersBox.get(MongoId.kanonik(id));
      if (m != null) {
        m.username = username.trim();
        if (passwordHash != null) {
          m.passwordHash = passwordHash;
        }
        m.sisaUangJalan = saldoLokal(m);
        await m.save();
      }

      return HasilEditPengepul.berhasil;
    } catch (e) {
      print('Error editPengepul: ${e.runtimeType}');
      return HasilEditPengepul.gagal;
    }
  }

  Future<bool> hapusPengepul(dynamic id) async {
    try {
      final hasil = await _remote.deleteOne('users', MongoId.filterId(id));
      if (!hasil.ok) return false;

      await _hive.usersBox.delete(MongoId.kanonik(id));

      return true;
    } catch (e) {
      print('Error hapusPengepul: ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> _usernameDipakai(String username, {dynamic selainId}) async {
    final docs = await _remote.find(
      'users',
      {
        'username': username,
        if (selainId != null) '_id': {r'$nin': MongoId.kandidat(selainId)},
      },
      fields: const ['username'],
    );
    return docs.isNotEmpty;
  }
}
