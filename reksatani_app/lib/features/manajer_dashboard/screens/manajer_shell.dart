import 'package:flutter/material.dart';
import 'manajer_beranda_screen.dart';
import 'manajer_peta_screen.dart';
import '../../../shared/widgets/app_theme.dart';

/// ManajerShell – Shell navigasi bottom nav untuk Manajer Gudang.
/// Saat ini hanya tab Beranda yang aktif. Tab lain coming soon.
class ManajerShell extends StatefulWidget {
  const ManajerShell({super.key});

  @override
  State<ManajerShell> createState() => ManajerShellState();
}

class ManajerShellState extends State<ManajerShell> {
  int _index = 0;

  static ManajerShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<ManajerShellState>();

  void changeTab(int i) => setState(() => _index = i);

  static const _screens = <Widget>[
    BerandaManajerScreen(),
    _PlaceholderScreen(label: 'Master Data', icon: Icons.tune_outlined),
    ManajerPetaScreen(), // <--- UBAH BARIS INI (Hapus _PlaceholderScreen Peta)
  ];

  static const _tabs = [
    _Tab(icon: Icons.dashboard_outlined,  activeIcon: Icons.dashboard_rounded,   label: 'Beranda'),
    _Tab(icon: Icons.tune_outlined,       activeIcon: Icons.tune_rounded,         label: 'Master Data'),
    _Tab(icon: Icons.map_outlined,        activeIcon: Icons.map_rounded,          label: 'Peta'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: _BottomNav(
          currentIndex: _index,
          tabs: _tabs,
          onTap: changeTab,
        ),
      );
}

// ── Bottom Nav ───────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_Tab> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav(
      {required this.currentIndex,
      required this.tabs,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(tabs.length, (i) {
                final tab    = tabs[i];
                final active = currentIndex == i;

                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? tab.activeIcon : tab.icon,
                          color: active
                              ? AppTheme.hijauMuda
                              : const Color(0xFFAAAAAA),
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: active
                                ? AppTheme.hijauMuda
                                : const Color(0xFFAAAAAA),
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
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
  const _Tab(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

// ── Placeholder ──────────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderScreen(
      {required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppTheme.textHint),
              const SizedBox(height: 12),
              Text('Halaman $label',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecond)),
              const SizedBox(height: 6),
              const Text('Coming soon...',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecond)),
            ],
          ),
        ),
      );
}