import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reksatani_app/features/pengepul_dashboard/controllers/profil_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/foto/foto_tertunda.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';
import 'package:reksatani_app/services/sync/sync_report.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _agen = 'agen-1';
const _idLokal = '${_agen}_1730000000000';

TransaksiHiveModel _trx({
  String idLokal = _idLokal,
  String status = 'pending',
  String nota = '',
  String barang = '',
  String statusFoto = 'pending',
}) =>
    TransaksiHiveModel(
      idLokal: idLokal,
      pengepulId: _agen,
      petaniId: '',
      namaPengepul: 'Agen',
      namaPetani: 'Pak Tani',
      namaKomoditas: 'Gabah',
      gradeTerpilih: 'A',
      berat: 10,
      hargaBeliSatuan: 5000,
      nominalPotongKasbon: 0,
      totalBayar: 50000,
      fotoFisikBarang: barang,
      fotoNota: nota,
      statusFoto: statusFoto,
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: status,
      createdAt: DateTime(2026, 1, 1, 8),
    );

void main() {
  final hive = HiveService();
  late Directory dir;
  late FakeRemote remote;
  late SyncEngine engine;
  late Map<String, String?> hasilFoto;
  late List<String> diunggah;
  Future<String?> Function(String path)? unggahKhusus;

  SyncEngine buatEngine({Duration batas = const Duration(seconds: 60)}) => SyncEngine(
        remote: remote,
        hive: hive,
        unggahFoto: (path) async {
          diunggah.add(path);
          final khusus = unggahKhusus;
          if (khusus != null) return khusus(path);
          return hasilFoto[path];
        },
        jam: () => DateTime(2026, 2, 1, 9),
        batasUnggahFoto: batas,
      );

  String buatFile(String nama) {
    final f = File('${dir.path}/$nama')..writeAsStringSync('isi');
    return f.path;
  }

  Map<String, dynamic> dok() => remote.dokumen('transaksi').single;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_engine_foto');
    await hive.init(testPath: dir.path);
    remote = FakeRemote();
    hasilFoto = {};
    diunggah = [];
    unggahKhusus = null;
    engine = buatEngine();
    // Controller memicu `syncAll`. Tanpa ini ia memakai MongoRemote asli.
    MasterDataService()
      ..engine = engine
      ..isSyncing = false;
    await hive.usersBox.put(
      'currentUser',
      UserHiveModel(
        id: _agen,
        username: 'agen',
        passwordHash: '',
        role: 'manajer',
        sisaUangJalan: 0,
        waktuDibuat: DateTime(2026),
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('T10: foto gagal tidak menahan data uang', () {
    test('foto gagal: data synced, status_foto pending, tanpa path lokal', () async {
      final nota = buatFile('nota.jpg');
      final t = _trx(nota: nota);
      await hive.transaksiBox.put(_idLokal, t);

      final laporan = await engine.siklus();

      expect(laporan.terkirim, 1);
      expect(t.statusSinkronisasi, 'synced');
      expect(t.statusFoto, 'pending');
      expect(t.fotoNota, nota);
      expect(dok()['status_foto'], 'pending');
      expect(dok()['foto_nota'], '');
      expect(laporan.masalah.map((m) => m.jenis), ['foto_gagal']);
    });

    test('retry berhasil: URL terisi di Hive dan cloud, status ok', () async {
      final nota = buatFile('nota.jpg');
      final barang = buatFile('barang.jpg');
      final t = _trx(nota: nota, barang: barang);
      await hive.transaksiBox.put(_idLokal, t);
      await engine.siklus();

      hasilFoto[nota] = 'https://cdn/nota.jpg';
      hasilFoto[barang] = 'https://cdn/barang.jpg';
      final laporan = await buatEngine().siklus();

      expect(laporan.sukses, isTrue);
      expect(t.statusFoto, 'ok');
      expect(t.fotoNota, 'https://cdn/nota.jpg');
      expect(t.fotoFisikBarang, 'https://cdn/barang.jpg');
      expect(dok()['foto_nota'], 'https://cdn/nota.jpg');
      expect(dok()['foto_fisik_barang'], 'https://cdn/barang.jpg');
      expect(dok()['status_foto'], 'ok');
    });

    test('satu foto berhasil: URL-nya terkirim, yang lain tetap dicoba lagi', () async {
      final nota = buatFile('nota.jpg');
      final barang = buatFile('barang.jpg');
      hasilFoto[nota] = 'https://cdn/nota.jpg';
      final t = _trx(nota: nota, barang: barang);
      await hive.transaksiBox.put(_idLokal, t);

      await engine.siklus();

      expect(t.statusFoto, 'pending');
      expect(dok()['foto_nota'], 'https://cdn/nota.jpg');
      expect(dok()['status_foto'], 'pending');

      diunggah.clear();
      await buatEngine().siklus();
      expect(diunggah, [barang]);
    });

    test('path lokal tidak pernah terkirim di tulisan mana pun', () async {
      final nota = buatFile('nota.jpg');
      await hive.transaksiBox.put(_idLokal, _trx(nota: nota, barang: buatFile('b.jpg')));

      await engine.siklus();
      await buatEngine().siklus();

      for (final p in remote.panggilanTulis('transaksi')) {
        expect(p.update.toString(), isNot(contains(dir.path)));
      }
    });

    test('unggahan menggantung: dihentikan oleh batas, siklus tetap selesai', () async {
      final t = _trx(nota: buatFile('nota.jpg'));
      await hive.transaksiBox.put(_idLokal, t);
      unggahKhusus = (_) => Completer<String?>().future;

      final laporan = await buatEngine(batas: const Duration(milliseconds: 10)).siklus();

      expect(t.statusSinkronisasi, 'synced');
      expect(t.statusFoto, 'pending');
      expect(laporan.masalah.map((m) => m.jenis), ['foto_gagal']);
    });

    test('unggahan melempar: tidak menahan baris lain', () async {
      final kedua = '${_agen}_1730000000001';
      final notaA = buatFile('a.jpg');
      final notaB = buatFile('b.jpg');
      await hive.transaksiBox.put(_idLokal, _trx(nota: notaA));
      await hive.transaksiBox.put(kedua, _trx(idLokal: kedua, nota: notaB));
      unggahKhusus = (path) async {
        if (path == notaA) throw const SocketException('putus');
        return 'https://cdn/b.jpg';
      };

      await engine.siklus();

      expect(hive.transaksiBox.get(_idLokal)!.statusFoto, 'pending');
      expect(hive.transaksiBox.get(kedua)!.fotoNota, 'https://cdn/b.jpg');
      expect(hive.transaksiBox.get(kedua)!.statusFoto, 'dilewati');
    });

    test('rekonsiliasi dan pull selesai sebelum foto diunggah', () async {
      final t = _trx(nota: buatFile('nota.jpg'));
      await hive.transaksiBox.put(_idLokal, t);
      remote.tanam('komoditas', {'_id': 'k', 'nama_komoditas': 'Gabah'});
      unggahKhusus = (_) async {
        expect(hive.komoditasBox.containsKey('k'), isTrue);
        return 'https://cdn/x.jpg';
      };

      await engine.siklus();

      expect(diunggah, hasLength(1));
    });
  });

  group('Status akhir', () {
    test('file hilang: status hilang, tidak dicoba lagi', () async {
      final t = _trx(nota: '${dir.path}/tidak-ada.jpg', barang: 'https://cdn/b.jpg');
      await hive.transaksiBox.put(_idLokal, t);

      final laporan = await engine.siklus();

      expect(laporan.sukses, isTrue);
      expect(t.statusFoto, 'hilang');
      expect(dok()['status_foto'], 'hilang');
      expect(dok()['foto_nota'], '');

      diunggah.clear();
      await buatEngine().siklus();
      expect(diunggah, isEmpty);
    });

    test('satu foto kosong: sesudah terunggah berstatus dilewati', () async {
      final nota = buatFile('nota.jpg');
      hasilFoto[nota] = 'https://cdn/nota.jpg';
      final t = _trx(nota: nota);
      await hive.transaksiBox.put(_idLokal, t);

      await engine.siklus();

      expect(t.statusFoto, 'dilewati');
      expect(dok()['status_foto'], 'dilewati');
      expect(dok()['foto_nota'], 'https://cdn/nota.jpg');
    });

    test('baris tanpa tugas foto tidak disentuh', () async {
      await hive.transaksiBox.put(
        _idLokal,
        _trx(status: 'synced', statusFoto: 'dilewati'),
      );
      remote.tanam('transaksi', {
        'id_lokal': _idLokal,
        'pengepul_id': _agen,
        'status_foto': 'dilewati',
      });

      await engine.siklus();

      expect(remote.panggilanTulis('transaksi'), isEmpty);
    });
  });

  group('Crash dan balapan', () {
    test('mati sebelum updateOne: URL tersimpan, retry tidak mengunggah ulang', () async {
      final nota = buatFile('nota.jpg');
      hasilFoto[nota] = 'https://cdn/nota.jpg';
      final barang = 'https://cdn/b.jpg';
      final t = _trx(nota: nota, barang: barang);
      await hive.transaksiBox.put(_idLokal, t);
      await engine.pushTransaksi();

      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');
      await engine.unggahFotoTertunda([]);

      expect(t.fotoNota, 'https://cdn/nota.jpg');
      expect(t.statusFoto, 'pending');
      expect(dok()['foto_nota'], '');

      diunggah.clear();
      await buatEngine().unggahFotoTertunda([]);

      expect(diunggah, isEmpty);
      expect(t.statusFoto, 'ok');
      expect(dok()['foto_nota'], 'https://cdn/nota.jpg');
    });

    test('baris belum terkirim tidak diunggah: belum ada dokumennya', () async {
      final nota = buatFile('nota.jpg');
      hasilFoto[nota] = 'https://cdn/nota.jpg';
      final t = _trx(nota: nota);
      await hive.transaksiBox.put(_idLokal, t);
      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');

      await engine.siklus();

      expect(diunggah, isEmpty);
      expect(t.statusSinkronisasi, 'pending');
    });

    test('baris pending_delete tidak diunggah', () async {
      final nota = buatFile('nota.jpg');
      await hive.transaksiBox.put(_idLokal, _trx(nota: nota, status: 'pending_delete'));

      await engine.siklus();

      expect(diunggah, isEmpty);
    });

    test('foto diganti selama unggahan: URL lama tidak dipasang ke foto baru', () async {
      final lama = buatFile('lama.jpg');
      final baru = buatFile('baru.jpg');
      final t = _trx(nota: lama, barang: 'https://cdn/b.jpg');
      await hive.transaksiBox.put(_idLokal, t);
      await engine.pushTransaksi();
      unggahKhusus = (path) async {
        t.fotoNota = baru;
        await t.save();
        return 'https://cdn/lama.jpg';
      };

      await engine.unggahFotoTertunda([]);

      expect(t.fotoNota, baru);
      expect(t.statusFoto, 'pending');
    });

    test('baris dihapus dari box selama unggahan: tidak melempar', () async {
      final t = _trx(nota: buatFile('nota.jpg'));
      await hive.transaksiBox.put(_idLokal, t);
      await engine.pushTransaksi();
      unggahKhusus = (_) async {
        await hive.transaksiBox.delete(_idLokal);
        return 'https://cdn/x.jpg';
      };

      final masalah = <SyncIssue>[];
      await engine.unggahFotoTertunda(masalah);

      expect(masalah, isEmpty);
      expect(hive.transaksiBox.containsKey(_idLokal), isFalse);
    });

    test('dokumen hilang: tercatat dan tetap pending', () async {
      final t = _trx(nota: 'https://cdn/n.jpg', barang: 'https://cdn/b.jpg', status: 'synced');
      await hive.transaksiBox.put(_idLokal, t);

      final laporan = await engine.siklus();

      expect(t.statusFoto, 'pending');
      expect(laporan.masalah.map((m) => m.jenis), contains('dokumen_hilang'));
    });
  });

  group('Salinan foto_tertunda', () {
    late Directory dokumen;

    setUp(() async {
      dokumen = await dir.createTemp('dokumen');
      FotoTertunda.direktoriDokumen = () async => dokumen;
    });

    tearDown(() {
      FotoTertunda.direktoriDokumen = () => dokumen.parent.createTemp();
    });

    test('foto asli tetap, salinan dipakai, nama memuat idLokal dan jenis', () async {
      final asli = buatFile('kamera.jpg');

      final salinan = await FotoTertunda.salin(asli, idLokal: 'x_1', jenis: 'nota');

      expect(salinan, isNot(asli));
      expect(salinan, contains('foto_tertunda'));
      expect(salinan, contains('x_1_nota_'));
      expect(File(asli).existsSync(), isTrue);
      expect(File(salinan).readAsStringSync(), 'isi');
    });

    test('sumber tidak ada: path asli tetap dipakai', () async {
      final path = '${dir.path}/tidak-ada.jpg';

      expect(await FotoTertunda.salin(path, idLokal: 'x', jenis: 'nota'), path);
    });

    test('direktori tidak tersedia: path asli tetap dipakai', () async {
      FotoTertunda.direktoriDokumen = () async => throw const FileSystemException('x');
      final asli = buatFile('kamera.jpg');

      expect(await FotoTertunda.salin(asli, idLokal: 'x', jenis: 'nota'), asli);
    });

    test('URL dan kosong dibiarkan', () async {
      expect(await FotoTertunda.salin('', idLokal: 'x', jenis: 'nota'), '');
      expect(
        await FotoTertunda.salin('https://cdn/a.jpg', idLokal: 'x', jenis: 'nota'),
        'https://cdn/a.jpg',
      );
    });

    test('unggahan berhasil menghapus salinan, tetapi tidak foto di luar folder', () async {
      final asli = buatFile('galeri.jpg');
      final salinan = await FotoTertunda.salin(asli, idLokal: _idLokal, jenis: 'nota');
      hasilFoto[salinan] = 'https://cdn/s.jpg';
      hasilFoto[asli] = 'https://cdn/g.jpg';
      await hive.transaksiBox.put(_idLokal, _trx(nota: salinan, barang: asli));

      await engine.siklus();

      expect(File(salinan).existsSync(), isFalse);
      expect(File(asli).existsSync(), isTrue);
    });

    test('hapus transaksi membersihkan salinannya', () async {
      final salinan = await FotoTertunda.salin(
        buatFile('k.jpg'),
        idLokal: _idLokal,
        jenis: 'nota',
      );
      await hive.transaksiBox.put(_idLokal, _trx(nota: salinan, status: 'pending_delete'));

      await engine.siklus();

      expect(File(salinan).existsSync(), isFalse);
    });

    test('controller: simpan memakai salinan dan berstatus pending', () async {
      final asli = buatFile('kamera.jpg');
      await hive.usersBox.put(
        'currentUser',
        UserHiveModel(
          id: _agen,
          username: 'agen',
          passwordHash: '',
          role: 'pengepul',
          sisaUangJalan: 1000000,
          waktuDibuat: DateTime(2026),
        ),
      );

      await TransaksiController().simpanTransaksi(
        petaniTerpilih: null,
        namaPenjual: 'Pak',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '1',
        hargaText: '1000',
        fotoNotaPath: asli,
        fotoBarangPath: '',
        izinkanTanpaFoto: true,
      );
      await tungguSync();

      final t = hive.transaksiBox.values.single;
      expect(t.fotoNota, contains('foto_tertunda'));
      expect(t.statusFoto, 'pending');
    });

    test('controller: edit dengan foto baru kembali pending, salinan lama terhapus', () async {
      final lama = await FotoTertunda.salin(
        buatFile('lama.jpg'),
        idLokal: _idLokal,
        jenis: 'nota',
      );
      final t = _trx(nota: lama, status: 'synced', statusFoto: 'hilang');
      await hive.transaksiBox.put(_idLokal, t);

      await TransaksiController().updateTransaksi(
        t,
        petaniTerpilih: null,
        namaPenjual: 'Pak',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '10',
        hargaText: '5000',
        fotoNotaPath: buatFile('baru.jpg'),
        fotoBarangPath: '',
      );
      await tungguSync();

      expect(t.statusFoto, 'pending');
      expect(t.fotoNota, contains('foto_tertunda'));
      expect(t.fotoNota, isNot(lama));
      expect(File(lama).existsSync(), isFalse);
    });

    test('controller: edit tanpa ganti foto tidak mengubah status foto', () async {
      final t = _trx(
        nota: 'https://cdn/n.jpg',
        barang: 'https://cdn/b.jpg',
        status: 'synced',
        statusFoto: 'ok',
      );
      await hive.transaksiBox.put(_idLokal, t);

      await TransaksiController().updateTransaksi(
        t,
        petaniTerpilih: null,
        namaPenjual: 'Pak',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '10',
        hargaText: '5000',
        fotoNotaPath: 'https://cdn/n.jpg',
        fotoBarangPath: 'https://cdn/b.jpg',
      );
      await tungguSync();

      expect(t.statusFoto, 'ok');
    });
  });

  group('Pull di perangkat lain', () {
    Map<String, dynamic> dokCloud({String status = 'ok', String nota = ''}) => {
          'id_lokal': _idLokal,
          'pengepul_id': _agen,
          'petani_id': '',
          'nama_komoditas': 'Gabah',
          'total_bayar': 50000.0,
          'foto_nota': nota,
          'foto_fisik_barang': '',
          'status_foto': status,
        };

    test('path lokal dari data lama di cloud menjadi kosong', () async {
      remote.tanam('transaksi', dokCloud(nota: '/data/user/0/app/nota.jpg'));

      await engine.siklus();

      expect(hive.transaksiBox.get(_idLokal)!.fotoNota, '');
    });

    test('pending di cloud tidak menjadi tugas perangkat ini', () async {
      remote.tanam('transaksi', dokCloud(status: 'pending'));

      await engine.siklus();
      final jumlahTulis = remote.panggilanTulis('transaksi').length;
      await buatEngine().siklus();

      expect(hive.transaksiBox.get(_idLokal)!.statusFoto, 'menunggu_asal');
      expect(remote.panggilanTulis('transaksi'), hasLength(jumlahTulis));
      expect(remote.dokumen('transaksi').single['status_foto'], 'pending');
    });

    test('URL yang terunggah belakangan sampai ke baris yang sudah ditarik', () async {
      remote.tanam('transaksi', dokCloud(status: 'pending'));
      await engine.siklus();

      await remote.updateOne('transaksi', {'id_lokal': _idLokal}, {
        r'$set': {'foto_nota': 'https://cdn/n.jpg', 'status_foto': 'ok'},
      });
      await buatEngine().siklus();

      final t = hive.transaksiBox.get(_idLokal)!;
      expect(t.fotoNota, 'https://cdn/n.jpg');
      expect(t.statusFoto, 'ok');
    });

    test('baris dengan unggahan lokal tidak tertimpa nilai cloud', () async {
      final nota = buatFile('nota.jpg');
      remote.tanam('transaksi', dokCloud(status: 'ok', nota: 'https://cdn/lama.jpg'));
      final t = _trx(nota: nota, barang: 'https://cdn/b.jpg', status: 'synced');
      await hive.transaksiBox.put(_idLokal, t);

      await engine.siklus();

      expect(t.fotoNota, nota);
      expect(t.statusFoto, 'pending');
    });
  });

  group('Isi awal sekali jalan', () {
    Future<void> muatUlang() async {
      await Hive.close();
      await hive.init(testPath: dir.path);
    }

    test('path lokal: pending bila file ada, hilang bila tidak, URL tidak disentuh', () async {
      final ada = buatFile('ada.jpg');
      await hive.settingsBox.delete('statusFotoVersi');
      await hive.transaksiBox.putAll({
        'a': _trx(idLokal: 'a', nota: ada, status: 'synced', statusFoto: 'ok'),
        'b': _trx(idLokal: 'b', nota: '${dir.path}/x.jpg', status: 'synced', statusFoto: 'ok'),
        'c': _trx(idLokal: 'c', nota: 'https://cdn/c.jpg', status: 'synced', statusFoto: 'ok'),
        'd': _trx(idLokal: 'd', nota: ada, status: 'pending', statusFoto: 'ok'),
      });

      await muatUlang();

      expect(hive.transaksiBox.get('a')!.statusFoto, 'pending');
      expect(hive.transaksiBox.get('b')!.statusFoto, 'hilang');
      expect(hive.transaksiBox.get('c')!.statusFoto, 'ok');
      expect(hive.transaksiBox.get('d')!.statusFoto, 'pending');
    });

    test('hanya sekali: status yang sudah selesai tidak dihidupkan lagi', () async {
      final ada = buatFile('ada.jpg');
      await hive.transaksiBox.put(
        'a',
        _trx(idLokal: 'a', nota: ada, status: 'synced', statusFoto: 'ok'),
      );

      await muatUlang();

      expect(hive.transaksiBox.get('a')!.statusFoto, 'ok');
    });
  });

  test('bersihkan cache: baris yang fotonya belum terunggah dipertahankan', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await hive.transaksiBox.putAll({
      'a': _trx(idLokal: 'a', status: 'synced', statusFoto: 'pending'),
      'b': _trx(idLokal: 'b', status: 'synced', statusFoto: 'ok'),
    });

    final jumlah = await ProfilController().bersihkanCacheTersinkronisasi();

    expect(jumlah, 1);
    expect(hive.transaksiBox.containsKey('a'), isTrue);
    expect(hive.transaksiBox.containsKey('b'), isFalse);
  });
}
