import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../../models/hive/user_hive_model.dart';
import '../../../services/hive_service.dart';
import '../../../services/sync/mongo_id.dart';
import '../../../services/sync/mongo_remote.dart';
import '../../../services/sync/sync_remote.dart';

class AuthController {
  AuthController({SyncRemote? remote}) : _remote = remote ?? MongoRemote();

  final SyncRemote _remote;

  /// Satu pesan untuk username yang tidak ada dan password yang salah, supaya
  /// layar login tidak bisa dipakai untuk menebak username yang terdaftar.
  static const String pesanLoginGagal = 'Username atau password salah';

  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  Future<bool> login(String username, String password) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      // Aplikasi bisa dimulai saat offline, jadi koneksi mungkin belum ada.
      await _remote.ping();

      // 1. Cari data berdasarkan username di awan (Cloud)
      final hasilCari = await _remote.find('users', {'username': username});

      // 2. Jika username tidak ditemukan di MongoDB
      if (hasilCari.isEmpty) {
        errorMessage.value = pesanLoginGagal;
        isLoading.value = false;
        return false;
      }
      final userDoc = hasilCari.first;

      // 3. Validasi Password dengan Bcrypt & Auto-migration
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
        // TODO: hapus fallback plaintext ini setelah data Atlas diperiksa dan tidak
        // ada lagi `password_hash` yang bukan bcrypt. Menghapusnya sekarang bisa
        // mengunci akun lama yang belum pernah login sejak migrasi otomatis di bawah.
        isCorrect = storedHash == password;
        if (isCorrect) {
          needsMigration = true;
        }
      }

      if (!isCorrect) {
        errorMessage.value = pesanLoginGagal;
        isLoading.value = false;
        return false;
      }

      String finalPasswordHash = storedHash;
      if (needsMigration) {
        finalPasswordHash = BCrypt.hashpw(password, BCrypt.gensalt());
        await _remote.updateOne(
          'users',
          {'_id': userDoc['_id']},
          {
            r'$set': {'password_hash': finalPasswordHash},
          },
        );
      }

      // 4. Jika COCOK, Kita ambil datanya dari MongoDB dan ubah jadi format Lokal (Hive)
      final loggedInUser = UserHiveModel(
        id: MongoId.kanonik(userDoc['_id']),
        username: userDoc['username'],
        passwordHash: finalPasswordHash,
        role: userDoc['role'], // 'pengepul' atau 'manajer'
        sisaUangJalan: (userDoc['sisa_uang_jalan'] ?? 0).toDouble(), // Pastikan double
        waktuDibuat: DateTime.now(),
      );

      // 5. Simpan sesi login ke Hive! (Inilah kunci Offline-First)
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