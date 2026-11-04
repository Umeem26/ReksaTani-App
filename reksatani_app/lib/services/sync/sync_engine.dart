import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show mapEquals;

import '../../models/hive/transaksi_hive_model.dart';
import '../hive_service.dart';
import 'mongo_id.dart';
import 'sync_remote.dart';
import 'sync_report.dart';

typedef UnggahFoto = Future<String?> Function(String path);

/// Mesin sinkronisasi. Semua dependensi masuk lewat konstruktor supaya bisa
/// diuji tanpa jaringan.
class SyncEngine {
  SyncEngine({
    required this.remote,
    required HiveService hive,
    required UnggahFoto unggahFoto,
    DateTime Function()? jam,
  })  : _hive = hive,
        _unggahFoto = unggahFoto,
        _jam = jam ?? DateTime.now;

  final SyncRemote remote;
  final HiveService _hive;
  final UnggahFoto _unggahFoto;
  final DateTime Function() _jam;

  static const String _tahapPush = 'push_transaksi';

  /// Bentuk update untuk satu transaksi.
  ///
  /// `$set` berisi semua yang bisa berubah karena edit, `$setOnInsert` berisi
  /// yang tetap sejak dibuat. `$setOnInsert` saja tidak cukup: bila upsert sudah
  /// sampai tetapi statusnya belum tersimpan, edit berikutnya akan hilang tanpa
  /// jejak. Kedua set kunci harus saling lepas, atau server menolak dengan kode 40.
  static Map<String, dynamic> bangunUpdateTransaksi(
    TransaksiHiveModel t,
    DateTime sekarang,
  ) {
    return {
      r'$set': <String, dynamic>{
        'petani_id': MongoId.kanonik(t.petaniId),
        'nama_petani': t.namaPetani,
        'nama_komoditas': t.namaKomoditas,
        'grade_terpilih': t.gradeTerpilih,
        'berat': t.berat,
        'harga_beli_satuan': t.hargaBeliSatuan,
        'nominal_potong_kasbon': t.nominalPotongKasbon,
        'total_bayar': t.totalBayar,
        'foto_nota': _urlAtauKosong(t.fotoNota),
        'foto_fisik_barang': _urlAtauKosong(t.fotoFisikBarang),
        'status_sinkronisasi': 'synced',
        'waktu_disinkron': sekarang.toIso8601String(),
      },
      r'$setOnInsert': <String, dynamic>{
        'pengepul_id': MongoId.kanonik(t.pengepulId),
        'nama_pengepul': t.namaPengepul,
        'latitude': t.latitude,
        'longitude': t.longitude,
        'created_at': t.createdAt.toIso8601String(),
      },
    };
  }

  /// Mengirim baris `pending` dan `pending_update` lewat satu jalur.
  ///
  /// Kegagalan satu baris dicatat dan tidak menghentikan baris lain.
  Future<SyncReport> pushTransaksi() async {
    final masalah = <SyncIssue>[];
    var terkirim = 0;

    final antrean = [
      ..._hive.getPendingTransaksi(),
      ..._hive.getPendingUpdateTransaksi(),
    ];

    for (final t in antrean) {
      try {
        if (await _kirimTransaksi(t, masalah)) terkirim++;
      } catch (e) {
        _catat(masalah, t.idLokal, 'koneksi_gagal', e);
      }
    }

    return SyncReport(masalah: masalah, terkirim: terkirim, selesai: _jam());
  }

  Future<bool> _kirimTransaksi(
    TransaksiHiveModel t,
    List<SyncIssue> masalah,
  ) async {
    final statusAwal = t.statusSinkronisasi;
    await _unggahFotoBaris(t, masalah);

    final sekarang = _jam();
    final update = bangunUpdateTransaksi(t, sekarang);
    final hasil = await _tulisTransaksi(t, update);

    if (!hasil.kenaDokumen) {
      masalah.add(SyncIssue(
        tahap: _tahapPush,
        idLokal: t.idLokal,
        jenis: hasil.ok ? 'dokumen_hilang' : 'ditolak_server',
        pesan: 'Kode ${hasil.errorCode}, matched ${hasil.matched}',
      ));
      return false;
    }

    // Selama masih ada $inc saldo, ini satu-satunya penanda aman: hanya saat
    // dokumen benar-benar baru. Upsert ulang tidak boleh memotong saldo lagi.
    if (hasil.upserted == 1) {
      await _kurangiSaldoTransaksiBaru(t, masalah);
    }

    if (!t.isInBox) return true; // Baris dihapus selama pengiriman.

    // Agen bisa mengedit atau menghapus baris selama pengiriman berjalan.
    // Perubahan itu belum terkirim, jadi baris harus tetap di antrean.
    final diubahSaatKirim = t.statusSinkronisasi != statusAwal ||
        !_isiSama(update, bangunUpdateTransaksi(t, sekarang));
    if (diubahSaatKirim) return true;

    t.statusSinkronisasi = 'synced';
    t.waktuDisinkron = sekarang;
    await t.save();
    return true;
  }

