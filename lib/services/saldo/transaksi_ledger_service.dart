import '../../models/hive/petani_hive_model.dart';
import '../../models/hive/transaksi_hive_model.dart';
import '../hive_service.dart';
import '../sync/mongo_id.dart';
import 'kasbon_rules.dart';
import 'transaksi_ditolak.dart';

/// Satu jalur untuk menghapus transaksi dari layar mana pun.
class TransaksiLedgerService {
  final _hive = HiveService();

  /// Menandai [trx] `pending_delete` dan mengembalikan saldo lokal.
  ///
  /// Selalu lewat `pending_delete`, juga untuk baris `pending`: upsert-nya bisa
  /// saja sudah sampai ke server walau statusnya belum tersimpan, dan dokumen
  /// yang tertinggal akan muncul lagi lewat pull.
  ///
  /// Baris yang sudah `pending_delete` diabaikan, supaya saldo tidak dikembalikan
  /// dua kali. Melempar [TransaksiDitolak] bila menghapus pencairan yang sudah
  /// terpakai, dan dalam hal itu tidak ada yang berubah.
  Future<void> hapus(TransaksiHiveModel trx) async {
    if (trx.statusSinkronisasi == 'pending_delete') return;

    final pencairan = KasbonRules.isPencairan(trx.namaKomoditas);
    final deltaKasbon = KasbonRules.deltaKasbon(
      pencairan: pencairan,
      totalBayar: trx.totalBayar,
      potongan: trx.nominalPotongKasbon,
    );
    final deltaUangJalan = KasbonRules.deltaUangJalan(
      pencairan: pencairan,
      totalBayar: trx.totalBayar,
      potongan: trx.nominalPotongKasbon,
    );

    final petani = _petani(trx);
    if (pencairan && petani != null) {
      if (petani.sisaHutangKasbon - deltaKasbon < 0) {
        throw const TransaksiDitolak(
          'pencairan_terpakai',
          'Pencairan ini sudah terpakai. Hapus dulu transaksi yang memotong kasbon ini.',
        );
      }
    }

    // Transaksi ditulis dulu. Bila aplikasi mati sebelum saldo tersimpan, sync
    // berikutnya memperbaiki saldo, karena transaksi adalah sumber kebenaran.
    trx.statusSinkronisasi = 'pending_delete';
    await trx.save();

    if (petani != null && deltaKasbon != 0) {
      petani.sisaHutangKasbon -= deltaKasbon;
      await petani.save();
    }

    final user = _hive.usersBox.get('currentUser');
    if (user != null && MongoId.sama(trx.pengepulId, user.id)) {
      user.sisaUangJalan -= deltaUangJalan;
      await user.save();
    }
  }

  PetaniHiveModel? _petani(TransaksiHiveModel trx) => trx.petaniId.isEmpty
      ? null
      : _hive.petaniBox.get(MongoId.kanonik(trx.petaniId));
}
