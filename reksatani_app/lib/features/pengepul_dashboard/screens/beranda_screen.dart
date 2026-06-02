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
import '../../../../services/master_data_service.dart';
import '../../../../../shared/widgets/transaksi_detail_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    MasterDataService().addListener(_onDataMasterChanged);
  }

  void _onDataMasterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MasterDataService().removeListener(_onDataMasterChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memulai sinkronisasi data...'), duration: Duration(seconds: 1)),
    );

    await _controller.syncData();

    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Data berhasil disinkronkan!', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppTheme.hijauMuda,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), 
          side: const BorderSide(color: AppTheme.border, width: 1.5), // FIX ERROR
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.merah),
            SizedBox(width: 8),
            Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'Kamu yakin ingin logout?\nData luring tetap tersimpan dengan aman di perangkat ini.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecond, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.merah,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (konfirmasi == true && mounted) {
      await _controller.logout();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final harga = _controller.hargaTerbaru;
    final riwayat = _controller.riwayatTerbaru;
    final mitra = _controller.mitraTerbaru;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // Teks status bar gelap karena header putih
      child: Scaffold(
        backgroundColor: AppTheme.bgPage, // Background abu-abu sangat muda (High contrast)
        body: RefreshIndicator(
          color: AppTheme.hijauMuda,
          backgroundColor: Colors.white,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. HEADER "OVERLAPPING CARD" (OUTDOOR FRIENDLY) ──
              SliverToBoxAdapter(
                child: _HeaderModern(controller: _controller),
              ),

              // ── 2. BODY CONTENT (BENTO GRID & LISTS) ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    // STAT CARD ALA BENTO GRID (Solid & Clean)
                    _BentoStatRow(
                      jumlahTransaksi: _controller.jumlahTransaksi,
                      totalBerat: _controller.totalBerat,
                      pending: _controller.pending,
                    ),
                    const SizedBox(height: 36),

                    // ── SECTION: MITRA ──
                    _SectionHeader(
                      title: 'Daftar Mitra',
                      icon: Icons.people_alt_rounded,
                      actionLabel: 'Lihat Semua',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenPetaniScreen())).then((_) => setState(() {})),
                    ),
                    const SizedBox(height: 16),
                    if (mitra.isEmpty)
                      const _EmptyStateBento(icon: Icons.person_add_disabled_rounded, msg: 'Belum ada data mitra.\nTambahkan mitra baru.')
                    else
                      ...mitra.map((p) => _MitraRow(
                            data: p,
                            onEdit: () {
                              showModalBottomSheet(
                                context: context, isScrollControlled: true, backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                                builder: (_) => PetaniFormSheet(
                                  petaniLama: p,
                                  onSimpan: (nama, desa) async {
                                    p.namaPetani = nama; p.desa = desa;
                                    await p.save();
                                    try {
                                      final col = MongoDatabase.getCollection('petani');
                                      await col.updateOne(where.eq('_id', p.id), modify.set('nama_petani', nama).set('desa', desa));
                                    } catch (_) {}
                                    if (mounted) { Navigator.pop(context); setState(() {}); }
                                  },
                                ),
                              );
                            },
                            onDelete: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: const Text('Hapus Petani', style: TextStyle(fontWeight: FontWeight.w800)),
                                  content: Text('Yakin ingin menghapus ${p.namaPetani}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond))),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final idHapus = p.id;
                                        await p.delete();
                                        try {
                                          final col = MongoDatabase.getCollection('petani');
                                          await col.deleteOne(where.eq('_id', idHapus));
                                        } catch (_) {}
                                        if (mounted) { Navigator.pop(context); setState(() {}); }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
                    const SizedBox(height: 36),

                    // ── SECTION: HARGA PASAR ──
                    _SectionHeader(
                      title: 'Harga Pasar Terkini',
                      icon: Icons.storefront_rounded,
                      actionLabel: 'Lihat Semua',
                      onAction: () => MainShellState.of(context)?.changeTab(1),
                    ),
                    const SizedBox(height: 16),
                    if (harga.isEmpty)
                      const _EmptyStateBento(icon: Icons.price_change_outlined, msg: 'Belum ada data harga.\nTarik ke bawah untuk sync.')
                    else
                      ...harga.map((h) => _HargaRow(data: h)),
                    const SizedBox(height: 36),

                    // ── SECTION: TRANSAKSI TERAKHIR ──
                    _SectionHeader(
                      title: 'Transaksi Terakhir',
                      icon: Icons.history_rounded,
                      actionLabel: 'Lihat Semua',
                      onAction: () => MainShellState.of(context)?.changeTab(3),
                    ),
                    const SizedBox(height: 16),
                    if (riwayat.isEmpty)
                      const _EmptyStateBento(icon: Icons.receipt_long_rounded, msg: 'Belum ada riwayat transaksi.')
                    else
                      ...riwayat.map((t) => _TransaksiRow(
                            trx: t,
                            onEdit: t.statusSinkronisasi != 'pending_delete'
                                ? () async {
                                    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TransaksiScreen(editTrx: t)));
                                    if (changed == true && mounted) setState(() {});
                                  }
                                : null,
                            onDelete: t.statusSinkronisasi != 'pending_delete'
                                ? () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        title: const Text('Hapus Transaksi', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.merah)),
                                        content: const Text('Transaksi ini akan dihapus permanen. Lanjutkan?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond))),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
                                            child: const Text('Hapus Permanen'),
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

// ────────────────────────────────────────────────────────────────────────
// ─── KOMPONEN UI "OUTDOOR FRIENDLY" (HIGH CONTRAST & CLEAN) ───────────
// ────────────────────────────────────────────────────────────────────────

// ── 1. HEADER SOLID WHITE (Background Bersih khas Reference) ──
class _HeaderModern extends StatelessWidget {
  final BerandaController controller;

  const _HeaderModern({required this.controller});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    final top = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // Background Putih Bersih (Outdoor Friendly)
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BARIS GREETING & PROFIL (Teks Gelap agar Terbaca) ──
          Row(
            children: [
              // Logo Kiri
              Container(
                width: 45, height: 45, padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 24, color: AppTheme.hijauTua)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(color: AppTheme.textSecond, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.username,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              
              // Notifikasi Badge
              ChangeNotifierProvider.value(
                value: NotificationService(),
                child: Consumer<NotificationService>(
                  builder: (context, svc, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifikasiScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.hijauSoft, shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none_rounded, color: AppTheme.hijauTua, size: 24),
                        ),
                      ),
                      if (svc.unreadCount > 0)
                        Positioned(
                          right: -4, top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: AppTheme.merah, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            child: Text('${svc.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Avatar Profil
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border, width: 2)),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.kuning,
                  child: Text(user.username.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── KARTU SALDO (Distinct, green gradient highlight card ala Reference) ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient, // Gradasi Hijau Terang (AppTheme)
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                // Bayangan jatuh tebal untuk efek highlight maksumum
                BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.35), blurRadius: 25, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Saldo Uang Jalan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)), // Teks putih untuk kontras maksumum
                      ],
                    ),
                    // Pill Badge Status Sync
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: controller.pending > 0 ? const Color(0xFFFEF3C7) : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(controller.pending > 0 ? Icons.sync_problem_rounded : Icons.cloud_done_rounded, color: controller.pending > 0 ? const Color(0xFFD97706) : Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            controller.pending > 0 ? '${controller.pending} Pending' : 'Tersinkron',
                            style: TextStyle(color: controller.pending > 0 ? const Color(0xFFD97706) : Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _fmtRupiah(user.sisaUangJalan),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.0), // Teks putih untuk kontras maksumum
                ),
                const SizedBox(height: 24),
                Container(height: 1, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                
                // Rincian bawah kartu: Daily summariesside-by-side ala buttons ala Reference
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pengeluaran Hari Ini', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(_fmtRupiah(controller.totalPengeluaranHariIni), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Potongan Kasbon', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(_fmtRupiah(controller.totalPotonganKasbonHariIni), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
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

  String _fmtRupiah(double angka) {
    final s = angka.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${buf.toString()}';
  }
}

// ── 2. BENTO STAT ROW (Solid & Clean ala Bento Design) ──
class _BentoStatRow extends StatelessWidget {
  final int jumlahTransaksi, pending;
  final double totalBerat;

  const _BentoStatRow({required this.jumlahTransaksi, required this.totalBerat, required this.pending});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BentoCard(label: 'Transaksi', value: '$jumlahTransaksi', icon: Icons.receipt_long_rounded, color: AppTheme.biru),
        const SizedBox(width: 14),
        _BentoCard(label: 'Total Berat', value: '${totalBerat.toStringAsFixed(0)} kg', icon: Icons.scale_rounded, color: AppTheme.hijauMuda),
        const SizedBox(width: 14),
        _BentoCard(label: 'Pending', value: '$pending', icon: Icons.cloud_upload_rounded, color: AppTheme.kuning),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _BentoCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── 3. SECTION HEADER DENGAN AKSEN ──
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({required this.title, required this.icon, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.hijauMuda, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
            ],
          ),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(20)),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.hijauTua)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── WIDGET INTI: KARTU LIST ITEM SOLID & BERSIH ──
class _CleanCard extends StatelessWidget {
  final Widget child;

  const _CleanCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

// ── 4. LIST ITEMS ──
class _MitraRow extends StatelessWidget {
  final PetaniHiveModel data;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  const _MitraRow({required this.data, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return _CleanCard(
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: Text(data.namaPetani.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.namaPetani, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppTheme.textHint, size: 14),
                    const SizedBox(width: 4),
                    Text(data.desa, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              onSelected: (val) { if (val == 'edit') onEdit?.call(); if (val == 'delete') onDelete?.call(); },
              icon: const Icon(Icons.more_vert_rounded, size: 24, color: AppTheme.textSecond),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              elevation: 10,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppTheme.textPrimary), SizedBox(width: 10), Text('Edit Mitra', style: TextStyle(fontWeight: FontWeight.w600))])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppTheme.merah), SizedBox(width: 10), Text('Hapus', style: TextStyle(color: AppTheme.merah, fontWeight: FontWeight.w600))])),
              ],
            ),
        ],
      ),
    );
  }
}

