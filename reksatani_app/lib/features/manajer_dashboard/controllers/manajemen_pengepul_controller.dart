import 'package:mongo_dart/mongo_dart.dart' show modify, where;
import 'package:uuid/uuid.dart';
import '../../../../services/mongodb_service.dart';
import '../../../../services/hive_service.dart';
import '../../../../models/hive/user_hive_model.dart';

class ManajemenPengepulController {
  final _hive = HiveService();

  Future<List<Map<String, dynamic>>> getSemuaPengepul() async {
    try {
      final col = MongoDatabase.getCollection('users');
      final docs = await col.find(where.eq('role', 'pengepul')).toList();
      
      for (final d in docs) {
        final id = d['_id'].toString();
        final m = UserHiveModel(
          id: id,
          username: d['username'] ?? '',
          passwordHash: d['password_hash'] ?? '',
          role: d['role'] ?? 'pengepul',
          sisaUangJalan: (d['sisa_uang_jalan'] ?? 0).toDouble(),
          waktuDibuat: DateTime.tryParse(d['waktu_dibuat']?.toString() ?? '') ?? DateTime.now(),
        );
        if (id != 'currentUser') {
          await _hive.usersBox.put(m.id, m);
        }
      }
      return docs;
    } catch (e) {
      print('Error getSemuaPengepul: $e');
      final lokal = _hive.usersBox.values.where((u) => u.role == 'pengepul').toList();
      return lokal.map((u) => {
        '_id': u.id,
        'username': u.username,
        'password_hash': u.passwordHash,
        'role': u.role,
        'sisa_uang_jalan': u.sisaUangJalan,
        'waktu_dibuat': u.waktuDibuat.toIso8601String(),
      }).toList();
    }
  }

  Future<bool> tambahPengepul({
    required String username,
    required String password,
    required double sisaUangJalan,
  }) async {
    try {
      final col = MongoDatabase.getCollection('users');
      
      final existing = await col.findOne(where.eq('username', username.trim()));
      if (existing != null) {
        return false;
      }

      final id = const Uuid().v4();
      final now = DateTime.now();
      await col.insert({
        '_id': id,
        'username': username.trim(),
        'password_hash': password,
        'role': 'pengepul',
        'sisa_uang_jalan': sisaUangJalan,
        'waktu_dibuat': now.toIso8601String(),
      });

      final m = UserHiveModel(
        id: id,
        username: username.trim(),
        passwordHash: password,
        role: 'pengepul',
        sisaUangJalan: sisaUangJalan,
        waktuDibuat: now,
      );
      await _hive.usersBox.put(id, m);

      return true;
    } catch (e) {
      print('Exception tambahPengepul: $e');
      return false;
    }
  }

  Future<bool> editPengepul({
    required dynamic id,
    required String username,
    required String password,
    required double sisaUangJalan,
  }) async {
    try {
      final col = MongoDatabase.getCollection('users');
      
      final existing = await col.findOne(where.eq('username', username.trim()).ne('_id', id));
      if (existing != null) {
        return false;
      }

      await col.updateOne(
        where.eq('_id', id),
        modify
            .set('username', username.trim())
            .set('password_hash', password)
            .set('sisa_uang_jalan', sisaUangJalan),
      );

      final m = _hive.usersBox.get(id.toString());
      if (m != null) {
        m.username = username.trim();
        m.passwordHash = password;
        m.sisaUangJalan = sisaUangJalan;
        await m.save();
      }

      return true;
    } catch (e) {
      print('Error editPengepul: $e');
      return false;
    }
  }

  Future<bool> hapusPengepul(dynamic id) async {
    try {
      final col = MongoDatabase.getCollection('users');
      await col.deleteOne(where.eq('_id', id));

      await _hive.usersBox.delete(id.toString());

      return true;
    } catch (e) {
      print('Error hapusPengepul: $e');
      return false;
    }
  }
}
