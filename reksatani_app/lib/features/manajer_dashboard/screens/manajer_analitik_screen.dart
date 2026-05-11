import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/app_theme.dart';
import '../../../models/hive/transaksi_hive_model.dart';
import '../controllers/manajer_analitik_controller.dart';

/// ManajerAnalitikScreen – Dasbor analitik untuk Manajer Gudang.
/// Menampilkan ringkasan stok, breakdown per komoditas & grade,
/// progress sinkronisasi, dan 5 transaksi terbaru.
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: RefreshIndicator(
          color: AppTheme.hijauMuda,
          onRefresh: _ctrl.refresh,
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
                  'Analitik',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppTheme.textPrimary),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: _ctrl.syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.hijauMuda))
                        : const Icon(Icons.sync_rounded,
                            color: AppTheme.hijauMuda),
                    onPressed: _ctrl.syncing ? null : _ctrl.refresh,
                    tooltip: 'Refresh data',
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── 4 Stat Cards ─────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Stok',
                            value: '${_ctrl.totalStokKg.toStringAsFixed(0)} kg',
                            icon: Icons.inventory_2_outlined,
                            color: AppTheme.hijauMuda,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Nilai',
                            value: _fmtRupiah(_ctrl.totalNilai),
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Belum Sync',
                            value: '${_ctrl.jumlahPending} transaksi',
                            icon: Icons.cloud_off_outlined,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Sudah Sync',
                            value: '${_ctrl.jumlahSynced} transaksi',
                            icon: Icons.cloud_done_outlined,
                            color: AppTheme.hijauMuda,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Progress Sinkronisasi ─────────────────────
                    _SyncProgressCard(
                      persen: _ctrl.persenSynced,
                      synced: _ctrl.jumlahSynced,
                      total: _ctrl.semuaTransaksi.length,
                    ),
                    const SizedBox(height: 20),

                    // ── Stok per Komoditas ────────────────────────
                    const _SectionHeader(title: 'Stok per Komoditas'),
                    const SizedBox(height: 12),
                    if (_ctrl.stokPerKomoditas.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data komoditas.')
                    else
                      ..._ctrl.stokPerKomoditas
                          .map((d) => _KomoditasRow(data: d,
                              totalKg: _ctrl.totalStokKg)),
                    const SizedBox(height: 20),

                    // ── Breakdown Grade ───────────────────────────
                    const _SectionHeader(title: 'Breakdown Grade Kualitas'),
                    const SizedBox(height: 12),
                    if (_ctrl.stokPerGrade.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data grade.')
                    else
                      _GradeBreakdownCard(
                          grades: _ctrl.stokPerGrade,
                          totalKg: _ctrl.totalStokKg),
                    const SizedBox(height: 20),

                    // ── Sisa Kas Agen ─────────────────────────────
                    const _SectionHeader(title: 'Sisa Kas Agen'),
                    const SizedBox(height: 12),
                    _KasAgenCard(
                      username: _ctrl.user.username,
                      sisaKas: _ctrl.user.sisaUangJalan,
                    ),
                    const SizedBox(height: 20),

                    // ── Transaksi Terbaru ─────────────────────────
                    const _SectionHeader(title: 'Transaksi Terbaru'),
                    const SizedBox(height: 12),
                    if (_ctrl.transaksiTerbaru.isEmpty)
                      const _EmptyCard(msg: 'Belum ada transaksi.')
                    else
                      ..._ctrl.transaksiTerbaru
                          .map((t) => _TransaksiRow(trx: t)),
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

// ── Stat Card ────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecond)),
          ],
        ),
      );
}

// ── Sync Progress Card ───────────────────────────────────────────
class _SyncProgressCard extends StatelessWidget {
  final double persen;
  final int synced, total;

