import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'beranda_screen.dart';
import 'pasar_screen.dart';
import 'riwayat_screen.dart';
import 'profil_screen.dart';
import '../../../../../shared/widgets/app_theme.dart';
import '../../pcd_scanner/screens/pcd_camera_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key}); // INI CONSTRUCTOR YANG MEMPERBAIKI ERROR ROUTER-MU

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _index = 0;

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  void changeTab(int i) {
    HapticFeedback.selectionClick(); // Memberikan getaran haptic halus khas iOS
    setState(() => _index = i);
  }

  static const _screens = <Widget>[
    BerandaScreen(),
    PasarScreen(),
    SizedBox.shrink(), // Placeholder untuk tombol tengah
    RiwayatScreen(),
    ProfilScreen(),
  ];

  static const _tabs = [
    _Tab(icon: Icons.home_outlined,       activeIcon: Icons.home_rounded,       label: 'Beranda'),
    _Tab(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Pasar'),
    _Tab(icon: Icons.document_scanner_outlined, activeIcon: Icons.document_scanner_rounded, label: '', isCenter: true),
    _Tab(icon: Icons.history_outlined,    activeIcon: Icons.history_rounded,    label: 'Riwayat'),
    _Tab(icon: Icons.person_outline,      activeIcon: Icons.person_rounded,     label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgPage,
        extendBody: true, // WAJIB ADA agar body bisa tembus ke bawah navbar kaca
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: _LiquidGlassBottomNav(
          currentIndex: _index,
          tabs: _tabs,
          onTap: changeTab,
        ),
      );
}

// ─── INOVASI ULTIMATE: LIQUID GLASS DOCK & GOPAY BUTTON ───
class _LiquidGlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_Tab> tabs;
  final ValueChanged<int> onTap;

  const _LiquidGlassBottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          height: 85, // Tinggi total untuk mengakomodasi tombol GoPay yang menonjol
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none, // Membiarkan tombol kamera meluap keluar batas Stack
            children: [
              // ── 1. LAPISAN KACA BURAM (LIQUID GLASS) ──
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: 70, // Tinggi dasar Dock Kaca
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Blur optimal agar background tembus
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35), // Transparansi tinggi agar efek 'Liquid' terlihat jelas!
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5), // Efek bingkai kaca
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(tabs.length, (i) {
                            final tab = tabs[i];
                            final active = currentIndex == i;

                            // Jika ini posisi tengah, biarkan kosong (diisi oleh Stack di atasnya)
                            if (tab.isCenter) {
                              return const SizedBox(width: 60); 
                            }

                            // Menu Tab Normal
                            return GestureDetector(
                              onTap: () => onTap(i),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 60,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  transform: Matrix4.translationValues(0, active ? -2 : 0, 0), // Lompatan halus
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                        child: Icon(
                                          active ? tab.activeIcon : tab.icon,
                                          key: ValueKey<bool>(active),
                                          color: active ? AppTheme.hijauTua : AppTheme.textSecond.withOpacity(0.8),
                                          size: active ? 26 : 24,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 300),
                                        style: TextStyle(
                                          fontSize: active ? 11 : 10,
                                          color: active ? AppTheme.hijauTua : AppTheme.textSecond.withOpacity(0.8),
                                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                        child: Text(tab.label),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. TOMBOL KAMERA GOPAY-STYLE (POP-OUT BEBAS TERPOTONG) ──
              Positioned(
                top: 0, // Akan melompat keluar 15 pixel di atas dock (karena height stack 85, dock 70)
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PcdCameraScreen()));
                  },
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: AppTheme.headerGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4), // Border putih tebal (GoPay signature)
                      boxShadow: [
                        BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Icon(tabs[2].activeIcon, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon, activeIcon;
  final String label;
  final bool isCenter;
  const _Tab({required this.icon, required this.activeIcon, required this.label, this.isCenter = false});
}