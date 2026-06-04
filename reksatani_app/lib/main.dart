import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/master_data_service.dart';
import 'services/mongodb_service.dart';
import 'services/hive_service.dart';
import 'core/routing/app_router.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── FIX: Memastikan Hive benar-benar siap sebelum menggambar UI ──
  bool isHiveReady = false;
  try {
    final hiveService = HiveService();
    await hiveService.init();
    isHiveReady = true;
  } catch (e) {
    debugPrint("🚨 ERROR FATAL: Hive gagal diinisialisasi secara total! Error: $e");
  }

  try {
    await MongoDatabase.connect();
  } catch (e) {
    debugPrint("🌐 Peringatan Jaringan: Gagal terhubung ke MongoDB Atlas. Aplikasi mode Offline. Error: $e");
  }

  // ─── LISTENER AUTO-SYNC LATAR BELAKANG ───
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
      debugPrint("📡 Sinyal Internet Terdeteksi! Memulai Auto-Sync Latar Belakang...");
      if (isHiveReady) MasterDataService().syncAll(); 
    }
  });

  // Jika HP gagal membuat database (Storage penuh / rusak parah)
  if (!isHiveReady) {
      runApp(const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text('Aplikasi tidak dapat memuat penyimpanan lokal.\nSilakan hapus data aplikasi di pengaturan HP Anda atau coba instal ulang aplikasi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          ),
        ),
      ));
      return;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReksaTani',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}