  const _SyncProgressCard({
    required this.persen,
    required this.synced,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync_outlined,
                    color: AppTheme.hijauMuda, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Progress Sinkronisasi',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimary)),
                ),
                Text(
                  '${(persen * 100).toInt()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.hijauMuda),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: persen,
                minHeight: 10,
                backgroundColor: AppTheme.hijauSoft,
                valueColor: const AlwaysStoppedAnimation(AppTheme.hijauMuda),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$synced dari $total transaksi telah tersinkronisasi ke server',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecond),
            ),
          ],
        ),
      );
}

// ── Komoditas Row ────────────────────────────────────────────────
class _KomoditasRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final double totalKg;

  const _KomoditasRow({required this.data, required this.totalKg});

  @override
  Widget build(BuildContext context) {
    final kg    = data['totalKg'] as double;
    final nilai = data['totalNilai'] as double;
    final persen = totalKg > 0 ? kg / totalKg : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 12),
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
                child: const Center(
                    child: Text('🌾', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(data['nama'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${kg.toInt()} kg',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.hijauTua)),
                  const SizedBox(height: 1),
                  Text(_fmtRupiah(nilai),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecond)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: persen,
                    minHeight: 6,
                    backgroundColor: AppTheme.hijauSoft,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.hijauMuda),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(persen * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecond)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Grade Breakdown Card ─────────────────────────────────────────
class _GradeBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> grades;
  final double totalKg;

  const _GradeBreakdownCard(
      {required this.grades, required this.totalKg});

  static const _gradeColor = {
    'A': Color(0xFF10B981),
    'B': Color(0xFFF59E0B),
    'C': Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 14),
        child: Column(
          children: grades.map((g) {
            final grade  = g['grade'] as String;
            final kg     = g['totalKg'] as double;
            final persen = totalKg > 0 ? kg / totalKg : 0.0;
            final color  = _gradeColor[grade] ?? AppTheme.hijauMuda;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: color.withOpacity(0.3)),
                        ),
                        child: Text('Grade $grade',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      const Spacer(),
                      Text('${kg.toInt()} kg',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textPrimary)),
                      const SizedBox(width: 6),
                      Text('(${(persen * 100).toInt()}%)',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecond)),
                    ],
                  ),
                  const SizedBox(height: 8),
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

// ── Kas Agen Card ────────────────────────────────────────────────
class _KasAgenCard extends StatelessWidget {
  final String username;
  final double sisaKas;

  const _KasAgenCard(
      {required this.username, required this.sisaKas});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.hijauSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('Pengepul Lapangan',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecond)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmtRupiah(sisaKas),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.hijauTua)),
                const SizedBox(height: 2),
                const Text('Sisa Uang Jalan',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecond)),
              ],
            ),
          ],
        ),
      );
}

// ── Transaksi Row ────────────────────────────────────────────────
class _TransaksiRow extends StatelessWidget {
  final TransaksiHiveModel trx;
  const _TransaksiRow({required this.trx});

  @override
  Widget build(BuildContext context) {
    final isPending = trx.statusSinkronisasi == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.hijauSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child: Text('🌾', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trx.namaKomoditas} · Grade ${trx.gradeTerpilih} · ${trx.berat.toInt()} kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(trx.namaPetani,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecond)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtRupiah(trx.totalBayar),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.hijauTua)),
              const SizedBox(height: 4),
              _StatusBadge(isPending: isPending),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isPending;
  const _StatusBadge({required this.isPending});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPending
              ? const Color(0xFFFEF3C7)
              : AppTheme.hijauSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPending
                    ? const Color(0xFFF59E0B)
                    : AppTheme.hijauMuda,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isPending ? 'Pending' : 'Synced',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isPending
                    ? const Color(0xFF92400E)
                    : AppTheme.hijauTua,
              ),
            ),
          ],
        ),
      );
}

// ── Section Header ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary));
}

// ── Empty Card ───────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(radius: 12),
        child: Center(
          child: Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecond,
                  height: 1.5)),
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