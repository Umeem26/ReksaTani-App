import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show mapEquals;

import '../../models/hive/komoditas_hive_model.dart';
import '../../models/hive/petani_hive_model.dart';
import '../../models/hive/transaksi_hive_model.dart';
import '../../models/hive/user_hive_model.dart';
import '../hive_service.dart';
import '../saldo/saldo_ledger.dart';
import 'mongo_id.dart';
import 'sync_remote.dart';
import 'sync_report.dart';

typedef UnggahFoto = Future<String?> Function(String path);

/// Yang perlu diingat dari rekonsiliasi untuk menghitung saldo lokal setelah pull.
class _KonteksSaldo {
  final List<Map<String, dynamic>> dokumen;
  final Set<String> cakupanPetani;

  _KonteksSaldo(this.dokumen, this.cakupanPetani);
}

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
  static const String _tahapHapus = 'push_hapus';
  static const String _tahapRekonsiliasi = 'rekonsiliasi';

  static const String _dasarKasbon = 'saldo_dasar_kasbon';
  static const String _sisaKasbon = 'sisa_hutang_kasbon';
  static const String _dasarUangJalan = 'saldo_dasar_uang_jalan';
  static const String _sisaUangJalan = 'sisa_uang_jalan';

  /// Selisih di bawah ini dianggap sama, supaya tidak menulis karena pembulatan.
  static const double _toleransi = 0.01;

  static const List<String> _fieldSaldoTransaksi = [
    'id_lokal',
    'petani_id',
    'pengepul_id',
    'nama_komoditas',
    'total_bayar',
    'nominal_potong_kasbon',
    'waktu_disinkron',
  ];

  // ── Siklus ──────────────────────────────────────────────────────

  /// Satu siklus penuh. Urutannya penting: push dan hapus dulu supaya
  /// rekonsiliasi melihat transaksi terbaru, dan pull terakhir supaya saldo
  /// lokal tidak tertimpa nilai lama.
  ///
  /// Kegagalan satu tahap dicatat dan tidak menghentikan tahap lain.
  Future<SyncReport> siklus() async {
    final masalah = <SyncIssue>[];

    final push = await pushTransaksi();
    masalah.addAll(push.masalah);
    final hapus = await pushHapusTransaksi();
    masalah.addAll(hapus.masalah);

    final konteks = await _rekonsiliasiSaldo(masalah);

    await _tarikKomoditas(masalah);
    await _tarikAgen(konteks, masalah);
    await _tarikPetani(konteks, masalah);
    final riwayatBaru = await _tarikRiwayat(masalah);

    return SyncReport(
      masalah: masalah,
      terkirim: push.terkirim,
      riwayatBaru: riwayatBaru,
      selesai: _jam(),
    );
  }

  // ── Push transaksi ──────────────────────────────────────────────

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
        _catat(masalah, _tahapPush, 'koneksi_gagal', e, idLokal: t.idLokal);
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

  // ── Push hapus ──────────────────────────────────────────────────

  /// Menghapus dokumen untuk baris `pending_delete`.
  ///
  /// Saldo cloud tidak disentuh di sini: rekonsiliasi di siklus yang sama akan
  /// mengembalikannya. Jadi `removed: 0` pada retry berarti sudah terhapus, dan
  /// tidak ada apa pun yang bisa kembali dua kali.
  Future<SyncReport> pushHapusTransaksi() async {
    final masalah = <SyncIssue>[];
    var terkirim = 0;

    for (final t in _hive.getPendingDeleteTransaksi()) {
      try {
        final hasil =
            await remote.deleteOne('transaksi', {'id_lokal': t.idLokal});
        if (!hasil.ok) {
          masalah.add(SyncIssue(
            tahap: _tahapHapus,
            idLokal: t.idLokal,
            jenis: 'ditolak_server',
            pesan: 'Kode ${hasil.errorCode}',
          ));
          continue;
        }
        await _hive.transaksiBox.delete(t.idLokal);
        terkirim++;
      } catch (e) {
        _catat(masalah, _tahapHapus, 'koneksi_gagal', e, idLokal: t.idLokal);
      }
    }

    return SyncReport(masalah: masalah, terkirim: terkirim, selesai: _jam());
  }

  // ── Rekonsiliasi saldo ──────────────────────────────────────────

  /// Menghitung saldo dari daftar transaksi cloud, lalu menulisnya dengan `$set`.
  ///
  /// Hanya untuk agen. Mengembalikan null bila bukan agen atau bila pembacaan
  /// gagal. Dalam kasus terakhir tidak ada yang ditulis, dan siklus berikutnya
  /// mengulang semuanya.
  Future<_KonteksSaldo?> _rekonsiliasiSaldo(List<SyncIssue> masalah) async {
    final user = _hive.usersBox.get('currentUser');
    if (user == null || user.role != 'pengepul') return null;

    final List<Map<String, dynamic>> dokumenTransaksi;
    final List<Map<String, dynamic>> dokumenPetani;
    final List<Map<String, dynamic>> dokumenAgen;
    final Set<String> cakupan;

    try {
      final filterAgen = MongoId.filterRef('pengepul_id', user.id);
      final trxAgen = await remote.find(
        'transaksi',
        filterAgen,
        fields: _fieldSaldoTransaksi,
      );

      final petaniMilik = await remote.find(
        'petani',
        filterAgen,
        fields: const [_dasarKasbon, _sisaKasbon],
      );

      final idMilik = petaniMilik.map((d) => MongoId.kanonik(d['_id'])).toSet();
      final idRujukan = <String>{
        ...trxAgen.map((d) => MongoId.kanonik(d['petani_id'])),
        ..._barisBelumTerkirim().map((t) => MongoId.kanonik(t.petaniId)),
      }..remove('');
      cakupan = {...idMilik, ...idRujukan};

      final idLuar = idRujukan.difference(idMilik);
      final petaniLuar = idLuar.isEmpty
          ? const <Map<String, dynamic>>[]
          : await remote.find(
              'petani',
              {'_id': {r'$in': _kandidatSemua(idLuar)}},
              fields: const [_dasarKasbon, _sisaKasbon],
            );
      dokumenPetani = [...petaniMilik, ...petaniLuar];

      // Kasbon petani bisa terpotong oleh agen lain, jadi transaksinya semua
      // agen ikut dihitung.
      final trxPetani = cakupan.isEmpty
          ? const <Map<String, dynamic>>[]
          : await remote.find(
              'transaksi',
              {'petani_id': {r'$in': _kandidatSemua(cakupan)}},
              fields: _fieldSaldoTransaksi,
            );
      dokumenTransaksi = [...trxAgen, ...trxPetani];

      dokumenAgen = await remote.find(
        'users',
        MongoId.filterId(user.id),
        fields: const [_dasarUangJalan, _sisaUangJalan],
      );
    } catch (e) {
      _catat(masalah, _tahapRekonsiliasi, 'koneksi_gagal', e);
      return null;
    }

    final ringkasan = SaldoLedger.hitung(dokumenTransaksi);

    final idDitemukan =
        dokumenPetani.map((d) => MongoId.kanonik(d['_id'])).toSet();
    for (final id in cakupan.difference(idDitemukan)) {
      masalah.add(SyncIssue(
        tahap: _tahapRekonsiliasi,
        jenis: 'saldo_tidak_terbarui',
        pesan: 'petani/$id tidak ditemukan',
      ));
    }

    for (final d in dokumenPetani) {
      final delta = ringkasan.deltaKasbon(d['_id']);
      final dasar = d[_dasarKasbon];
      if (dasar is num && SaldoLedger.saldo(dasar.toDouble(), delta) < 0) {
        masalah.add(SyncIssue(
          tahap: _tahapRekonsiliasi,
          jenis: 'kasbon_negatif',
          pesan: 'petani/${MongoId.kanonik(d['_id'])}',
        ));
      }
      await _tulisSaldo(
          'petani', d, _dasarKasbon, _sisaKasbon, delta, masalah);
    }

    if (dokumenAgen.isEmpty) {
      masalah.add(SyncIssue(
        tahap: _tahapRekonsiliasi,
        jenis: 'saldo_tidak_terbarui',
        pesan: 'users/${user.id} tidak ditemukan',
      ));
    }
    for (final d in dokumenAgen) {
      await _tulisSaldo('users', d, _dasarUangJalan, _sisaUangJalan,
          ringkasan.deltaUangJalan(d['_id']), masalah);
    }

    return _KonteksSaldo(dokumenTransaksi, cakupan);
  }

  /// Menulis `sisa = dasar + delta` bila berbeda.
  ///
  /// Filter ikut memuat nilai dasar yang tadi dibaca: top-up manajer yang masuk
  /// sesudah pembacaan membuat tulisan ini tidak mengenai dokumen, sehingga
  /// tidak menimpanya dengan nilai basi. Siklus berikutnya menghitung ulang.
  Future<void> _tulisSaldo(
    String koleksi,
    Map<String, dynamic> dokumen,
    String fieldDasar,
    String fieldSisa,
    double delta,
    List<SyncIssue> masalah,
  ) async {
    final id = MongoId.kanonik(dokumen['_id']);
    final dasar = dokumen[fieldDasar];
    if (dasar is! num) {
      // Tanpa saldo dasar, angka yang ditulis pasti salah.
      masalah.add(SyncIssue(
        tahap: _tahapRekonsiliasi,
        jenis: 'belum_dimigrasi',
        pesan: '$koleksi/$id belum punya $fieldDasar',
      ));
      return;
    }

    final target = SaldoLedger.saldo(dasar.toDouble(), delta);
    final sisa = dokumen[fieldSisa];
    if (sisa is num && (sisa - target).abs() <= _toleransi) return;

    try {
      final hasil = await remote.updateOne(
        koleksi,
        {'_id': dokumen['_id'], fieldDasar: dasar},
        {
          r'$set': {fieldSisa: target},
        },
      );
      if (!hasil.kenaDokumen) {
        masalah.add(SyncIssue(
          tahap: _tahapRekonsiliasi,
          jenis: 'saldo_tidak_terbarui',
          pesan: '$koleksi/$id, kode ${hasil.errorCode}',
        ));
      }
    } catch (e) {
      _catat(masalah, _tahapRekonsiliasi, 'saldo_tidak_terbarui', e);
    }
  }

  // ── Pull ────────────────────────────────────────────────────────

  Future<void> _tarikKomoditas(List<SyncIssue> masalah) async {
    try {
      final docs = await remote.find('komoditas', {});
      await _hive.komoditasBox.clear();
      for (final d in docs) {
        final grades = (d['grade_kualitas'] as List<dynamic>? ?? [])
            .map<Map<String, dynamic>>((g) => {
                  'grade': g['grade'] ?? '',
                  'harga_maks': _angka(g['harga_maks']),
                })
            .toList();

        final m = KomoditasHiveModel(
          id: MongoId.kanonik(d['_id']),
          namaKomoditas: d['nama_komoditas'] ?? '',
          unitSatuan: d['unit_satuan'] ?? 'kg',
          gradeKualitas: grades,
          diperbaruiOleh: d['diperbarui_oleh']?.toString() ?? '',
          waktuPembaruan: tanggal(d['waktu_pembaruan_harga']) ?? _jam(),
        );
        await _hive.komoditasBox.put(m.id, m);
      }
    } catch (e) {
      _catat(masalah, 'pull_komoditas', 'koneksi_gagal', e);
    }
  }

  Future<void> _tarikAgen(
    _KonteksSaldo? konteks,
    List<SyncIssue> masalah,
  ) async {
    try {
      final docs = await remote.find('users', {'role': 'pengepul'});

      final kunciLama =
          _hive.usersBox.keys.where((k) => k != 'currentUser').toList();
      await _hive.usersBox.deleteAll(kunciLama);

      for (final d in docs) {
        final m = UserHiveModel(
          id: MongoId.kanonik(d['_id']),
          username: d['username'] ?? '',
          passwordHash: '',
          role: d['role'] ?? 'pengepul',
          sisaUangJalan: _angka(d[_sisaUangJalan]),
          waktuDibuat: tanggal(d['waktu_dibuat']) ?? _jam(),
        );
        await _hive.usersBox.put(m.id, m);
      }

      await _perbaruiUangJalanSendiri(docs, konteks);
    } catch (e) {
      _catat(masalah, 'pull_agen', 'koneksi_gagal', e);
    }
  }

  /// Saldo di HP agen harus mengikuti cloud, termasuk tambahan dari manajer,
  /// dan tetap memperhitungkan transaksi yang belum terkirim.
  ///
  /// Tanpa konteks rekonsiliasi atau tanpa saldo dasar, nilai cloud tidak
  /// mencerminkan transaksi, jadi nilai lokal yang dipertahankan.
  Future<void> _perbaruiUangJalanSendiri(
    List<Map<String, dynamic>> docs,
    _KonteksSaldo? konteks,
  ) async {
    final user = _hive.usersBox.get('currentUser');
    if (user == null || konteks == null) return;

    for (final d in docs) {
      if (!MongoId.sama(d['_id'], user.id)) continue;
      final dasar = d[_dasarUangJalan];
      if (dasar is! num) return;

      final baru = SaldoLedger.saldo(
        dasar.toDouble(),
        SaldoLedger.efektif(konteks.dokumen, _barisBelumTerkirim())
            .deltaUangJalan(user.id),
      );
      if (baru != user.sisaUangJalan) {
        user.sisaUangJalan = baru;
        await user.save();
      }
      return;
    }
  }

  /// Menggabungkan petani cloud ke Hive tanpa `clear()`, karena `save()` pada
  /// objek yang sedang dipegang layar akan melempar setelah box dikosongkan.
  Future<void> _tarikPetani(
    _KonteksSaldo? konteks,
    List<SyncIssue> masalah,
  ) async {
    try {
      final docs = await remote.find('petani', {});
      final user = _hive.usersBox.get('currentUser');
      final pertahankanLokal = user?.role == 'pengepul' && konteks == null;

      // Dihitung dan diterapkan tanpa jeda `await`, supaya transaksi yang
      // disimpan selama penulisan tidak tertimpa.
      final efektif = konteks == null
          ? null
          : SaldoLedger.efektif(konteks.dokumen, _barisBelumTerkirim());
      final idCloud = <String>{};
      final diubah = <PetaniHiveModel>[];
      final baru = <PetaniHiveModel>[];

      for (final d in docs) {
        final id = MongoId.kanonik(d['_id']);
        idCloud.add(id);
        final lama = _hive.petaniBox.get(id);
        final kasbon = _kasbonLokal(d, id, lama, konteks, efektif, pertahankanLokal);

        if (lama == null) {
          baru.add(PetaniHiveModel(
            id: id,
            namaPetani: d['nama_petani'] ?? '',
            desa: d['desa'] ?? '',
            pengepulId: MongoId.kanonik(d['pengepul_id']),
            sisaHutangKasbon: kasbon,
            waktuDibuat: _waktuDibuat(d) ?? _jam(),
          ));
          continue;
        }

        lama
          ..namaPetani = d['nama_petani'] ?? ''
          ..desa = d['desa'] ?? ''
          ..pengepulId = MongoId.kanonik(d['pengepul_id'])
          ..sisaHutangKasbon = kasbon
          ..waktuDibuat = _waktuDibuat(d) ?? lama.waktuDibuat;
        diubah.add(lama);
      }

      for (final m in diubah) {
        await m.save();
      }
      await _hive.petaniBox.putAll({for (final m in baru) m.id: m});

      final kunciHilang = _hive.petaniBox.keys
          .where((k) => !idCloud.contains(k))
          .toList();
      await _hive.petaniBox.deleteAll(kunciHilang);
    } catch (e) {
      _catat(masalah, 'pull_petani', 'koneksi_gagal', e);
    }
  }

  double _kasbonLokal(
    Map<String, dynamic> d,
    String id,
    PetaniHiveModel? lama,
    _KonteksSaldo? konteks,
    RingkasanSaldo? efektif,
    bool pertahankanLokal,
  ) {
    final dasar = d[_dasarKasbon];
    if (konteks != null && konteks.cakupanPetani.contains(id)) {
      if (dasar is num) {
        return SaldoLedger.saldo(dasar.toDouble(), efektif!.deltaKasbon(id));
      }
      // Tanpa saldo dasar, nilai cloud tidak mencerminkan transaksi.
      if (lama != null) return lama.sisaHutangKasbon;
    }
    if (pertahankanLokal && lama != null) return lama.sisaHutangKasbon;
    return _angka(d[_sisaKasbon]);
  }

  Future<int> _tarikRiwayat(List<SyncIssue> masalah) async {
    var jumlahBaru = 0;
    try {
      final user = _hive.usersBox.get('currentUser');
      if (user == null) return 0;

      final Map<String, dynamic> filter = _peranManajer(user.role)
          ? {
              'pengepul_id': {r'$ne': ''},
            }
          : MongoId.filterRef('pengepul_id', user.id);

      final docs = await remote.find('transaksi', filter);

      for (final d in docs) {
        final kunci = SaldoLedger.kunciDokumen(d);
        if (_hive.transaksiBox.containsKey(kunci)) continue;

        final m = TransaksiHiveModel(
          idLokal: kunci,
          pengepulId: MongoId.kanonik(d['pengepul_id']),
          petaniId: MongoId.kanonik(d['petani_id']),
          namaPengepul: d['nama_pengepul']?.toString() ?? '',
          namaPetani: d['nama_petani']?.toString() ?? '',
          namaKomoditas: d['nama_komoditas']?.toString() ?? '',
          gradeTerpilih: d['grade_terpilih']?.toString() ?? '',
          berat: _angka(d['berat']),
          hargaBeliSatuan: _angka(d['harga_beli_satuan']),
          nominalPotongKasbon: _angka(d['nominal_potong_kasbon']),
          totalBayar: _angka(d['total_bayar']),
          fotoFisikBarang: d['foto_fisik_barang']?.toString() ?? '',
          fotoNota: d['foto_nota']?.toString() ?? '',
          latitude: _angka(d['latitude']),
          longitude: _angka(d['longitude']),
          statusSinkronisasi: d['status_sinkronisasi']?.toString() ?? 'synced',
          createdAt: tanggal(d['created_at']) ?? _jam(),
          waktuDisinkron: tanggal(d['waktu_disinkron']),
        );
        await _hive.transaksiBox.put(m.idLokal, m);
        jumlahBaru++;
      }
    } catch (e) {
      _catat(masalah, 'pull_riwayat', 'koneksi_gagal', e);
    }
    return jumlahBaru;
  }

  // ── Foto ────────────────────────────────────────────────────────

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
      _catat(masalah, _tahapPush, 'foto_gagal', e, idLokal: t.idLokal);
      return null;
    }
  }

  // ── Bantuan ─────────────────────────────────────────────────────

  /// Mengurai tanggal dari cloud. Null bila kosong atau tidak bisa dibaca.
  static DateTime? tanggal(Object? val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString());
  }

  /// Field ini tertulis dengan dua nama di data yang ada.
  static DateTime? _waktuDibuat(Map<String, dynamic> d) =>
      tanggal(d['waktu_dibuat']) ?? tanggal(d['created_at']);

  static double _angka(Object? v) => v is num ? v.toDouble() : 0.0;

  static bool _peranManajer(String peran) =>
      peran == 'manager' || peran == 'manajer' || peran == 'admin';

  static List<Object> _kandidatSemua(Iterable<String> ids) =>
      [for (final id in ids) ...MongoId.kandidat(id)];

  Iterable<TransaksiHiveModel> _barisBelumTerkirim() =>
      _hive.transaksiBox.values.where((t) => t.statusSinkronisasi != 'synced');

  void _catat(
    List<SyncIssue> masalah,
    String tahap,
    String jenis,
    Object galat, {
    String? idLokal,
  }) {
    // Pesan exception koneksi bisa berisi detail server, jadi tipenya saja.
    final pesan = galat.runtimeType.toString();
    masalah.add(SyncIssue(
      tahap: tahap,
      idLokal: idLokal,
      jenis: jenis,
      pesan: pesan,
    ));
    developer.log('$tahap/$jenis pada ${idLokal ?? '-'}: $pesan',
        name: 'SyncEngine');
  }

  static bool _adalahUrl(String nilai) => nilai.startsWith('http');

  /// Path lokal tidak berarti apa-apa di perangkat lain, jadi tidak boleh ke cloud.
  static String _urlAtauKosong(String nilai) => _adalahUrl(nilai) ? nilai : '';

  static bool _isiSama(Map<String, dynamic> a, Map<String, dynamic> b) =>
      mapEquals(a[r'$set'] as Map?, b[r'$set'] as Map?) &&
      mapEquals(a[r'$setOnInsert'] as Map?, b[r'$setOnInsert'] as Map?);
}
