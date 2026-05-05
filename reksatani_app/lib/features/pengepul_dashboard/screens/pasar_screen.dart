import 'package:flutter/material.dart';
import '../../../services/hive_service.dart';
import '../../../models/hive/komoditas_hive_model.dart';
import '../../../shared/widgets/app_theme.dart';

class PasarScreen extends StatefulWidget {
  const PasarScreen({super.key});

  @override
  State<PasarScreen> createState() => _PasarScreenState();
}

class _PasarScreenState extends State<PasarScreen> {
  final _hive = HiveService();
  String _filterGrade = 'Semua';

  /// Flatten semua komoditas + grade jadi list flat untuk ditampilkan
  List<_HargaItem> get _daftarHarga {
    final result = <_HargaItem>[];
    for (final k in _hive.komoditasBox.values) {
      for (final g in k.gradeKualitas) {
        final grade    = g['grade'] as String? ?? '';
        final hargaMaks = (g['harga_maks'] as num?)?.toDouble() ?? 0;
        if (_filterGrade == 'Semua' || _filterGrade == grade) {
          result.add(_HargaItem(
            namaKomoditas: k.namaKomoditas,
            unitSatuan: k.unitSatuan,
            grade: grade,
            hargaMaks: hargaMaks,
          ));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final list = _daftarHarga;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterChips(),
          _buildMeta(list.length),
          Expanded(
            child: list.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _HargaCard(item: list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Harga Pasar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.trending_up_rounded,
                color: AppTheme.hijauMuda, size: 22),
          ),
        ],
      );

  Widget _buildFilterChips() => Container(
        color: AppTheme.bgCard,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: ['Semua', 'A', 'B', 'C'].map((g) => _GradeChip(
            label: g == 'Semua' ? 'Semua' : 'Grade $g',
            isActive: _filterGrade == g,
            onTap: () => setState(() => _filterGrade = g),
          )).toList(),
        ),
      );

  Widget _buildMeta(int jumlah) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Text('$jumlah komoditas',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecond)),
            const Spacer(),
            const Icon(Icons.access_time_rounded,
                size: 13, color: AppTheme.textSecond),
            const SizedBox(width: 4),
            const Text('Data dari server',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecond)),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined,
                size: 56, color: AppTheme.textHint),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data harga.',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecond),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tarik beranda ke bawah untuk sync dari server.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecond),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Data class ringan untuk display ──────────────────────────────
class _HargaItem {
  final String namaKomoditas;
  final String unitSatuan;
  final String grade;
  final double hargaMaks;

  const _HargaItem({
    required this.namaKomoditas,
    required this.unitSatuan,
    required this.grade,
    required this.hargaMaks,
  });
}

// ── Grade chip filter ─────────────────────────────────────────────
class _GradeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GradeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.hijauMuda : AppTheme.bgPage,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppTheme.hijauMuda : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppTheme.textSecond,
            ),
          ),
        ),
      );
}

// ── Kartu satu harga komoditas ────────────────────────────────────
class _HargaCard extends StatelessWidget {
  final _HargaItem item;
  const _HargaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final gradeColor = switch (item.grade) {
      'A' => AppTheme.hijauMuda,
      'B' => AppTheme.kuning,
      _   => AppTheme.merah,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          // Ikon komoditas
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppTheme.hijauSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🌾', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),

          // Nama + grade badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.namaKomoditas,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: gradeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Grade ${item.grade}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: gradeColor),
                  ),
                ),
              ],
            ),
          ),

          // Harga maks + satuan
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp ${_fmt(item.hargaMaks.toInt())}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                '/${item.unitSatuan}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecond),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.hijauSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Harga Maks',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.hijauTua),
                ),
              ),
            ],
          ),
        ],
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