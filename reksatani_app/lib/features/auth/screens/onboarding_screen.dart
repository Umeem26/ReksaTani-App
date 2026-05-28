import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
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
  double _bgAnimValue = 0.0;
  Timer? _bgTimer;

  // ─── 3 SLIDE DATA ───
  final _pages = const [
    _OnboardData(
      lottieAsset: 'assets/onboard1.json',
      title: 'Pencatatan\nLuring Handal',
      subtitle: 'Tetap produktif di tengah kebun tanpa sinyal. Data tersimpan aman secara lokal & siap sinkron saat online.',
    ),
    _OnboardData(
      lottieAsset: 'assets/onboard2.json',
      title: 'Validasi & Mutu\nTerjamin',
      subtitle: 'Ambil foto nota & komoditas secara presisi. Validasi harga AI menjaga integritas transaksi Anda.',
    ),
    _OnboardData(
      lottieAsset: 'assets/onboard3.json',
      title: 'Pemetaan &\nAnalitik Cerdas',
      subtitle: 'Pantau sebaran lokasi panen dan valuasi aset secara realtime melalui dasbor peta interaktif.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) setState(() => _bgAnimValue = _bgAnimValue == 0.0 ? 1.0 : 0.0);
    });
  }

  Future<void> _selesaiOnboarding() async {
    await HiveService().completeOnboarding();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()));
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            // ─── 1. BACKGROUND ORBS (DEKORASI) ───
            AnimatedPositioned(
              duration: const Duration(seconds: 5), curve: Curves.easeInOut,
              top: _bgAnimValue == 0.0 ? -50 : size.height * 0.2,
              left: _bgAnimValue == 0.0 ? -50 : size.width * 0.4,
              child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.hijauMuda.withOpacity(0.25))),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 5), curve: Curves.easeInOut,
              bottom: _bgAnimValue == 0.0 ? size.height * 0.2 : -50,
              right: _bgAnimValue == 0.0 ? -20 : size.width * 0.2,
              child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.biru.withOpacity(0.15))),
            ),

            // ─── 2. MAIN CONTENT (PAGEVIEW) ───
            SafeArea(
              child: Column(
                children: [
                  // Logo & Skip Button Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 45, height: 45, padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 1.5)),
                          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                        ),
                        TextButton(
                          onPressed: _selesaiOnboarding,
                          child: const Text('Lewati', style: TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),

                  // PAGEVIEW UNTUK ANIMASI & TEKS
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (context, index) {
                        return _OnboardItemView(data: _pages[index], pageIndex: index, totalPages: _pages.length, onNext: () {
                          if (_pageIndex < _pages.length - 1) {
                            _pageCtrl.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart);
                          } else {
                            _selesaiOnboarding();
                          }
                        });
                      },
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

// ─── KOMPONEN ITEM PER HALAMAN ───
class _OnboardItemView extends StatelessWidget {
  final _OnboardData data;
  final int pageIndex;
  final int totalPages;
  final VoidCallback onNext;

  const _OnboardItemView({
    required this.data,
    required this.pageIndex,
    required this.totalPages,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Column(
      children: [
        // ─── BAGIAN ATAS: LOTTIE (MENGAMBANG & BESAR) ───
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Lottie.asset(
              data.lottieAsset,
              height: size.height * 0.45, // Ukuran diperbesar sesuai request
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),

        // ─── BAGIAN BAWAH: GLASS DOCK FOR TEXT ───
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 40, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indikator Dots Modern
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalPages,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: pageIndex == i ? 24 : 6,
                          decoration: BoxDecoration(
                            color: pageIndex == i ? AppTheme.hijauTua : AppTheme.hijauMuda.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Judul
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w900, 
                        color: AppTheme.textPrimary, 
                        height: 1.15, 
                        letterSpacing: -0.8
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Subtitle
                    Text(
                      data.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5, 
                        color: AppTheme.textSecond, 
                        height: 1.5, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Button Lanjut / Mulai
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.hijauTua,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: AppTheme.hijauTua.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            key: ValueKey<int>(pageIndex),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                pageIndex == totalPages - 1 ? 'MULAI SEKARANG' : 'LANJUT',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                pageIndex == totalPages - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 22,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardData {
  final String lottieAsset, title, subtitle;
  const _OnboardData({required this.lottieAsset, required this.title, required this.subtitle});
}