class _HargaRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HargaRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final grade = data['grade'] as String;
    final harga = data['hargaMaks'] as double;
    final satuan = data['unitSatuan'] as String;
    final komoditas = data['namaKomoditas'] as String;

    final gradeColor = switch (grade) { 'A' => AppTheme.hijauMuda, 'B' => const Color(0xFFF59E0B), _ => AppTheme.merah };

    return _CleanCard(
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('🌾', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(komoditas, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: gradeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('Grade $grade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: gradeColor)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rp ${_fmtRibu(harga.toInt())}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.hijauTua)),
              const SizedBox(height: 2),
              Text('/ $satuan', style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
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
}

class _TransaksiRow extends StatelessWidget {
  final TransaksiHiveModel trx;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransaksiRow({required this.trx, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = trx.statusSinkronisasi;
    final isKasbonMurni = trx.namaKomoditas.toLowerCase().contains('pencairan kasbon');
    
    Color badgeBg = AppTheme.hijauSoft;
    Color badgeDot = AppTheme.hijauMuda;
    Color badgeTextCol = AppTheme.hijauTua;
    String badgeText = 'Synced';

    if (status == 'pending') { badgeBg = const Color(0xFFFEF3C7); badgeDot = const Color(0xFFF59E0B); badgeTextCol = const Color(0xFF92400E); badgeText = 'Pending'; } 
    else if (status == 'pending_update') { badgeBg = const Color(0xFFDBEAFE); badgeDot = const Color(0xFF3B82F6); badgeTextCol = const Color(0xFF1E3A8A); badgeText = 'Updating'; }

    return GestureDetector(
      onTap: () => TransaksiDetailSheet.show(context, trx),
      behavior: HitTestBehavior.opaque,      
      child: _CleanCard(
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: isKasbonMurni ? const Color(0xFFFEF3C7) : AppTheme.bgPage, borderRadius: BorderRadius.circular(16)),
              child: Center(child: isKasbonMurni ? const Icon(Icons.payments_rounded, color: Color(0xFFF59E0B), size: 24) : const Text('🌾', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKasbonMurni ? 'Pencairan Kasbon' : '${trx.namaKomoditas} · ${trx.berat.toInt()} kg',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isKasbonMurni ? const Color(0xFFB45309) : AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, color: AppTheme.textSecond, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(trx.namaPetani, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
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
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isKasbonMurni ? const Color(0xFFB45309) : AppTheme.hijauTua),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: badgeDot)),
                      const SizedBox(width: 4),
                      Text(badgeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeTextCol)),
                    ],
                  ),
                ),
              ],
            ),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (val) { if (val == 'edit') onEdit?.call(); if (val == 'delete') onDelete?.call(); },
                icon: const Icon(Icons.more_vert_rounded, size: 24, color: AppTheme.textSecond),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                elevation: 10,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppTheme.textPrimary), SizedBox(width: 10), Text('Edit', style: TextStyle(fontWeight: FontWeight.w600))])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppTheme.merah), SizedBox(width: 10), Text('Hapus', style: TextStyle(color: AppTheme.merah, fontWeight: FontWeight.w600))])),
                ],
              ),
            ],
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
}

// ── 5. EMPTY STATE SOLID BENTO CARD ──
class _EmptyStateBento extends StatelessWidget {
  final String msg;
  final IconData icon;
  
  const _EmptyStateBento({required this.msg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.bgPage, shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.textHint, size: 36),
            ),
            const SizedBox(height: 16),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.5)),
          ],
        ),
      ),
    );
  }
}