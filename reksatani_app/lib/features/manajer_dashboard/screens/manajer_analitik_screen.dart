import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/app_theme.dart';
import '../controllers/manajer_analitik_controller.dart';

/// ManajerAnalitikScreen – Dasbor analitik detail untuk Manajer Gudang.
/// Menampilkan breakdown komoditas, grade, analisis nilai, dan distribusi transaksi.
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
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSync() async {
    if (_ctrl.syncing) return;
    await _ctrl.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Data berhasil disinkronisasi',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppTheme.hijauTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTransaksi = _ctrl.semuaTransaksi.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: RefreshIndicator(
          color: AppTheme.hijauMuda,
          onRefresh: _onSync,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App Bar ────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.bgCard,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: const Text(
                  'Analitik Detail',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppTheme.textPrimary),
                ),
                centerTitle: false,
                actions: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _ctrl.syncing
                        ? const Padding(
                            key: ValueKey('loading'),
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.hijauMuda),
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('sync'),
                            icon: const Icon(Icons.sync_rounded,
                                color: AppTheme.hijauMuda),
                            onPressed: _onSync,
                            tooltip: 'Sinkronisasi data',
                          ),
                  ),
                  const SizedBox(width: 4),
                ],
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: AppTheme.border),
                ),
              ),

              // ── Body ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── Progress Sinkronisasi (dari overview beranda) ──
                    _SyncDetailCard(
                      persen: _ctrl.persenSynced,
                      synced: _ctrl.jumlahSynced,
                      pending: _ctrl.jumlahPending,
                      total: totalTransaksi,
                    ),
                    const SizedBox(height: 20),



                    // ── Stok per Komoditas ─────────────────────────
                    _SectionHeader(
                      title: 'Stok per Komoditas',
                      subtitle: 'Distribusi berat & nilai tiap jenis hasil tani',
                    ),
                    const SizedBox(height: 12),
                    if (_ctrl.stokPerKomoditas.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data komoditas.')
                    else
                      ..._ctrl.stokPerKomoditas.map((d) => _KomoditasRow(
                          data: d, totalKg: _ctrl.totalStokKg,
                          totalNilai: _ctrl.totalNilai)),
                    const SizedBox(height: 20),

                    // ── Breakdown Grade Kualitas ───────────────────
                    _SectionHeader(
                      title: 'Breakdown Grade Kualitas',
                      subtitle: 'Proporsi kualitas komoditas yang masuk',
                    ),
                    const SizedBox(height: 12),
                    if (_ctrl.stokPerGrade.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data grade.')
                    else
                      _GradeBreakdownCard(
                          grades: _ctrl.stokPerGrade,
                          totalKg: _ctrl.totalStokKg),
                    const SizedBox(height: 20),

                    // ── Distribusi Transaksi per Komoditas ─────────
                    _SectionHeader(
                      title: 'Distribusi Transaksi',
                      subtitle: 'Jumlah transaksi per jenis komoditas',
                    ),
                    const SizedBox(height: 12),
                    if (_ctrl.distribusiTransaksi.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data transaksi.')
                    else
                      _DistribusiCard(
                        data: _ctrl.distribusiTransaksi,
                        total: totalTransaksi,
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sync Detail Card ─────────────────────────────────────────────
class _SyncDetailCard extends StatelessWidget {
  final double persen;
  final int synced, pending, total;

  const _SyncDetailCard({
    required this.persen,
    required this.synced,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.hijauMuda.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_sync_outlined,
                      color: AppTheme.hijauMuda, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status Sinkronisasi',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Progres upload data ke server',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecond)),
                    ],
                  ),
                ),
                Text(
                  '${(persen * 100).toInt()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppTheme.hijauMuda),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: persen,
                minHeight: 10,
                backgroundColor: AppTheme.hijauSoft,
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.hijauMuda),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _SyncChip(
                  label: 'Synced',
                  count: synced,
                  color: AppTheme.hijauMuda,
                  icon: Icons.cloud_done_outlined,
                ),
                const SizedBox(width: 8),
                _SyncChip(
                  label: 'Pending',
                  count: pending,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.cloud_off_outlined,
                ),
                const SizedBox(width: 8),
                _SyncChip(
                  label: 'Total',
                  count: total,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ),
          ],
        ),
      );
}

