import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/app_theme.dart';
import '../controllers/manajer_analitik_controller.dart';
import '../../../../services/master_data_service.dart';

class ManajerAnalitikScreen extends StatefulWidget {
  const ManajerAnalitikScreen({super.key});

  @override
  State<ManajerAnalitikScreen> createState() => _ManajerAnalitikScreenState();
}

class _ManajerAnalitikScreenState extends State<ManajerAnalitikScreen> {
  late final ManajerAnalitikController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ManajerAnalitikController();
    
    // ── UI OTOMATIS RENDER ULANG SAAT DATA BACKGROUND BERUBAH ──
    MasterDataService().addListener(_onDataMasterChanged);
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onDataMasterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MasterDataService().removeListener(_onDataMasterChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalTransaksi = _ctrl.semuaTransaksi.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, 
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        // Dihilangkan RefreshIndicator
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text('Analitik Detail', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.textPrimary, letterSpacing: -0.5)),
              centerTitle: false,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SyncDetailCard(persen: _ctrl.persenSynced, synced: _ctrl.jumlahSynced, pending: _ctrl.jumlahPending, total: totalTransaksi),
                  const SizedBox(height: 36),
                  const _SectionHeaderModern(title: 'Stok per Komoditas', subtitle: 'Distribusi berat & nilai tiap jenis hasil tani', icon: Icons.inventory_2_rounded),
                  const SizedBox(height: 16),
                  if (_ctrl.stokPerKomoditas.isEmpty)
                    const _EmptyCard(msg: 'Belum ada data komoditas.')
                  else
                    ..._ctrl.stokPerKomoditas.map((d) => _KomoditasRow(data: d, totalKg: _ctrl.totalStokKg, totalNilai: _ctrl.totalNilai)),
                  const SizedBox(height: 36),
                  const _SectionHeaderModern(title: 'Breakdown Grade', subtitle: 'Proporsi kualitas komoditas masuk', icon: Icons.star_rounded, iconColor: Color(0xFFF59E0B)),
                  const SizedBox(height: 16),
                  if (_ctrl.stokPerGrade.isEmpty)
                    const _EmptyCard(msg: 'Belum ada data grade.')
                  else
                    _GradeBreakdownCard(grades: _ctrl.stokPerGrade, totalKg: _ctrl.totalStokKg),
                  const SizedBox(height: 36),
                  const _SectionHeaderModern(title: 'Distribusi Transaksi', subtitle: 'Jumlah transaksi per jenis komoditas', icon: Icons.pie_chart_rounded, iconColor: Color(0xFF3B82F6)),
                  const SizedBox(height: 16),
                  if (_ctrl.distribusiTransaksi.isEmpty)
                    const _EmptyCard(msg: 'Belum ada data transaksi.')
                  else
                    _DistribusiCard(data: _ctrl.distribusiTransaksi, total: totalTransaksi),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncDetailCard extends StatelessWidget {
  final double persen;
  final int synced, pending, total;
  const _SyncDetailCard({required this.persen, required this.synced, required this.pending, required this.total});
  @override
  Widget build(BuildContext context) {
    final bool isComplete = persen >= 1.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.border.withOpacity(0.5)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isComplete ? AppTheme.hijauSoft : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)), child: Icon(isComplete ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded, color: isComplete ? AppTheme.hijauTua : const Color(0xFFD97706), size: 20)),
                  const SizedBox(width: 12),
                  const Text('Sinkronisasi Server', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                ],
              ),
              Text('${(persen * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isComplete ? AppTheme.hijauTua : const Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(value: persen, minHeight: 12, backgroundColor: AppTheme.bgPage, valueColor: AlwaysStoppedAnimation(isComplete ? AppTheme.hijauMuda : const Color(0xFFF59E0B))),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _SyncChip(label: 'Tersinkron', count: synced, color: AppTheme.hijauTua, bgColor: AppTheme.hijauSoft, icon: Icons.cloud_done_rounded),
              const SizedBox(width: 12),
              _SyncChip(label: 'Tertunda', count: pending, color: const Color(0xFFB45309), bgColor: const Color(0xFFFEF3C7), icon: Icons.cloud_off_rounded),
              const SizedBox(width: 12),
              _SyncChip(label: 'Total Trx', count: total, color: const Color(0xFF1D4ED8), bgColor: const Color(0xFFDBEAFE), icon: Icons.receipt_long_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const _SyncChip({required this.label, required this.count, required this.color, required this.bgColor, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.8))),
            ],
          ),
        ),
      );
}

