import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/mongodb_service.dart';
import 'services/hive_service.dart';
import 'core/routing/app_router.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  // Pastikan engine Flutter sudah siap
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 1. Load Environment Variables (.env)
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Peringatan: Gagal meload .env file. Pastikan file ada dan terdaftar di pubspec.yaml. Error: $e");
  }

  try {
    // 2. Inisialisasi Hive (Wajib berhasil karena ini Single Source of Truth)
    final hiveService = HiveService();
    await hiveService.init();
  } catch (e) {
    debugPrint("🚨 ERROR FATAL: Hive gagal diinisialisasi! Error: $e");
  }

  try {
    // 3. Konek ke MongoDB (Dibuat tidak memblokir aplikasi jika gagal)
    // Karena konsep kita Offline-first, kalau gagal konek Mongo, app harus tetap jalan.
    await MongoDatabase.connect();
  } catch (e) {
    debugPrint("🌐 Peringatan Jaringan: Gagal terhubung ke MongoDB Atlas. Aplikasi akan berjalan mode Offline. Error: $e");
  }

  // 4. Jalankan UI Aplikasinya
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReksaTani',
      debugShowCheckedModeBanner: false, // Menghilangkan pita debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // Arahkan ke Gatekeeper
      home: const SplashScreen(),
    );
  }
}