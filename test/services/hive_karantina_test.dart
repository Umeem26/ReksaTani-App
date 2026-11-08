import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';

/// Mewakili salah skema: file valid, tetapi adapter gagal membacanya.
class _AdapterRusak extends TypeAdapter<TransaksiHiveModel> {
  @override
  final int typeId = 3;

  @override
  TransaksiHiveModel read(BinaryReader reader) => throw StateError('skema salah');

  @override
  void write(BinaryWriter writer, TransaksiHiveModel obj) =>
      throw StateError('skema salah');
}

TransaksiHiveModel _trx(String idLokal) => TransaksiHiveModel(
      idLokal: idLokal,
      pengepulId: 'agen',
      petaniId: 'petani',
      namaPengepul: 'Agen',
      namaPetani: 'Petani',
      namaKomoditas: 'Gabah',
      gradeTerpilih: 'A',
      berat: 10,
      hargaBeliSatuan: 5000,
      nominalPotongKasbon: 0,
      totalBayar: 50000,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: 'pending',
      createdAt: DateTime(2026, 1, 1),
    );

/// `openBox` yang gagal juga meninggalkan error async tak tertangani dari
/// completer internal Hive (`hive_impl.dart:116-119`). Di aplikasi itu hanya
/// tercatat di log, tetapi di tes akan menggagalkan tes. Karena itu init
/// dijalankan di zona sendiri, sedangkan hasilnya tetap diteruskan ke pemanggil.
Future<void> _init(HiveService service, String folder) {
  final selesai = Completer<void>();
  runZonedGuarded(() async {
    try {
      await service.init(testPath: folder);
      selesai.complete();
    } catch (e, st) {
      selesai.completeError(e, st);
    }
  }, (_, _) {});
  return selesai.future;
}

void main() {
  final service = HiveService();
  late Directory dir;
  late File fileTransaksi;
  late Directory folderKarantina;

  Future<void> pasangAdapterAsli() async {
    Hive.registerAdapter<TransaksiHiveModel>(
      TransaksiHiveModelAdapter(),
      override: true,
    );
  }

  Future<void> pasangAdapterRusak() async {
    Hive.registerAdapter<TransaksiHiveModel>(_AdapterRusak(), override: true);
  }

  /// Menyiapkan box transaksi berisi satu baris, lalu menutup semua box.
  Future<void> siapkanData() async {
    await pasangAdapterAsli();
    await _init(service, dir.path);
    await service.transaksiBox.put('t1', _trx('t1'));
    await service.usersBox.put(
      'currentUser',
      UserHiveModel(
        id: 'agen',
        username: 'agen',
        passwordHash: '',
        role: 'pengepul',
        sisaUangJalan: 100,
        waktuDibuat: DateTime(2026),
      ),
    );
    await Hive.close();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_karantina');
    fileTransaksi = File(p.join(dir.path, 'transaksibox.hive'));
    folderKarantina = Directory(p.join(dir.path, 'hive_karantina'));
    service.jam = () => DateTime(2026, 1, 2, 3, 4, 5);
  });

  tearDown(() async {
    await pasangAdapterAsli();
    await Hive.close();
    service.jam = DateTime.now;
    await dir.delete(recursive: true);
  });

  test('box gagal dibuka: salinan identik byte, box baru kosong, notifikasi muncul',
      () async {
    await siapkanData();
    final isiAsli = await fileTransaksi.readAsBytes();
    expect(isiAsli, isNotEmpty);

    await pasangAdapterRusak();
    await _init(service, dir.path);

    final salinan = File(
        p.join(folderKarantina.path, 'transaksibox_20260102_030405.hive'));
    expect(await salinan.exists(), isTrue);
    expect(await salinan.readAsBytes(), isiAsli);

    expect(service.transaksiBox, isEmpty);

    final pesan = service.notifikasiBox.values.map((n) => n.pesan).toList();
    expect(pesan, hasLength(1));
    expect(pesan.single, contains('transaksi'));
    expect(pesan.single, contains('dicadangkan'));
    expect(pesan.single, contains('Hubungi admin'));

    // Box lain tidak ikut terdampak.
    expect(service.usersBox.get('currentUser')?.username, 'agen');
  });

  test('salinan karantina tidak menyertakan file .lock', () async {
    await siapkanData();

    await pasangAdapterRusak();
    await _init(service, dir.path);

    final nama = await folderKarantina.list().map((e) => p.basename(e.path)).toList();
    expect(nama, ['transaksibox_20260102_030405.hive']);
  });

  test('salinan bisa dipulihkan: disalin balik lalu dibuka adapter yang benar',
      () async {
    await siapkanData();
    await pasangAdapterRusak();
    await _init(service, dir.path);
    await Hive.close();

    final salinan = File(
        p.join(folderKarantina.path, 'transaksibox_20260102_030405.hive'));
    await salinan.copy(fileTransaksi.path);

    await pasangAdapterAsli();
    await _init(service, dir.path);

    expect(service.transaksiBox.get('t1')?.totalBayar, 50000);
  });

  test('gagal menyalin: box TIDAK dihapus dan error diteruskan', () async {
    await siapkanData();
    final isiAsli = await fileTransaksi.readAsBytes();
    // File di posisi folder membuat pembuatan folder karantina gagal.
    await File(folderKarantina.path).writeAsString('bukan folder');

    await pasangAdapterRusak();
    await expectLater(_init(service, dir.path), throwsStateError);

    expect(await fileTransaksi.readAsBytes(), isiAsli);

    // Setelah adapter benar, data masih bisa dibaca.
    await Hive.close();
    await pasangAdapterAsli();
    await _init(service, dir.path);
    expect(service.transaksiBox.get('t1')?.totalBayar, 50000);
  });

  test('FileSystemException: tidak mengkarantina dan tidak menghapus', () async {
    // Direktori di posisi file box membuat Hive melempar FileSystemException.
    final posisiBox = Directory(p.join(dir.path, 'usersbox.hive'));
    await posisiBox.create();
    await File(p.join(posisiBox.path, 'penanda')).writeAsString('tetap ada');

    await expectLater(
      _init(service, dir.path),
      throwsA(isA<FileSystemException>()),
    );

    expect(await File(p.join(posisiBox.path, 'penanda')).exists(), isTrue);
    expect(await folderKarantina.exists(), isFalse);
  });

  test('hanya 3 salinan terbaru yang disimpan per box', () async {
    for (var detik = 1; detik <= 5; detik++) {
      await siapkanData();
      service.jam = () => DateTime(2026, 1, 2, 3, 4, detik);
      await pasangAdapterRusak();
      await _init(service, dir.path);
      await Hive.close();
      service.jam = () => DateTime(2026, 1, 2, 3, 4, 5);
    }

    final nama = (await folderKarantina.list().map((e) => p.basename(e.path)).toList())
      ..sort();
    expect(nama, [
      'transaksibox_20260102_030403.hive',
      'transaksibox_20260102_030404.hive',
      'transaksibox_20260102_030405.hive',
    ]);
  });

  test('init normal tidak membuat folder karantina atau notifikasi', () async {
    await siapkanData();

    await _init(service, dir.path);

    expect(await folderKarantina.exists(), isFalse);
    expect(service.notifikasiBox, isEmpty);
    expect(service.transaksiBox.get('t1'), isNotNull);
  });
}
