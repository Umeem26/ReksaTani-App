import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../models/hive/user_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../shared/widgets/app_theme.dart';
import '../../../../../core/routing/app_router.dart';
import '../controllers/beranda_controller.dart';
import 'main_shell.dart';
import 'manajemen_petani_screen.dart';
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../../../../../services/mongodb_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show modify, where;
import '../../../../services/notification_service.dart';
import 'notifikasi_screen.dart';
import 'package:provider/provider.dart';


class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final _controller = BerandaController();
  bool _syncing = false;

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.sync_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Memulai sinkronisasi data...', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.hijauTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 1),
      ),
    );

    await _controller.syncData();

    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Data berhasil disinkronkan!', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          backgroundColor: AppTheme.hijauMuda,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final harga   = _controller.hargaTerbaru;
    final riwayat = _controller.riwayatTerbaru;
    final mitra   = _controller.mitraTerbaru;

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
                  controller: _controller,
                  syncing: _syncing,
                  onSync: _refresh,
                ),
              ),

              // ── Body ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 150),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Stat cards
                    _StatRow(
                      jumlahTransaksi: _controller.jumlahTransaksi,
                      totalBerat: _controller.totalBerat,
                      pending: _controller.pending,
                    ),
                    const SizedBox(height: 24),

                    // Riwayat transaksi preview (Dipindah ke atas)
                    _SectionHeader(
                      title: 'Transaksi Terakhir',
                      actionLabel: 'Lihat Semua',
                      onAction: () =>
                          MainShellState.of(context)?.changeTab(3),
                    ),
                    const SizedBox(height: 12),
                    if (riwayat.isEmpty)
                      const _EmptyCard(
                          msg:
                              'Belum ada transaksi.\nTekan tombol kamera untuk mulai.')
                    else
                      ...riwayat.map((t) => _TransaksiRow(
                        trx: t,
                        onEdit: t.statusSinkronisasi != 'pending_delete'
                            ? () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransaksiScreen(editTrx: t),
                                  ),
                                );
                                if (changed == true && mounted) setState(() {});
                              }
                            : null,
                        onDelete: t.statusSinkronisasi != 'pending_delete'
                            ? () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Hapus Transaksi',
                                        style: TextStyle(fontWeight: FontWeight.w700)),
                                    content: const Text(
                                        'Transaksi ini akan dihapus dari perangkat. Lanjutkan?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.merah,
                                            foregroundColor: Colors.white,
                                            elevation: 0),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted) {
                                  await _controller.hapusTransaksi(t);
                                  setState(() {});
                                }
                              }
                            : null,
                      )),
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
                      const _EmptyCard(
                          msg:
                              'Belum ada data harga.\nTarik ke bawah untuk sync dari server.')
                    else
                      ...harga.map((h) => _HargaRow(data: h)),
                    const SizedBox(height: 24),

                    // Daftar Mitra
                    _SectionHeader(
                      title: 'Daftar Mitra',
                      actionLabel: 'Lihat Semua',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManajemenPetaniScreen()),
                      ).then((_) => setState(() {})),
                    ),
                    const SizedBox(height: 12),
                    if (mitra.isEmpty)
                      const _EmptyCard(msg: 'Belum ada data mitra.\nTambahkan mitra baru.')
                    else
                      ...mitra.map((p) => _MitraRow(
                        data: p,
                        onEdit: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                            builder: (_) => PetaniFormSheet(
                              petaniLama: p,
                              onSimpan: (nama, desa) async {
                                p.namaPetani = nama;
                                p.desa = desa;
                                await p.save();
                                try {
                                  final col = MongoDatabase.getCollection('petani');
                                  await col.updateOne(where.eq('_id', p.id), modify.set('nama_petani', nama).set('desa', desa));
                                } catch (_) {}
                                if (mounted) { Navigator.pop(context); setState((){}); }
                              },
                            ),
                          );
                        },
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Hapus Petani', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text('Yakin ingin menghapus ${p.namaPetani}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond)),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final idHapus = p.id;
                                    await p.delete();
                                    try {
                                      final col = MongoDatabase.getCollection('petani');
                                      await col.deleteOne(where.eq('_id', idHapus));
                                    } catch (_) {}
                                    if (mounted) { Navigator.pop(context); setState((){}); }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                        },
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

// ── Header bergradien ────────────────────────────────────────────
class _Header extends StatelessWidget {
  final BerandaController controller;
  final bool syncing;
  final VoidCallback onSync;

  const _Header(
      {required this.controller,
      required this.syncing,
      required this.onSync});

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat siang,',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
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
                          MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
                        ),
                      ),
                      if (svc.unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.merah,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              '${svc.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
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
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF59E0B),
                child: Text(
                  user.username.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF019241),
                      fontWeight: FontWeight.w800,
                      fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Saldo / Balancing card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF015225),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saldo Uang Jalan Saat Ini',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ]),
                    // Badge status sinkronisasi kas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: controller.pending > 0 ? const Color(0xFFF59E0B) : AppTheme.hijauMuda,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        controller.pending > 0 ? '${controller.pending} Pending Sync' : 'Kas Tersinkron',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _fmtRupiah(user.sisaUangJalan),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengeluaran Hari Ini', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_fmtRupiah(controller.totalPengeluaranHariIni), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Potongan Kasbon', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_fmtRupiah(controller.totalPotonganKasbonHariIni), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: spinning
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Icon(icon, color: Colors.white, size: 24),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecond)),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 14,
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
                        fontWeight: FontWeight.w700, fontSize: 16)),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: gradeColor)),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${_fmtRibu(harga.toInt())}/$satuan',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _MitraRow extends StatelessWidget {
  final PetaniHiveModel data;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  const _MitraRow({
    required this.data,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.hijauSoft,
            child: Text(
              data.namaPetani.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.namaPetani,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  data.desa,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecond),
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecond, size: 22),
                    tooltip: 'Edit',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: AppTheme.merah, size: 22),
                    tooltip: 'Hapus',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Transaksi Row ────────────────────────────────────────────────
class _TransaksiRow extends StatelessWidget {
  final TransaksiHiveModel trx;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransaksiRow({
    required this.trx,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = trx.statusSinkronisasi;
    final isPendingOrUpdate = status == 'pending' || status == 'pending_update';
    
    Color badgeBg = AppTheme.hijauSoft;
    Color badgeDot = AppTheme.hijauMuda;
    Color badgeTextCol = AppTheme.hijauTua;
    String badgeText = 'Synced';

    if (status == 'pending') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeDot = const Color(0xFFF59E0B);
      badgeTextCol = const Color(0xFF92400E);
      badgeText = 'Pending';
    } else if (status == 'pending_update') {
      badgeBg = const Color(0xFFDBEAFE);
      badgeDot = const Color(0xFF3B82F6);
      badgeTextCol = const Color(0xFF1E3A8A);
      badgeText = 'Updating';
    }

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
                      fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  trx.namaPetani,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecond),
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
                    fontSize: 15,
                    color: AppTheme.hijauTua),
              ),
              const SizedBox(height: 4),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badgeDot,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badgeTextCol,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Tombol aksi muncul jika onEdit/onDelete diberikan
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecond, size: 22),
                    tooltip: 'Edit',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: AppTheme.merah, size: 22),
                    tooltip: 'Hapus',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
              ],
            ),
          ],
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