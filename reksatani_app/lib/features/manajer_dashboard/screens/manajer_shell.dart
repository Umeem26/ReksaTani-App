import 'package:flutter/material.dart';
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

  void changeTab(int i) => setState(() => _index = i);

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
                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 70,
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
  const _Tab({required this.icon, required this.activeIcon, required this.label});
}