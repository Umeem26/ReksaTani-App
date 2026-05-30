import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'manajer_beranda_screen.dart';
import 'manajer_analitik_screen.dart';
import 'manajer_peta_screen.dart';
import 'manajemen_komoditas_screen.dart';
import 'manajemen_pengepul_screen.dart';
import '../../../shared/widgets/app_theme.dart';

class ManajerShell extends StatefulWidget {
  const ManajerShell({super.key});

  @override
  State<ManajerShell> createState() => ManajerShellState();
}

class ManajerShellState extends State<ManajerShell> {
  int _index = 0;

  static ManajerShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<ManajerShellState>();

  void changeTab(int i) {
    HapticFeedback.selectionClick(); // Memberikan getaran haptic halus khas iOS
    setState(() => _index = i);
  }

  static const _screens = <Widget>[
    BerandaManajerScreen(),
    ManajerAnalitikScreen(),
    ManajerPetaScreen(),
    ManajemenKomoditasScreen(),
    ManajemenPengepulScreen(),
  ];

  static const _tabs = [
    _Tab(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Beranda'),
    _Tab(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analitik'),
    _Tab(icon: Icons.map_outlined,       activeIcon: Icons.map_rounded,       label: 'Peta'),
    _Tab(icon: Icons.category_outlined,  activeIcon: Icons.category_rounded,  label: 'Komoditas'),
    _Tab(icon: Icons.people_outline,     activeIcon: Icons.people_rounded,    label: 'Pengepul'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgPage,
        extendBody: true, // Wajib agar konten body bisa menembus di bawah navbar kaca
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: _LiquidGlassBottomNav(
          currentIndex: _index,
          tabs: _tabs,
          onTap: changeTab,
        ),
      );
}

// ─── INOVASI ULTIMATE: LIQUID GLASS DOCK (MANAJER VERSION) ───
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
          height: 70, // Tinggi standar dok kaca
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // ── 1. LAPISAN SHADOW (DIPISAH AGAR BAYANGAN RAPI) ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
                  ],
                ),
              ),

              // ── 2. LAPISAN KACA BURAM (LIQUID GLASS) ──
              ClipRRect(
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
  const _Tab({required this.icon, required this.activeIcon, required this.label});
}