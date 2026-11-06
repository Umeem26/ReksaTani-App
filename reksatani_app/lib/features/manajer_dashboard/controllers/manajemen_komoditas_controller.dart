import 'package:uuid/uuid.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/sync/mongo_id.dart';
import '../../../../services/sync/mongo_remote.dart';
import '../../../../services/sync/sync_remote.dart';

enum HasilSimpanKomoditas { berhasil, tidakValid, tidakDitemukan, gagal }

class ManajemenKomoditasController {
  ManajemenKomoditasController({SyncRemote? remote})
      : _remote = remote ?? MongoRemote();

  final SyncRemote _remote;
  final _hive = HiveService();

  static const String _koleksi = 'komoditas';

  /// Sama dengan enum `grade` pada validator koleksi `komoditas` di Atlas.
  static const Set<String> gradeSah = {'A', 'B', 'C'};

  /// Pesan untuk layar bila penyimpanan tidak berhasil.
  static String pesanGagal(HasilSimpanKomoditas hasil) => switch (hasil) {
        HasilSimpanKomoditas.tidakValid =>
          'Grade harus A, B, atau C dan harga tidak boleh negatif.',
        HasilSimpanKomoditas.tidakDitemukan =>
          'Data komoditas tidak ditemukan. Muat ulang daftar lalu coba lagi.',
        _ => 'Gagal menyimpan komoditas. Periksa koneksi lalu coba lagi.',
      };

  static String? validasiGrade(String? teks) {
    final grade = (teks ?? '').trim().toUpperCase();
    if (grade.isEmpty) return 'Grade tidak boleh kosong';
    if (!gradeSah.contains(grade)) return 'Hanya A, B, C';
    return null;
  }

  static String? validasiHarga(String? teks) {
    final isi = (teks ?? '').trim();
    if (isi.isEmpty) return 'Harga tidak boleh kosong';
    final harga = double.tryParse(isi);
    if (harga == null || !harga.isFinite) return 'Format harga tidak valid';
    if (harga < 0) return 'Harga tidak boleh negatif';
    return null;
  }

  /// Penjaga terakhir sebelum menulis, karena form bukan satu-satunya pemanggil.
  static bool gradeKualitasSah(List<Map<String, dynamic>> gradeKualitas) {
    if (gradeKualitas.isEmpty) return false;
    return gradeKualitas.every((g) {
      final harga = g['harga_maks'];
      return gradeSah.contains(g['grade']) &&
          harga is num &&
          harga.isFinite &&
          harga >= 0;
    });
  }

  Future<List<Map<String, dynamic>>> getSemuaKomoditas() async {
    try {
      final docs = await _remote.find(_koleksi, const {});
      final allowedNames = {'gabah', 'kopi robusta', 'sawit'};
      return docs.where((d) {
        final name = (d['nama_komoditas'] ?? '').toString().toLowerCase();
        return allowedNames.contains(name);
      }).toList();
    } catch (e) {
      print('Error getSemuaKomoditas: ${e.runtimeType}');
      return [];
    }
  }

  Future<HasilSimpanKomoditas> tambahKomoditas({
    required String namaKomoditas,
    required String unitSatuan,
    required List<Map<String, dynamic>> gradeKualitas,
  }) async {
    if (!gradeKualitasSah(gradeKualitas)) return HasilSimpanKomoditas.tidakValid;

    try {
      final user = _hive.usersBox.get('currentUser');
      final hasil = await _remote.updateOne(
        _koleksi,
        {'_id': const Uuid().v4()},
        {
          r'$setOnInsert': {
            'nama_komoditas': namaKomoditas,
            'unit_satuan': unitSatuan,
            'grade_kualitas': gradeKualitas,
            'diperbarui_oleh': user?.id ?? '',
            'waktu_pembaruan_harga': DateTime.now().toIso8601String(),
          },
        },
        upsert: true,
      );
      return hasil.kenaDokumen
          ? HasilSimpanKomoditas.berhasil
          : HasilSimpanKomoditas.gagal;
    } catch (e) {
      print('Exception tambahKomoditas: ${e.runtimeType}');
      return HasilSimpanKomoditas.gagal;
    }
  }

  Future<HasilSimpanKomoditas> editKomoditas({
    required dynamic id,
    required String namaKomoditas,
    required String unitSatuan,
    required List<Map<String, dynamic>> gradeKualitas,
  }) async {
    if (!gradeKualitasSah(gradeKualitas)) return HasilSimpanKomoditas.tidakValid;

    try {
      final user = _hive.usersBox.get('currentUser');
      final hasil = await _remote.updateOne(
        _koleksi,
        MongoId.filterId(id),
        {
          r'$set': {
            'nama_komoditas': namaKomoditas,
            'unit_satuan': unitSatuan,
            'grade_kualitas': gradeKualitas,
            'diperbarui_oleh': user?.id ?? '',
            'waktu_pembaruan_harga': DateTime.now().toIso8601String(),
          },
        },
      );
      if (!hasil.ok) return HasilSimpanKomoditas.gagal;
      // Server menjawab sukses walau filter tidak mengenai dokumen apa pun.
      if (hasil.matched == 0) return HasilSimpanKomoditas.tidakDitemukan;
      return HasilSimpanKomoditas.berhasil;
    } catch (e) {
      print('Error editKomoditas: ${e.runtimeType}');
      return HasilSimpanKomoditas.gagal;
    }
  }

  Future<bool> hapusKomoditas(dynamic id) async {
    try {
      final hasil = await _remote.deleteOne(_koleksi, MongoId.filterId(id));
      return hasil.ok;
    } catch (e) {
      print('Error hapusKomoditas: ${e.runtimeType}');
      return false;
    }
  }
}
