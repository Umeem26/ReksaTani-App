import 'dart:io';

import 'package:hive/hive.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';

import 'fake_remote.dart';

/// Batasnya sengaja jauh di atas nominal tes saldo, yang memakai berat 1 sehingga
/// harga sama dengan total. Tes aturan harga memakai komoditasnya sendiri.
final komoditasGabah = KomoditasHiveModel(
  id: 'gabah',
  namaKomoditas: 'Gabah',
  unitSatuan: 'kg',
  gradeKualitas: const [
    {'grade': 'A', 'harga_maks': 100000000.0},
  ],
  diperbaruiOleh: '',
  waktuPembaruan: DateTime(2026),
);

/// Controller memicu `syncAll` tanpa menunggunya, jadi tes harus menunggu di sini.
Future<void> tungguSync() async {
  while (MasterDataService().isSyncing) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// Satu HP: Hive sendiri, memakai awan yang sama.
///
/// `HiveService` adalah singleton, jadi hanya satu perangkat yang bisa aktif pada
/// satu waktu. Berpindah perangkat berarti menutup Hive lalu membuka folder lain.
class Perangkat {
  Perangkat(this.remote, this.idAgen);

  final FakeRemote remote;
  final String idAgen;
  late final Directory _folder;

  final hive = HiveService();
  final jamSync = DateTime(2026, 2, 1, 9);

  Future<void> pasang({double uangJalan = 0, String role = 'pengepul'}) async {
    _folder = await Directory.systemTemp.createTemp('perangkat');
    await aktifkan();
    await hive.usersBox.put(
      'currentUser',
      UserHiveModel(
        id: idAgen,
        username: idAgen,
        passwordHash: '',
        role: role,
        sisaUangJalan: uangJalan,
        waktuDibuat: DateTime(2026),
      ),
    );
  }

  /// Menjadikan perangkat ini yang aktif.
  Future<void> aktifkan() async {
    await Hive.close();
    await hive.init(testPath: _folder.path);
    MasterDataService().engine = SyncEngine(
      remote: remote,
      hive: hive,
      unggahFoto: (_) async => null,
      jam: () => jamSync,
    );
    MasterDataService().isSyncing = false;
  }

  Future<void> hancurkan() async {
    await Hive.close();
    await _folder.delete(recursive: true);
  }

  Future<void> sinkron() async {
    await tungguSync();
    await MasterDataService().syncAll();
  }

  UserHiveModel get user => hive.usersBox.get('currentUser')!;
  PetaniHiveModel petani(String id) => hive.petaniBox.get(id)!;
}

void tanamAgen(FakeRemote remote, Object id, double saldo) {
  remote.tanam('users', {
    '_id': id,
    'username': 'agen_$id',
    'role': 'pengepul',
    'saldo_dasar_uang_jalan': saldo,
    'sisa_uang_jalan': saldo,
  });
}

void tanamPetani(FakeRemote remote, Object id, Object agen, double kasbon) {
  remote.tanam('petani', {
    '_id': id,
    'nama_petani': 'Petani $id',
    'desa': 'Desa',
    'pengepul_id': agen,
    'saldo_dasar_kasbon': kasbon,
    'sisa_hutang_kasbon': kasbon,
  });
}
