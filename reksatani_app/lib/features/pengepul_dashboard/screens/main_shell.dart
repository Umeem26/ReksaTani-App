import 'package:flutter/material.dart';
import 'beranda_screen.dart';
import 'pasar_screen.dart';
import 'riwayat_screen.dart';
import 'profil_screen.dart';
import '../../../../../shared/widgets/app_theme.dart';
import '../../pcd_scanner/screens/pcd_camera_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _index = 0;

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  void changeTab(int i) => setState(() => _index = i);

  static const _screens = <Widget>[
    BerandaScreen(),
    PasarScreen(),
    SizedBox.shrink(),
    RiwayatScreen(),
    ProfilScreen(),
  ];

  static const _tabs = [
    _Tab(icon: Icons.home_outlined,       activeIcon: Icons.home_rounded,       label: 'Beranda'),
    _Tab(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Pasar'),
    _Tab(icon: Icons.camera_alt_outlined, activeIcon: Icons.camera_alt_rounded, label: '', isCenter: true),
    _Tab(icon: Icons.history_outlined,    activeIcon: Icons.history_rounded,    label: 'Riwayat'),
    _Tab(icon: Icons.person_outline,      activeIcon: Icons.person_rounded,     label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgPage,
        extendBody: true,
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: _BottomNav(
          currentIndex: _index,
          tabs: _tabs,
          onTap: changeTab,
        ),
      );
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_Tab> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 20, offset: Offset(0, 4)),
            ],
          ),
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
                final tab    = tabs[i];
                final active = currentIndex == i;

                if (tab.isCenter) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PcdCameraScreen(),
                        ),
                      );
                    },
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: AppTheme.headerGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.hijauMuda.withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(tab.activeIcon, color: Colors.white, size: 24),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? tab.activeIcon : tab.icon,
                          color: active ? AppTheme.hijauMuda : const Color(0xFFAAAAAA),
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(tab.label, style: TextStyle(
                          fontSize: 10,
                          color: active ? AppTheme.hijauMuda : const Color(0xFFAAAAAA),
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}

class _Tab {
  final IconData icon, activeIcon;
  final String label;
  final bool isCenter;
  const _Tab({required this.icon, required this.activeIcon, required this.label, this.isCenter = false});
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppTheme.textHint),
              const SizedBox(height: 12),
              Text('Halaman $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
              const SizedBox(height: 6),
              const Text('Coming soon...', style: TextStyle(fontSize: 13, color: AppTheme.textSecond)),
            ],
          ),
        ),
      );
}