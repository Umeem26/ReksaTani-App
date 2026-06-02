import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/pasar_controller.dart';
import '../../../shared/widgets/app_theme.dart';
import 'tren_harga_screen.dart';

class PasarScreen extends StatefulWidget {
  const PasarScreen({super.key});

  @override
  State<PasarScreen> createState() => _PasarScreenState();
}

class _PasarScreenState extends State<PasarScreen> {
  final _controller = PasarController();

  List<dynamic> _getDaftarHarga() {
    final c = _controller as dynamic;
    try { return c.daftarHarga as List<dynamic>? ?? []; } catch (_) {}
    try { return c.daftarKomoditas as List<dynamic>? ?? []; } catch (_) {}
    return [];
  }

  String _getFilter() {
    final c = _controller as dynamic;
    try { return c.filterGrade as String; } catch (_) {}
    try { return c.selectedFilter as String; } catch (_) {}
    return 'Semua';
  }

  void _setFilter(String f) {
    final c = _controller as dynamic;
    try { c.filterGrade = f; } catch (_) {}
    try { c.setFilter(f); } catch (_) {}
    try { c.ubahFilter(f); } catch (_) {}
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _getDaftarHarga();
    final filterAktif = _getFilter();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              pinned: true,
              expandedHeight: 120,
              // ── FIX: TOMBOL TREN HARGA DIBUAT KONTRAST TINGGI ──
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrenHargaScreen())),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.hijauTua, // Hijau Solid agar stand out
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.show_chart_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Tren Harga', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                title: const Text('Harga Pasar Terkini', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5, color: AppTheme.textPrimary)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.white),
                    Positioned(
                      right: -30, top: -20,
                      child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.hijauSoft.withOpacity(0.5))),
                    ),
                  ],
                ),
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeaderDelegate(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildFilterChips(filterAktif),
                      const SizedBox(height: 16),
                      Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.analytics_outlined, color: AppTheme.hijauTua, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Menampilkan ${list.length} komoditas aktif',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            list.isEmpty
                ? SliverFillRemaining(child: _buildEmpty())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _HargaCard(item: list[index]),
                        childCount: list.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(String filterAktif) {
    final filters = ['Semua', 'A', 'B', 'C'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((f) {
          final isSelected = filterAktif == f;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _setFilter(f),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCirc,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.hijauTua : AppTheme.bgPage,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isSelected ? AppTheme.hijauTua : AppTheme.border, width: 1.5),
                  boxShadow: isSelected ? [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))] : null,
                ),
                child: Text(
                  f == 'Semua' ? 'Semua Grade' : 'Grade $f',
                  style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecond, fontSize: 13),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
          child: const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textHint),
        ),
        const SizedBox(height: 20),
        const Text('Tidak ada komoditas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        const Text('Coba pilih grade kualitas yang lain.', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterHeaderDelegate({required this.child});
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  double get maxExtent => 80.0;
  @override
  double get minExtent => 80.0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _HargaCard extends StatelessWidget {
  final dynamic item;
  const _HargaCard({required this.item});

  String get nama => _val<String>(item, 'namaKomoditas') ?? 'Komoditas';
  String get grade => _val<String>(item, 'grade') ?? '-';
  String get satuan => _val<String>(item, 'unitSatuan') ?? 'kg';
  double get hargaMaks => _num(item, 'hargaMaks') ?? _num(item, 'harga') ?? 0.0;

  T? _val<T>(dynamic obj, String key) {
    try { return obj.toJson()[key] as T?; } catch(_) {}
    try { return obj[key] as T?; } catch(_) {}
    try {
      if (key == 'namaKomoditas') return obj.namaKomoditas as T?;
      if (key == 'grade') return obj.grade as T?;
      if (key == 'unitSatuan') return obj.unitSatuan as T?;
    } catch (_) {}
    return null;
  }
  double? _num(dynamic obj, String key) {
    try { return (obj.toJson()[key] as num).toDouble(); } catch(_) {}
    try { return (obj[key] as num).toDouble(); } catch(_) {}
    try {
      if (key == 'hargaMaks') return (obj.hargaMaks as num).toDouble();
      if (key == 'harga') return (obj.harga as num).toDouble();
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = switch (grade) { 'A' => AppTheme.hijauMuda, 'B' => const Color(0xFFF59E0B), _ => AppTheme.merah };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrenHargaScreen())),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('🌾', style: TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nama, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary, letterSpacing: -0.3)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: gradeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, color: gradeColor, size: 12),
                                const SizedBox(width: 4),
                                Text('Grade $grade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: gradeColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${_fmt(hargaMaks.toInt())}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.hijauTua, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '/ $satuan',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}