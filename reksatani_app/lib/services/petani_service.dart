import 'package:uuid/uuid.dart';

import '../models/hive/petani_hive_model.dart';
import 'hive_service.dart';
import 'master_data_service.dart';
import 'saldo/transaksi_ditolak.dart';
import 'sync/mongo_id.dart';

/// Satu jalur untuk menambah, mengubah, dan menghapus petani dari layar mana pun.
///
/// Perubahan selalu masuk ke Hive dulu dengan status antrean, lalu dikirim oleh
/// siklus sinkronisasi. Jadi hasilnya sama saat online maupun offline.
class PetaniService {
  final _hive = HiveService();

  Future<PetaniHiveModel> tambah({
    required String nama,
    required String desa,
  }) async {
    final user = _hive.usersBox.get('currentUser')!;
    final baru = PetaniHiveModel(
      id: const Uuid().v4(),
      namaPetani: nama,
      desa: desa,
      pengepulId: user.id,
      sisaHutangKasbon: 0,
      waktuDibuat: DateTime.now(),
      statusSinkronisasi: 'pending',
    );
    await _hive.petaniBox.put(baru.id, baru);
    MasterDataService().syncAll();
    return baru;
  }

  /// Baris `pending` tetap `pending`, karena dokumennya mungkin belum ada di cloud.
  Future<void> ubah(
    PetaniHiveModel petani, {
    required String nama,
    required String desa,
  }) async {
    petani
      ..namaPetani = nama
      ..desa = desa;
    if (petani.statusSinkronisasi == 'synced') {
      petani.statusSinkronisasi = 'pending_update';
    }
    await petani.save();
    MasterDataService().syncAll();
  }

  /// Menandai [petani] `pending_delete`. Dokumennya baru dihapus sesudah
  /// rekonsiliasi, supaya kasbon yang masuk dari perangkat lain masih terlihat.
  ///
  /// Selalu lewat `pending_delete`, juga untuk baris `pending`: upsert-nya bisa
  /// saja sudah sampai ke server walau statusnya belum tersimpan.
  ///
  /// Melempar [TransaksiDitolak] bila petani masih punya kasbon atau sudah punya
  /// transaksi, dan dalam hal itu tidak ada yang berubah. Tanpa aturan kedua,
  /// menghapus transaksi yang pernah memotong kasbon sesudahnya tidak punya
  /// dokumen untuk mengembalikan hutangnya.
  ///
  /// Baris `pending_delete` tidak dihitung, karena transaksinya sudah dihapus.
  /// Hive tidak selalu lengkap, jadi mesin sinkron memeriksa lagi di cloud.
  Future<void> hapus(PetaniHiveModel petani) async {
    if (petani.sisaHutangKasbon > 0) {
      throw const TransaksiDitolak(
        'petani_berkasbon',
        'Petani ini masih punya kasbon. Lunasi dulu sebelum menghapusnya.',
      );
    }
    final punyaTransaksi = _hive.transaksiBox.values.any((t) =>
        t.statusSinkronisasi != 'pending_delete' &&
        MongoId.sama(t.petaniId, petani.id));
    if (punyaTransaksi) {
      throw const TransaksiDitolak(
        'petani_punya_transaksi',
        'Petani ini sudah punya transaksi, jadi tidak bisa dihapus.',
      );
    }
    petani.statusSinkronisasi = 'pending_delete';
    await petani.save();
    MasterDataService().syncAll();
  }
}
