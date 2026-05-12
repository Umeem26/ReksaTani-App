import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/app_theme.dart';
import '../../../services/hive_service.dart';
import '../../../core/routing/app_router.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim; // Tambah animasi skala

  @override
  void initState() {
    super.initState();
    // Animasi muncul yang lebih kompleks dan halus
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)
    ));

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
      parent: _animCtrl, 
      // Menggunakan easeOutCubic untuk efek membesar yang cepat di awal lalu melambat elegan
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic) 
    ));
    
    _animCtrl.forward();
    _pindahLayar();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pindahLayar() async {
    // Total waktu splash (2.5 detik)
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final hive = HiveService();
    
    Widget screenLanjut;
    if (hive.isFirstTime()) {
      screenLanjut = const OnboardingScreen();
    } else {
      screenLanjut = AppRouter.getGatekeeper();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screenLanjut,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, 
      child: Scaffold(
        backgroundColor: Colors.white, // BG Putih Bersih
        body: Stack(
          children: [
            // Watermark estetis tipis
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Text(
                  'REKSATANI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade100,
                    letterSpacing: 7
                  ),
                ),
              ),
            ),
            
            // KONTEN UTAMA
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── LOGO .PNG ASLI ───
                      Container(
                        width: 130, height: 130, // Sedikit lebih besar
                        padding: const EdgeInsets.all(10), // Padding agar logo tidak mepet border
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 40,
                              offset: const Offset(0, 15)
                            )
                          ],
                        ),
                        // LOAD GAMBAR ASSET LOGO.PNG
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain, // Logo utuh di dalam kotak
                          ),
                        ),
                      ),
                      const SizedBox(height: 24), // Jarak ke teks
                      
                      // ─── TEKS BRANDING BARU ───
                      Text(
                        'ReksaTani App',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary, // Hijau tua/gelap
                          letterSpacing: -0.5,
                          // Efek bayangan teks tipis agar premium
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                          ]
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rantai Pasok Pertanian Digital',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecond,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}