class _SyncChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SyncChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 4),
              Text('$count',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecond)),
            ],
          ),
        ),
      );
}



// ── Komoditas Row ────────────────────────────────────────────────
class _KomoditasRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final double totalKg;
  final double totalNilai;

  const _KomoditasRow(
      {required this.data, required this.totalKg, required this.totalNilai});

  @override
  Widget build(BuildContext context) {
    final kg = data['totalKg'] as double;
    final nilai = data['totalNilai'] as double;
    final persenKg = totalKg > 0 ? kg / totalKg : 0.0;
    final persenNilai = totalNilai > 0 ? nilai / totalNilai : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.hijauSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Center(child: Text('🌾', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(data['nama'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: AppTheme.textPrimary)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${kg.toInt()} kg',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.hijauTua)),
                  Text(_fmtRupiah(nilai),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecond)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Volume bar
          _BarRow(
            label: 'Volume',
            persen: persenKg,
            color: AppTheme.hijauMuda,
            suffix: '${(persenKg * 100).toInt()}%',
          ),
          const SizedBox(height: 6),
          // Nilai bar
          _BarRow(
            label: 'Nilai',
            persen: persenNilai,
            color: const Color(0xFF3B82F6),
            suffix: '${(persenNilai * 100).toInt()}%',
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label, suffix;
  final double persen;
  final Color color;

  const _BarRow({
    required this.label,
    required this.persen,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecond)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: persen,
                minHeight: 7,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(suffix,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );
}

// ── Grade Breakdown Card ─────────────────────────────────────────
class _GradeBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> grades;
  final double totalKg;

  const _GradeBreakdownCard({required this.grades, required this.totalKg});

  static const _gradeColor = {
    'A': Color(0xFF10B981),
    'B': Color(0xFFF59E0B),
    'C': Color(0xFFEF4444),
  };

  static const _gradeDesc = {
    'A': 'Kualitas Premium',
    'B': 'Kualitas Standar',
    'C': 'Kualitas Rendah',
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 14),
        child: Column(
          children: grades.map((g) {
            final grade = g['grade'] as String;
            final kg = g['totalKg'] as double;
            final persen = totalKg > 0 ? kg / totalKg : 0.0;
            final color = _gradeColor[grade] ?? AppTheme.hijauMuda;
            final desc = _gradeDesc[grade] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(grade,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Grade $grade',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                            Text(desc,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecond)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${kg.toInt()} kg',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary)),
                          Text('${(persen * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: persen,
                      minHeight: 8,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

// ── Distribusi Transaksi Card ─────────────────────────────────────
class _DistribusiCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final int total;

  const _DistribusiCard({required this.data, required this.total});

  static const _colors = [
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 14),
        child: Column(
          children: data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final jumlah = d['jumlahTransaksi'] as int;
            final nama = d['nama'] as String;
            final persen = total > 0 ? jumlah / total : 0.0;
            final color = _colors[i % _colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(nama,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                            ),
                            Text('$jumlah trx',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                            const SizedBox(width: 6),
                            Text('(${(persen * 100).toInt()}%)',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecond)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: persen,
                            minHeight: 6,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
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

// ── Section Header ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecond)),
          ],
        ],
      );
}

// ── Empty Card ───────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(radius: 12),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 32, color: AppTheme.textSecond),
              const SizedBox(height: 8),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecond,
                      height: 1.5)),
            ],
          ),
        ),
      );
}

// ── Format helper ────────────────────────────────────────────────
String _fmtRupiah(double angka) {
  final s = angka.toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${buf.toString()}';
}