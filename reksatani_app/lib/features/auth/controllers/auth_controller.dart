import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Import mongo_dart
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
        errorMessage.value = 'Username tidak ditemukan di database pusat!';
        isLoading.value = false;
        return false;
      }

      // 4. Validasi Password
      // CATATAN: Pastikan nama field di MongoDB-mu adalah 'password_hash' atau sesuaikan
      if (userDoc['password_hash'] != password) {
        errorMessage.value = 'Password yang Anda masukkan salah!';
        isLoading.value = false;
        return false;
      }

      // 5. Jika COCOK, Kita ambil datanya dari MongoDB dan ubah jadi format Lokal (Hive)
      final loggedInUser = UserHiveModel(
        id: userDoc['_id'].toString(), // ObjectId dari Mongo diubah ke String
        username: userDoc['username'],
        passwordHash: userDoc['password_hash'],
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
      errorMessage.value = 'Gagal terhubung ke Server. Pastikan ada sinyal internet saat Login. Error: $e';
      isLoading.value = false;
      return false;
    }
  }

  // Fungsi Logout
  Future<void> logout() async {
    await HiveService().usersBox.delete('currentUser');
  }
}