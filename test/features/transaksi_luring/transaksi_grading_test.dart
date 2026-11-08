import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/features/pcd_scanner/services/grading_rubric.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/saldo/transaksi_ditolak.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

KomoditasHiveModel _komoditas(String nama) => KomoditasHiveModel(
      id: nama.toLowerCase(),
      namaKomoditas: nama,
      unitSatuan: 'kg',
      gradeKualitas: [
        {'grade': 'A', 'harga_maks': 7500.0},
        {'grade': 'B', 'harga_maks': 6000.0},
        {'grade': 'C', 'harga_maks': 4000.0},
      ],
      diperbaruiOleh: '',
      waktuPembaruan: DateTime(2026),
    );

Matcher _ditolak(String kode) =>
    throwsA(isA<TransaksiDitolak>().having((e) => e.kode, 'kode', kode));

const _gabahB = ['kotoran_hampa=3-10', 'butir=seragam'];
const _gabahA = ['kotoran_hampa=sd3', 'butir=seragam'];

void main() {
  group('komoditasDiubah', () {
    test('tanpa saran AI tidak pernah dianggap diubah', () {
      expect(TransaksiController.komoditasDiubah(null, 'Gabah'), isFalse);
      expect(TransaksiController.komoditasDiubah('', 'Gabah'), isFalse);
    });

    test('pilihan yang cocok dengan saran tidak dianggap diubah', () {
      expect(TransaksiController.komoditasDiubah('gabah', 'Gabah'), isFalse);
      expect(TransaksiController.komoditasDiubah('kelapa_sawit', 'Sawit'), isFalse);
      expect(TransaksiController.komoditasDiubah('kopi', 'Kopi Robusta'), isFalse);
    });

    test('pilihan berbeda atau kosong dianggap diubah', () {
      expect(TransaksiController.komoditasDiubah('kopi', 'Gabah'), isTrue);
      expect(TransaksiController.komoditasDiubah('gabah', ''), isTrue);
    });
  });

  group('simpan dan edit dengan catatan grading', () {
    final oidAgen = ObjectId();
    late FakeRemote remote;
    late Perangkat hp;
    final c = TransaksiController(ambilLokasi: () async => null);

    setUp(() async {
      remote = FakeRemote();
      tanamAgen(remote, oidAgen, 1000000);
      hp = Perangkat(remote, oidAgen.oid);
      await hp.pasang(uangJalan: 1000000);
      await hp.sinkron();
    });

    tearDown(() async {
      await tungguSync();
      await hp.hancurkan();
    });

    Future<void> simpan({
      String komoditas = 'Gabah',
      String? grade = 'B',
      CatatanGrading grading = const CatatanGrading(),
    }) =>
        c.simpanTransaksi(
          petaniTerpilih: null,
          namaPenjual: 'Pak',
          komoditasTerpilih: _komoditas(komoditas),
          gradeTerpilih: grade,
          beratText: '10',
          hargaText: '3000',
          fotoNotaPath: '',
          fotoBarangPath: '',
          izinkanTanpaFoto: true,
          grading: grading,
        );

    Future<void> edit(
      TransaksiHiveModel t, {
      String komoditas = 'Gabah',
      String? grade,
      String berat = '10',
      CatatanGrading? grading,
    }) =>
        c.updateTransaksi(
          t,
          petaniTerpilih: null,
          namaPenjual: 'Pak',
          komoditasTerpilih: _komoditas(komoditas),
          gradeTerpilih: grade ?? t.gradeTerpilih,
          beratText: berat,
          hargaText: '3000',
          fotoNotaPath: '',
          fotoBarangPath: '',
          grading: grading,
        );

    TransaksiHiveModel satu() => hp.hive.transaksiBox.values.single;

    test('saran AI dan jawaban checklist tersimpan, versi dicap controller', () async {
      await simpan(grading: const CatatanGrading(saranKomoditasAi: 'gabah', rubrikJawaban: _gabahB));

      final t = satu();
      expect(t.gradeTerpilih, 'B');
      expect(t.saranKomoditasAi, 'gabah');
      expect(t.komoditasDiubahPengguna, isFalse);
      expect(t.rubrikVersi, rubrikVersi);
      expect(t.rubrikJawaban, _gabahB);
    });

    test('saran berbeda dari pilihan: pilihan pengguna menang, keduanya tercatat', () async {
      await simpan(grading: const CatatanGrading(saranKomoditasAi: 'kopi', rubrikJawaban: _gabahB));

      final t = satu();
      expect(t.namaKomoditas, 'Gabah');
      expect(t.saranKomoditasAi, 'kopi');
      expect(t.komoditasDiubahPengguna, isTrue);
    });

    test('tanpa saran AI: saran null dan tidak diubah', () async {
      await simpan(grading: const CatatanGrading(rubrikJawaban: _gabahB));

      expect(satu().saranKomoditasAi, isNull);
      expect(satu().komoditasDiubahPengguna, isFalse);
    });

    test('grade tidak sama dengan hasil rubrik: ditolak, tidak ada yang tertulis', () async {
      await expectLater(
        simpan(grade: 'A', grading: const CatatanGrading(rubrikJawaban: _gabahB)),
        _ditolak('grade_tidak_cocok_rubrik'),
      );
      await expectLater(
        simpan(grading: const CatatanGrading(rubrikJawaban: ['kotoran_hampa=3-10'])),
        _ditolak('grade_tidak_cocok_rubrik'),
      );
      await expectLater(
        simpan(komoditas: 'Kopi Robusta', grading: const CatatanGrading(rubrikJawaban: _gabahB)),
        _ditolak('grade_tidak_cocok_rubrik'),
      );
      expect(hp.hive.transaksiBox.isEmpty, isTrue);
      expect(hp.user.sisaUangJalan, 1000000);
    });

    test('pemanggil lama tanpa catatan grading: field rubrik null', () async {
      await simpan();

      expect(satu().rubrikVersi, isNull);
      expect(satu().rubrikJawaban, isNull);
      expect(satu().komoditasDiubahPengguna, isFalse);
    });

    test('edit dengan checklist baru: grade dan jawaban diganti, saran asli tetap', () async {
      await simpan(grading: const CatatanGrading(saranKomoditasAi: 'gabah', rubrikJawaban: _gabahB));

      await edit(satu(), grade: 'A', grading: const CatatanGrading(rubrikJawaban: _gabahA));

      final t = satu();
      expect(t.gradeTerpilih, 'A');
      expect(t.rubrikJawaban, _gabahA);
      expect(t.saranKomoditasAi, 'gabah');
      expect(t.komoditasDiubahPengguna, isFalse);
    });

    test('edit ganti komoditas: tanda diubah dihitung ulang terhadap saran asli', () async {
      await simpan(grading: const CatatanGrading(saranKomoditasAi: 'gabah', rubrikJawaban: _gabahB));

      await edit(
        satu(),
        komoditas: 'Kopi Robusta',
        grade: 'A',
        grading: const CatatanGrading(rubrikJawaban: ['biji_cacat=sd10']),
      );

      expect(satu().komoditasDiubahPengguna, isTrue);
      expect(satu().rubrikJawaban, ['biji_cacat=sd10']);
    });

    test('edit berat saja: jawaban dan grade lama dipertahankan', () async {
      await simpan(grading: const CatatanGrading(rubrikJawaban: _gabahB));

      await edit(satu(), berat: '12');

      expect(satu().berat, 12);
      expect(satu().gradeTerpilih, 'B');
      expect(satu().rubrikVersi, rubrikVersi);
      expect(satu().rubrikJawaban, _gabahB);
    });

    test('grade berubah tanpa checklist baru: jawaban lama dibuang karena basi', () async {
      await simpan(grading: const CatatanGrading(rubrikJawaban: _gabahB));

      await edit(satu(), grade: 'C');

      expect(satu().gradeTerpilih, 'C');
      expect(satu().rubrikVersi, isNull);
      expect(satu().rubrikJawaban, isNull);
    });

    test('data lama tanpa rubrik bisa diedit beratnya tanpa checklist', () async {
      await simpan();

      await edit(satu(), berat: '11');

      expect(satu().berat, 11);
      expect(satu().gradeTerpilih, 'B');
      expect(satu().rubrikJawaban, isNull);
    });

    test('field grading sampai ke cloud lewat sync', () async {
      await simpan(grading: const CatatanGrading(saranKomoditasAi: 'kopi', rubrikJawaban: _gabahB));
      await hp.sinkron();

      final dok = remote.dokumen('transaksi').single;
      expect(dok['saran_komoditas_ai'], 'kopi');
      expect(dok['komoditas_diubah_pengguna'], isTrue);
      expect(dok['rubrik_versi'], rubrikVersi);
      expect(dok['rubrik_jawaban'], _gabahB);
      expect(satu().statusSinkronisasi, 'synced');
    });
  });
}
