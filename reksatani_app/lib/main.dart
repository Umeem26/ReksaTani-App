import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/master_data_service.dart';
import 'services/mongodb_service.dart';
import 'services/hive_service.dart';
import 'core/routing/app_router.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Peringatan: Gagal meload .env file. Error: $e");
  }

  try {
    final hiveService = HiveService();
    await hiveService.init();
  } catch (e) {
    debugPrint("🚨 ERROR FATAL: Hive gagal diinisialisasi! Error: $e");
  }

  try {
    await MongoDatabase.connect();
  } catch (e) {
    debugPrint("🌐 Peringatan Jaringan: Gagal terhubung ke MongoDB Atlas. Aplikasi mode Offline. Error: $e");
  }

  // ─── LISTENER AUTO-SYNC LATAR BELAKANG ───
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    // Jika terdeteksi ada koneksi internet (Mobile atau WiFi)
    if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
      debugPrint("📡 Sinyal Internet Terdeteksi! Memulai Auto-Sync Latar Belakang...");
      MasterDataService().syncAll(); // Panggil fungsi reaktif
    }
  });

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