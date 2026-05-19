import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/app_theme.dart';
import '../../../models/hive/transaksi_hive_model.dart';
import '../../../models/hive/user_hive_model.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/routing/app_router.dart';
import '../controllers/manajer_beranda_controller.dart';
import 'manajer_shell.dart';
import '../../../../services/notification_service.dart';
import '../../pengepul_dashboard/screens/notifikasi_screen.dart';
import 'package:provider/provider.dart';

class BerandaManajerScreen extends StatefulWidget {
  const BerandaManajerScreen({super.key});

  @override
  State<BerandaManajerScreen> createState() => _BerandaManajerScreenState();
}

class _BerandaManajerScreenState extends State<BerandaManajerScreen> {
  late final ManajerBerandaController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ManajerBerandaController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Aplikasi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('Kamu yakin ingin logout?',
            style: TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(color: AppTheme.textSecond)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.merah,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (konfirmasi == true && mounted) {
      await AuthController().logout();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaksiTampil = _ctrl.semuaTransaksi.take(5).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: RefreshIndicator(
          color: AppTheme.hijauMuda,
          onRefresh: _ctrl.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ManajerHeader(
                  user: _ctrl.user,
                  syncing: _ctrl.syncing,
                  onSync: _ctrl.refresh,
                  onLogout: _logout,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Stok Masuk',
                            value: '${_ctrl.totalStokKg.toStringAsFixed(0)} kg',
                            icon: Icons.inventory_2_outlined,
                            color: AppTheme.hijauMuda,
                            onTap: () => ManajerShellState.of(context)?.changeTab(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Nilai',
                            value: _fmtRupiah(_ctrl.totalNilai),
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF3B82F6),
                            onTap: () => ManajerShellState.of(context)?.changeTab(1),
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
                            onTap: () => ManajerShellState.of(context)?.changeTab(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Sudah Sync',
                            value: '${_ctrl.jumlahSynced} transaksi',
                            icon: Icons.cloud_done_outlined,
                            color: AppTheme.hijauMuda,
                            onTap: () => ManajerShellState.of(context)?.changeTab(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader(
                      title: 'Harga & Komoditas',
                      trailing: GestureDetector(
                        onTap: () => ManajerShellState.of(context)?.changeTab(3),
                        child: const Text('Lihat Semua',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.hijauTua)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_ctrl.daftarKomoditas.isEmpty)
                      const _EmptyCard(msg: 'Belum ada komoditas terdaftar.')
                    else
                      ..._ctrl.daftarKomoditas.take(3).map((k) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
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
                                    child: Icon(Icons.category_rounded, color: AppTheme.hijauTua, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(k.namaKomoditas,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text('${k.gradeKualitas.length} Grade Kualitas',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                                    ],
                                  ),
                                ),
                                if (k.gradeKualitas.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Mulai dari', style: TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                                      const SizedBox(height: 3),
                                      Text(
                                        _fmtRupiah((k.gradeKualitas.last['harga_maks'] as num).toDouble()),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 24),

                    _SectionHeader(
                      title: 'Aktivitas & Kas Agen',
                      trailing: GestureDetector(
                        onTap: () => ManajerShellState.of(context)?.changeTab(4),
                        child: const Text('Lihat Semua',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.hijauTua)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_ctrl.daftarAgen.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data agen terdaftar.')
                    else
                      ..._ctrl.daftarAgen.map((agen) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _KasAgenCard(
                              user: agen,
                              history: _ctrl.getTransaksiAgen(agen.id),
                              lastSync: _ctrl.getWaktuSyncTerakhir(agen.id),
                            ),
                          )),
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

class _ManajerHeader extends StatelessWidget {
  final UserHiveModel user;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  const _ManajerHeader({
    required this.user,
    required this.syncing,
    required this.onSync,
    required this.onLogout,
  });

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
                      'Halo, ${user.username} 👋',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Manajer Gudang',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              _IkonBtn(icon: Icons.sync_rounded, spinning: syncing, onTap: onSync),
              const SizedBox(width: 8),
              ChangeNotifierProvider.value(
                value: NotificationService(),
                child: Consumer<NotificationService>(
                  builder: (context, svc, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _IkonBtn(
                        icon: Icons.notifications_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotifikasiScreen()),
                        ),
                      ),
                      if (svc.unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.merah,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${svc.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IkonBtn(icon: Icons.logout_rounded, onTap: onLogout),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.dashboard_outlined, color: Colors.white70, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dasbor Manajer — pantau stok & agen lapangan',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
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

class _KasAgenCard extends StatefulWidget {
  final UserHiveModel user;
  final List<TransaksiHiveModel> history;
  final DateTime? lastSync;
  const _KasAgenCard(
      {required this.user, required this.history, this.lastSync});

  @override
  State<_KasAgenCard> createState() => _KasAgenCardState();
}

class _KasAgenCardState extends State<_KasAgenCard> {
  bool _isExpanded = false;

  bool get _isOnline {
    if (widget.lastSync == null) return false;
    final diff = DateTime.now().difference(widget.lastSync!);
    return diff.inMinutes.abs() < 60;
  }

  String get _timeAgo {
    if (widget.lastSync == null) return 'Belum ada aktivitas';
    final diff = DateTime.now().difference(widget.lastSync!);
    
    if (diff.inSeconds.abs() < 60) return 'Baru saja';
    if (diff.inMinutes.abs() < 60) return '${diff.inMinutes.abs()}m lalu';
    if (diff.inHours.abs() < 24) return '${diff.inHours.abs()}j lalu';
    if (diff.inDays.abs() < 7) return '${diff.inDays.abs()} hari lalu';
    
    return '${widget.lastSync!.day}/${widget.lastSync!.month}/${widget.lastSync!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header (Klik untuk Expand) ──
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        Text(widget.user.username,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'Online' : _timeAgo,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _isOnline
                                      ? Colors.green.shade700
                                      : AppTheme.textSecond),
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
                        _fmtRupiah(widget.user.sisaUangJalan),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.hijauTua),
                      ),
                      const SizedBox(height: 2),
                      const Text('Sisa Uang Jalan',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecond)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecond,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Konten Expand (Riwayat 5 Transaksi) ──
          if (_isExpanded) ...[
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppTheme.border),
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.bgPage.withOpacity(0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 14, color: AppTheme.textSecond),
                      const SizedBox(width: 6),
                      Text('5 Transaksi Terakhir ${widget.user.username}:',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecond)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Belum ada transaksi dari agen ini.',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecond)),
                    )
                  else
                    ...widget.history.map((t) => _SmallTrxRow(trx: t)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallTrxRow extends StatelessWidget {
  final TransaksiHiveModel trx;
  const _SmallTrxRow({required this.trx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trx.namaKomoditas} · ${trx.berat.toInt()} kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  '${trx.namaPetani} · ${_fmtDate(trx.createdAt)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecond),
                ),
              ],
            ),
          ),
          Text(
            _fmtRupiah(trx.totalBayar),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppTheme.hijauTua),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    if (trailing != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          trailing!,
        ],
      );
    }
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary));
  }
}

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
                  fontSize: 13, color: AppTheme.textSecond, height: 1.5)),
        ),
      );
}

class _IkonBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool spinning;

  const _IkonBtn(
      {required this.icon, required this.onTap, this.spinning = false});

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

String _fmtRupiah(double angka) {
  final s = angka.toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${buf.toString()}';
}