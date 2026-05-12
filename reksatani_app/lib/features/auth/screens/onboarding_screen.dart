import 'dart:async'; // Untuk timer animasi background
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart'; // Wajib import Lottie
import '../../../shared/widgets/app_theme.dart';
import '../../../services/hive_service.dart';
import '../../../core/routing/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _pageIndex = 0;
  
  // State untuk animasi background
  double _bgAnimValue = 0.0;
  Timer? _bgTimer;

  // ─── 1. DATA ONBOARDING DITINGKATKAN (SEKARANG 4 HALAMAN) ───
  final _pages = const [
    _OnboardData(
      lottieAsset: 'assets/onboard1.json', // Menggunakan Lottie
      title: 'Pencatatan\nLuring Handal',
      subtitle: 'Tetap produktif di tengah kebun tanpa sinyal. Data tersimpan aman secara lokal & siap sinkron saat online.',
    ),
    _OnboardData(
      lottieAsset: 'assets/onboard2.json',
      title: 'Validasi & Mutu\nTerjamin',
      subtitle: 'Ambil foto nota & komoditas secara presisi. Validasi harga otomatis menjaga integritas transaksi Anda.',
    ),
    _OnboardData(
      lottieAsset: 'assets/onboard3.json',
      title: 'Pemetaan\nPanen Cerdas',
      subtitle: 'Pantau sebaran lokasi panen dan analitik stok secara realtime melalui dasbor peta interaktif.',
    ),
    // Konten baru untuk halaman 4 (Master Data Manajer)
    _OnboardData(
      lottieAsset: 'assets/onboard4.json', 
      title: 'Dasbor Analitik\nManajer',
      subtitle: 'Kelola harga harian dinamis dan pantau total stok masuk serta valuasi nilai gudang secara akurat.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // ─── 2. INISIALISASI ANIMASI BACKGROUND SIMPEL ───
    // Mengubah nilai secara periodik untuk menggerakkan lingkaran background
    _bgTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _bgAnimValue = _bgAnimValue == 0.0 ? 1.0 : 0.0;
        });
      }
    });
  }

  Future<void> _selesaiOnboarding() async {
    await HiveService().completeOnboarding();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()));
  }

  @override
  void dispose() {
    _bgTimer?.cancel(); // Cancel timer agar tidak memory leak
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambil ukuran layar untuk kalkulasi background anim
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ─── 3. LATAR BELAKANG GRADIEN BERGERAK ───
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFF7FFF9), // Sangat pucat
                    Color(0xFFF0FFF4), 
                    Color(0xFFE6FFFA), // Segar di bawah
                  ],
                ),
              ),
            ),
            
            // ── Lingkaran Dekorasi Bergerak (The Magic for Glassmorphism) ──
            // Menggunakan AnimatedPositioned agar bergerak halus
            AnimatedPositioned(
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut,
              top: _bgAnimValue == 0.0 ? -30 : 50,
              left: _bgAnimValue == 0.0 ? -30 : 80,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Warna hijau pudar
                  color: const Color(0xFFC7F9CC).withOpacity(0.3), 
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut,
              bottom: _bgAnimValue == 0.0 ? 80 : 150,
              right: _bgAnimValue == 0.0 ? -20 : 60,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Warna teal/biru pudar
                  color: const Color(0xFFE6FFFA).withOpacity(0.6), 
                ),
              ),
            ),
            // Lingkaran kecil tambahan berwarna agak kuning pudar agar ramai
            AnimatedPositioned(
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut,
              top: size.height * 0.4,
              right: _bgAnimValue == 0.0 ? size.width * 0.8 : size.width * 0.1,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF3C7).withOpacity(0.3), // Kuning pudar
                ),
              ),
            ),

            // ─── 4. KONTEN UTAMA (KARTU KACA LOTTIE) ───
            SafeArea(
              child: Column(
                children: [
                  // Tombol Lewati
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: _selesaiOnboarding,
                        child: const Text('Lewati', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Kotak Logo PNG Kecil di Atas
                  Container(
                    width: 50, height: 50,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 5))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),

                  // PageView dalam Kartu Kaca Lottie
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (_, i) => _OnboardGlassLottiePage(data: _pages[i]),
                    ),
                  ),

                  // ─── 5. NAVIGASI BAWAH MODERN ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dots Indicator Modern (Sekarang menyesuaikan 4 hal)
                        Row(
                          children: List.generate(
                            _pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
                              height: 8,
                              width: _pageIndex == i ? 30 : 8, // Sedikit lebih panjang
                              decoration: BoxDecoration(
                                color: _pageIndex == i ? AppTheme.hijauMuda : AppTheme.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        // Tombol Lanjut/Mulai
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_pageIndex < _pages.length - 1) {
                                _pageCtrl.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                              } else {
                                _selesaiOnboarding();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.hijauMuda,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: AppTheme.hijauMuda.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Row(
                                key: ValueKey<int>(_pageIndex),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _pageIndex == _pages.length - 1 ? 'Mulai' : 'Lanjut',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _pageIndex == _pages.length - 1 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                                    size: 19,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model Data Ditingkatkan untuk Lottie
class _OnboardData {
  final String lottieAsset; // Path file JSON Lottie
  final String title, subtitle;
  const _OnboardData({required this.lottieAsset, required this.title, required this.subtitle});
}

// ─── KOMPONEN KARTU KACA LOTTIE (GLASSMORPHISM + LOTTIE) ───
class _OnboardGlassLottiePage extends StatelessWidget {
  final _OnboardData data;
  const _OnboardGlassLottiePage({required this.data});

  @override
  Widget build(BuildContext context) {
    // Media query untuk menyesuaikan tinggi Lottie agar pas di layar kecil
    final size = MediaQuery.of(context).size;
    final lottieHeight = size.height * 0.28; // 28% dari tinggi layar

    return Center(
      child: Container(
        margin: const EdgeInsets.all(28), // Sedikit lebih kecil margin agar muat 4 hal teks
        clipBehavior: Clip.antiAlias, 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 35,
              offset: const Offset(0, 12),
            )
          ],
        ),
        // ── Efek Blur Latar Belakang (Glass) ──
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), // Blur sedikit lebih intens
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45), // Sedikit lebih solid agar teks terbaca
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Biar wrap content
              children: [
                // ─── ANIMASI LOTTIE (MENGGANTI IKON) ───
                SizedBox(
                  height: lottieHeight,
                  width: double.infinity,
                  child: Lottie.asset(
                    data.lottieAsset,
                    fit: BoxFit.contain,
                    repeat: true, // Animasi berulang
                    animate: true,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Judul
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23, // Sedikit lebih besar
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.6,
                    shadows: [Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 10)]
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecond,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8), // Sedikit padding bawah
              ],
            ),
          ),
        ),
      ),
    );
  }
}