import 'dart:ui';
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
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)
    ));

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
      parent: _animCtrl, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic) 
    ));

    _glowAnim = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(
      parent: _animCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeInOutSine)
    ));
    
    _animCtrl.forward();
    _pindahLayar();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── FIX LOGIKA: PEMANGGILAN SINGLETON HIVE SECARA AMAN ───
  Future<void> _pindahLayar() async {
    try {
      // Menunggu jalannya animasi splash screen selama 3 detik
      await Future.delayed(const Duration(milliseconds: 3000));
      if (!mounted) return;

      Widget screenLanjut;

      try {
        // FIX: Memanggil factory instance Singleton, bukan membuat instance baru kaku
        final hive = HiveService(); 
        
        // Memastikan box settingsBox sudah terbuka sempurna sebelum dibaca
        if (!hive.settingsBox.isOpen) {
          debugPrint('📡 [Hive-Fix] Membuka ulang settingsBox yang tertunda...');
          await hive.init();
        }

        // Mengecek kondisi onboarding menggunakan fungsi bawaan komandan
        bool isFirst = hive.isFirstTime();
        screenLanjut = isFirst ? const OnboardingScreen() : AppRouter.getGatekeeper();
      } catch (e) {
        // Proteksi jika terjadi silent error lokal, arahkan ke Gatekeeper utama
        debugPrint('⚠️ [Anti-Stuck Alert] Mengarahkan otomatis ke Gatekeeper karena: $e');
        screenLanjut = AppRouter.getGatekeeper(); 
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => screenLanjut,
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [Fatal Alert] Gagal memindahkan layar splash screen: $e');
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, 
      child: Scaffold(
        backgroundColor: AppTheme.bgPage, 
        body: Stack(
          children: [
            // Efek glowing pendaran hijau di tengah layar
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _glowAnim.value,
                      child: Container(
                        width: 250, height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.hijauMuda.withOpacity(0.35),
                              AppTheme.hijauMuda.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ),
            ),
            
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Text('REKSATANI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 7)),
              ),
            ),
            
            // Konten Utama di Tengah Sempurna
            Positioned.fill(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(36),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              width: 140, height: 140, 
                              padding: const EdgeInsets.all(16), 
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7), 
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 50, color: AppTheme.hijauTua)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28), 
                        
                        const Text(
                          'ReksaTani',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sistem Rantai Pasok Finansial',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecond, letterSpacing: 0.5),
                        ),
                      ],
                    ),
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