class _KomoditasRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final double totalKg;
  final double totalNilai;
  const _KomoditasRow({required this.data, required this.totalKg, required this.totalNilai});
  @override
  Widget build(BuildContext context) {
    final kg = data['totalKg'] as double;
    final nilai = data['totalNilai'] as double;
    final persenKg = totalKg > 0 ? kg / totalKg : 0.0;
    final persenNilai = totalNilai > 0 ? nilai / totalNilai : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border.withOpacity(0.5)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('🌾', style: TextStyle(fontSize: 22)))),
              const SizedBox(width: 14),
              Expanded(child: Text(data['nama'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary, letterSpacing: -0.3))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(20)), child: Text('${(persenKg * 100).toInt()}% dari total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecond))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _BarColumn(label: 'Volume (kg)', value: '${kg.toInt()} kg', persen: persenKg, color: AppTheme.hijauMuda)),
              const SizedBox(width: 20),
              Expanded(child: _BarColumn(label: 'Valuasi (Rp)', value: _fmtRupiah(nilai), persen: persenNilai, color: const Color(0xFF3B82F6))),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String label, value;
  final double persen;
  final Color color;
  const _BarColumn({required this.label, required this.value, required this.persen, required this.color});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: persen, minHeight: 8, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(color))),
        ],
      );
}

class _GradeBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> grades;
  final double totalKg;
  const _GradeBreakdownCard({required this.grades, required this.totalKg});
  static const _gradeColor = {'A': Color(0xFF10B981), 'B': Color(0xFFF59E0B), 'C': Color(0xFFEF4444)};
  static const _gradeDesc = {'A': 'Kualitas Premium', 'B': 'Kualitas Standar', 'C': 'Kualitas Rendah'};
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.border.withOpacity(0.5)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))]),
        child: Column(
          children: grades.map((g) {
            final grade = g['grade'] as String;
            final kg = g['totalKg'] as double;
            final persen = totalKg > 0 ? kg / totalKg : 0.0;
            final color = _gradeColor[grade] ?? AppTheme.hijauMuda;
            final desc = _gradeDesc[grade] ?? 'Tidak diketahui';
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Center(child: Text(grade, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Grade $grade', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                            Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${kg.toInt()} kg', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary)),
                          Text('${(persen * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: persen, minHeight: 10, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(color))),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

class _DistribusiCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final int total;
  const _DistribusiCard({required this.data, required this.total});
  static const _colors = [Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEF4444), Color(0xFF06B6D4)];
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.border.withOpacity(0.5)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))]),
        child: Column(
          children: data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final jumlah = d['jumlahTransaksi'] as int;
            final nama = d['nama'] as String;
            final persen = total > 0 ? jumlah / total : 0.0;
            final color = _colors[i % _colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                            Text('$jumlah trx', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                            const SizedBox(width: 6),
                            Text('(${persen > 0 ? (persen * 100).toStringAsFixed(1) : 0}%)', style: const TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: persen, minHeight: 8, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(color))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

class _SectionHeaderModern extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  const _SectionHeaderModern({required this.title, required this.subtitle, required this.icon, this.iconColor});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (iconColor ?? AppTheme.hijauMuda).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor ?? AppTheme.hijauTua, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard({required this.msg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inbox_rounded, size: 36, color: AppTheme.textHint),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.5)),
            ],
          ),
        ),
      );
}

String _fmtRupiah(double angka) {
  final s = angka.toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${buf.toString()}';
}