  Future<RemoteWrite> _tulisTransaksi(
    TransaksiHiveModel t,
    Map<String, dynamic> update,
  ) async {
    // Baris hasil pull dari dokumen tanpa id_lokal: kuncinya adalah `_id`
    // dokumen. Upsert berbasis id_lokal akan membuat dokumen kedua.
    if (!MongoId.idLokalBuatanAplikasi(t.idLokal)) {
      return remote.updateOne(
        'transaksi',
        MongoId.filterId(t.idLokal),
        {r'$set': update[r'$set']},
      );
    }

    final filter = {'id_lokal': t.idLokal};
    final hasil =
        await remote.updateOne('transaksi', filter, update, upsert: true);
    if (!hasil.duplikat) return hasil;

    // Dua upsert berlomba dan pihak lain menang, jadi dokumennya sudah ada.
    return remote.updateOne('transaksi', filter, update);
  }

  Future<void> _kurangiSaldoTransaksiBaru(
    TransaksiHiveModel t,
    List<SyncIssue> masalah,
  ) async {
    if (t.nominalPotongKasbon > 0 && t.petaniId.isNotEmpty) {
      await _incSaldo(masalah, t, 'petani', t.petaniId, 'sisa_hutang_kasbon',
          -t.nominalPotongKasbon);
    }
    final uangTunaiKeluar = t.totalBayar - t.nominalPotongKasbon;
    if (uangTunaiKeluar > 0) {
      await _incSaldo(masalah, t, 'users', t.pengepulId, 'sisa_uang_jalan',
          -uangTunaiKeluar);
    }
  }

  Future<void> _incSaldo(
    List<SyncIssue> masalah,
    TransaksiHiveModel t,
    String koleksi,
    String id,
    String field,
    double delta,
  ) async {
    try {
      final hasil = await remote.updateOne(koleksi, MongoId.filterId(id), {
        r'$inc': {field: delta},
      });
      // Server menjawab sukses walau filter tidak mengenai dokumen apa pun.
      if (!hasil.kenaDokumen) {
        masalah.add(SyncIssue(
          tahap: _tahapPush,
          idLokal: t.idLokal,
          jenis: 'saldo_tidak_terbarui',
          pesan: '$koleksi/$id, kode ${hasil.errorCode}',
        ));
      }
    } catch (e) {
      _catat(masalah, t.idLokal, 'saldo_tidak_terbarui', e);
    }
  }

  Future<void> _unggahFotoBaris(
    TransaksiHiveModel t,
    List<SyncIssue> masalah,
  ) async {
    final nota = await _unggahSatuFoto(t.fotoNota, t, masalah);
    if (nota != null) {
      t.fotoNota = nota;
      await t.save();
    }
    final barang = await _unggahSatuFoto(t.fotoFisikBarang, t, masalah);
    if (barang != null) {
      t.fotoFisikBarang = barang;
      await t.save();
    }
  }

  Future<String?> _unggahSatuFoto(
    String path,
    TransaksiHiveModel t,
    List<SyncIssue> masalah,
  ) async {
    if (path.isEmpty || _adalahUrl(path)) return null;
    try {
      if (!await File(path).exists()) return null;
      final url = await _unggahFoto(path);
      if (url == null) {
        masalah.add(SyncIssue(
          tahap: _tahapPush,
          idLokal: t.idLokal,
          jenis: 'foto_gagal',
          pesan: 'Unggah foto tidak menghasilkan URL',
        ));
      }
      return url;
    } catch (e) {
      // Foto tidak boleh menahan data uang.
      _catat(masalah, t.idLokal, 'foto_gagal', e);
      return null;
    }
  }

  void _catat(
    List<SyncIssue> masalah,
    String idLokal,
    String jenis,
    Object galat,
  ) {
    // Pesan exception koneksi bisa berisi detail server, jadi tipenya saja.
    final pesan = galat.runtimeType.toString();
    masalah.add(SyncIssue(
      tahap: _tahapPush,
      idLokal: idLokal,
      jenis: jenis,
      pesan: pesan,
    ));
    developer.log('$jenis pada $idLokal: $pesan', name: 'SyncEngine');
  }

  static bool _adalahUrl(String nilai) => nilai.startsWith('http');

  /// Path lokal tidak berarti apa-apa di perangkat lain, jadi tidak boleh ke cloud.
  static String _urlAtauKosong(String nilai) => _adalahUrl(nilai) ? nilai : '';

  static bool _isiSama(Map<String, dynamic> a, Map<String, dynamic> b) =>
      mapEquals(a[r'$set'] as Map?, b[r'$set'] as Map?) &&
      mapEquals(a[r'$setOnInsert'] as Map?, b[r'$setOnInsert'] as Map?);
}
