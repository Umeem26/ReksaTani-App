import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../models/hive/user_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../services/hive_service.dart';
import '../../../../../services/master_data_service.dart';
import '../../../../../shared/widgets/app_theme.dart';
import 'main_shell.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final _svc  = MasterDataService();
  final _hive = HiveService();
  bool _syncing = false;

  UserHiveModel get _user => _hive.usersBox.get('currentUser')!;

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    await _svc.syncAll();
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final harga   = _svc.getDaftarHargaDisplay().take(3).toList();
    final riwayat = _svc.getRiwayatTransaksi().take(3).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: RefreshIndicator(
          color: AppTheme.hijauMuda,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(
                  user: _user,
                  syncing: _syncing,
                  onSync: _refresh,
                ),
              ),

              // ── Body ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Stat cards
                    _StatRow(
                      jumlahTransaksi: _hive.transaksiBox.length,
                      totalBerat: _svc.totalBeratHariIni,
                      pending: _svc.jumlahPending,
                    ),
                    const SizedBox(height: 24),

                    // Harga pasar preview
                    _SectionHeader(
                      title: 'Harga Pasar Terkini',
                      actionLabel: 'Lihat Semua',
                      onAction: () =>
                          MainShellState.of(context)?.changeTab(1),
                    ),
                    const SizedBox(height: 12),
                    if (harga.isEmpty)
                      _EmptyCard(
                          msg:
                              'Belum ada data harga.\nTarik ke bawah untuk sync dari server.')
                    else
                      ...harga.map((h) => _HargaRow(data: h)),
                    const SizedBox(height: 24),

                    // Riwayat transaksi preview
                    _SectionHeader(
                      title: 'Transaksi Terakhir',
                      actionLabel: 'Lihat Semua',
                      onAction: () =>
                          MainShellState.of(context)?.changeTab(3),
                    ),
                    const SizedBox(height: 12),
                    if (riwayat.isEmpty)
                      _EmptyCard(
                          msg:
                              'Belum ada transaksi.\nTekan tombol kamera untuk mulai.')
                    else
                      ...riwayat.map((t) => _TransaksiRow(trx: t)),
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

// ── Header bergradien ────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserHiveModel user;
  final bool syncing;
  final VoidCallback onSync;

  const _Header(
      {required this.user,
      required this.syncing,
      required this.onSync});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: avatar + salam + ikon aksi
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF59E0B),
                child: Text(
                  user.username.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF019241),
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Siang, ${user.username} 👋',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      user.role,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              _IkonBtn(
                icon: Icons.sync_rounded,
                spinning: syncing,
                onTap: onSync,
              ),
              const SizedBox(width: 8),
              _IkonBtn(
                icon: Icons.notifications_outlined,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Saldo card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white54,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Saldo Uang Jalan',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        _fmtRupiah(user.sisaUangJalan),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.add,
                          size: 14, color: Color(0xFF019241)),
                      SizedBox(width: 4),
                      Text('Top-up',
                          style: TextStyle(
                              color: Color(0xFF019241),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IkonBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool spinning;

  const _IkonBtn(
      {required this.icon,
      required this.onTap,
      this.spinning = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: spinning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

// ── Stat Row ─────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final int jumlahTransaksi, pending;
  final double totalBerat;

  const _StatRow(
      {required this.jumlahTransaksi,
      required this.totalBerat,
      required this.pending});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StatCard(
            label: 'Transaksi',
            value: '$jumlahTransaksi',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Berat Hari Ini',
            value: '${totalBerat.toStringAsFixed(0)} kg',
            icon: Icons.scale_outlined,
            color: AppTheme.hijauMuda,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Pending Sync',
            value: '$pending',
            icon: Icons.cloud_upload_outlined,
            color: const Color(0xFFF59E0B),
          ),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecond)),
            ],
          ),
        ),
      );
}

// ── Section Header ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader(
      {required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.hijauMuda)),
            ),
        ],
      );
}

// ── Harga Row ────────────────────────────────────────────────────
class _HargaRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HargaRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final grade    = data['grade'] as String;
    final harga    = data['hargaMaks'] as double;
    final satuan   = data['unitSatuan'] as String;
    final komoditas= data['namaKomoditas'] as String;

    final gradeColor = switch (grade) {
      'A' => AppTheme.hijauMuda,
      'B' => const Color(0xFFF59E0B),
      _   => const Color(0xFFEF4444),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          // Ikon komoditas
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppTheme.hijauSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child: Text('🌾', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(komoditas,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                // Grade badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: gradeColor.withOpacity(0.3)),
                  ),
                  child: Text('Grade $grade',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: gradeColor)),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${_fmtRibu(harga.toInt())}/$satuan',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
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
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppTheme.hijauSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child: Text('🌾', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trx.namaKomoditas} · ${trx.berat.toInt()} kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  trx.namaPetani,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecond),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtRupiah(trx.totalBayar),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.hijauTua),
              ),
              const SizedBox(height: 4),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
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
                      width: 5, height: 5,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty card ───────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
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

// ── Format helpers ───────────────────────────────────────────────
String _fmtRupiah(double angka) {
  final s = angka.toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${buf.toString()}';
}

String _fmtRibu(int angka) {
  final s = angka.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}