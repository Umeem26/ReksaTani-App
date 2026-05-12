import 'package:mongo_dart/mongo_dart.dart' show modify, where;
import '../../../../services/mongodb_service.dart';
import '../../../../services/hive_service.dart';
import 'package:uuid/uuid.dart';

class ManajemenKomoditasController {
  final _hive = HiveService();

  Future<List<Map<String, dynamic>>> getSemuaKomoditas() async {
    try {
      final col = MongoDatabase.getCollection('komoditas');
      final docs = await col.find().toList();
      return docs;
    } catch (e) {
      print('Error getSemuaKomoditas: $e');
      return [];
    }
  }

  Future<bool> tambahKomoditas({
    required String namaKomoditas,
    required String unitSatuan,
    required List<Map<String, dynamic>> gradeKualitas,
  }) async {
    try {
      final user = _hive.usersBox.get('currentUser');
      final col = MongoDatabase.getCollection('komoditas');
      
      await col.insertOne({
        '_id': const Uuid().v4(),
        'nama_komoditas': namaKomoditas,
        'unit_satuan': unitSatuan,
        'grade_kualitas': gradeKualitas,
        'diperbarui_oleh': user?.id ?? '',
        'waktu_pembaruan': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error tambahKomoditas: $e');
      return false;
    }
  }

  Future<bool> editKomoditas({
    required dynamic id,
    required String namaKomoditas,
    required String unitSatuan,
    required List<Map<String, dynamic>> gradeKualitas,
  }) async {
    try {
      final user = _hive.usersBox.get('currentUser');
      final col = MongoDatabase.getCollection('komoditas');
      
      await col.updateOne(
        where.eq('_id', id),
        modify
            .set('nama_komoditas', namaKomoditas)
            .set('unit_satuan', unitSatuan)
            .set('grade_kualitas', gradeKualitas)
            .set('diperbarui_oleh', user?.id ?? '')
            .set('waktu_pembaruan', DateTime.now().toIso8601String()),
      );
      return true;
    } catch (e) {
      print('Error editKomoditas: $e');
      return false;
    }
  }

  Future<bool> hapusKomoditas(dynamic id) async {
    try {
      final col = MongoDatabase.getCollection('komoditas');
      await col.deleteOne(where.eq('_id', id));
      return true;
    } catch (e) {
      print('Error hapusKomoditas: $e');
      return false;
    }
  }
}
