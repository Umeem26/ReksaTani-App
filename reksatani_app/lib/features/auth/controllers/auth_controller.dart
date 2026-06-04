import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Import mongo_dart
import 'package:bcrypt/bcrypt.dart';
import '../../../models/hive/user_hive_model.dart';
import '../../../services/hive_service.dart';
import '../../../services/mongodb_service.dart'; // Import MongoDB Service temanmu

class AuthController {
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  Future<bool> login(String username, String password) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      // 1. Panggil Collection 'users' dari MongoDB
      // Pastikan nama collection-nya benar (asumsi: 'users')
      var usersCollection = MongoDatabase.getCollection('users');

      // 2. Cari data berdasarkan username di awan (Cloud)
      var userDoc = await usersCollection.findOne(mongo.where.eq('username', username));

      // 3. Jika username tidak ditemukan di MongoDB
      if (userDoc == null) {
        errorMessage.value = 'Username tidak terdaftar. Silakan periksa kembali username Anda.';
        isLoading.value = false;
        return false;
      }

      // 4. Validasi Password dengan Bcrypt & Auto-migration
      final storedHash = userDoc['password_hash'] as String? ?? '';
      bool isCorrect = false;
      bool needsMigration = false;

      if (storedHash.startsWith('\$2a\$') || storedHash.startsWith('\$2b\$') || storedHash.startsWith('\$2y\$')) {
        try {
          isCorrect = BCrypt.checkpw(password, storedHash);
        } catch (e) {
          isCorrect = false;
        }
      } else {
        isCorrect = storedHash == password;
        if (isCorrect) {
          needsMigration = true;
        }
      }

      if (!isCorrect) {
        errorMessage.value = 'Password salah. Silakan coba lagi.';
        isLoading.value = false;
        return false;
      }

      String finalPasswordHash = storedHash;
      if (needsMigration) {
        finalPasswordHash = BCrypt.hashpw(password, BCrypt.gensalt());
        await usersCollection.updateOne(
          mongo.where.eq('_id', userDoc['_id']),
          mongo.modify.set('password_hash', finalPasswordHash),
        );
      }

      // 5. Jika COCOK, Kita ambil datanya dari MongoDB dan ubah jadi format Lokal (Hive)
      final loggedInUser = UserHiveModel(
        id: userDoc['_id'].toString(), // ObjectId dari Mongo diubah ke String
        username: userDoc['username'],
        passwordHash: finalPasswordHash,
        role: userDoc['role'], // 'pengepul' atau 'manajer'
        sisaUangJalan: (userDoc['sisa_uang_jalan'] ?? 0).toDouble(), // Pastikan double
        waktuDibuat: DateTime.now(),
      );

      // 6. Simpan sesi login ke Hive! (Inilah kunci Offline-First)
      await HiveService().usersBox.put('currentUser', loggedInUser);

      isLoading.value = false;
      return true; // Sukses login dari DB Pusat!

    } catch (e) {
      // Menangkap error jika internet putus saat sedang login
      errorMessage.value = 'Koneksi internet bermasalah. Pastikan perangkat Anda terhubung ke internet untuk masuk pertama kali.';
      isLoading.value = false;
      return false;
    }
  }

  // Fungsi Logout
  Future<void> logout() async {
    await HiveService().usersBox.delete('currentUser');
  }
}