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
import '../../../../services/master_data_service.dart';
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
    
    // Tambahkan listener agar beranda manajer "dengar" kalau sync selesai
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
    // Wajib hapus listener saat layar ditutup agar tidak memory leak
    MasterDataService().removeListener(_onDataMasterChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.border, width: 1.5), 
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.merah),
            SizedBox(width: 8),
            Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text('Kamu yakin ingin logout dari akun Manajer Gudang?', style: TextStyle(fontSize: 14, color: AppTheme.textSecond, height: 1.5)),
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
      await AuthController().logout();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, 
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        body: RefreshIndicator(
          color: AppTheme.hijauMuda,
          backgroundColor: Colors.white,
          onRefresh: _ctrl.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. HEADER OUTDOOR FRIENDLY (PUTIH BERSIH + GLOWING ACCENT CARD) ──
              SliverToBoxAdapter(
                child: _ManajerHeaderModern(
                  user: _ctrl.user,
                  syncing: _ctrl.syncing,
                  onSync: _ctrl.refresh,
                  onLogout: _logout,
                  totalNilai: _ctrl.totalNilai,
                  totalStokKg: _ctrl.totalStokKg,
                ),
              ),

              // ── 2. BODY CONTENT (BENTO GRID METRIK & LISTS) ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    // BENTO SINKRONISASI ROW
                    _BentoSyncRow(
                      jumlahPending: _ctrl.jumlahPending,
                      jumlahSynced: _ctrl.jumlahSynced,
                    ),
                    const SizedBox(height: 36),

                    // SECTION: HARGA & KOMODITAS
                    _SectionHeaderModern(
                      title: 'Harga & Komoditas Gudang',
                      icon: Icons.grid_view_rounded,
                      actionLabel: 'Lihat Semua',
                      onAction: () => ManajerShellState.of(context)?.changeTab(3),
                    ),
                    const SizedBox(height: 16),
                    if (_ctrl.daftarKomoditas.isEmpty)
                      const _EmptyCardBento(msg: 'Belum ada komoditas terdaftar di gudang.')
                    else
                      ..._ctrl.daftarKomoditas.take(3).map((k) {
                        final hasGrade = k.gradeKualitas.isNotEmpty;
                        double hargaMaks = 0.0;
                        if (hasGrade) {
                          try {
                            hargaMaks = (k.gradeKualitas.last['harga_maks'] as num).toDouble();
                          } catch (_) {}
                        }
                        return _KomoditasRowModern(
                          namaKomoditas: k.namaKomoditas,
                          jumlahGrade: k.gradeKualitas.length,
                          hargaMaks: hargaMaks,
                          hasGrade: hasGrade,
                        );
                      }),
                    const SizedBox(height: 36),

                    // SECTION: AKTIVITAS & KAS AGEN
                    _SectionHeaderModern(
                      title: 'Aktivitas & Uang Jalan Agen',
                      icon: Icons.assignment_ind_rounded,
                      actionLabel: 'Lihat Semua',
                      onAction: () => ManajerShellState.of(context)?.changeTab(4),
                    ),
                    const SizedBox(height: 16),
                    if (_ctrl.daftarAgen.isEmpty)
                      const _EmptyCardBento(msg: 'Belum ada data agen lapangan terdaftar.')
                    else
                      ..._ctrl.daftarAgen.map((agen) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _KasAgenCardModern(
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

// ─── KOMPONEN UI MODERN BERGAYA ENTERPRISE BENTO ───

// ── 1. MANAJER HEADER REVOLUSIONER (Clean Base + Gradient Highlight) ──
class _ManajerHeaderModern extends StatelessWidget {
  final UserHiveModel user;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onLogout;
  final double totalNilai;
  final double totalStokKg;

  const _ManajerHeaderModern({
    required this.user,
    required this.syncing,
    required this.onSync,
    required this.onLogout,
    required this.totalNilai,
    required this.totalStokKg,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BARIS ATAS: PROFIL & SELEKTOR AKSI
          Row(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border, width: 2)),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF59E0B), 
                  child: Text(
                    user.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halo, Juragan', style: TextStyle(color: AppTheme.textSecond.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(user.username, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ],
                ),
              ),
              
              // Refresh/Sync Button
              _IkonBtnHeader(
                icon: Icons.sync_rounded,
                onTap: onSync,
                spinning: syncing,
                color: AppTheme.hijauSoft,
                iconColor: AppTheme.hijauTua,
              ),
              const SizedBox(width: 10),

              // Notifikasi Badge
              ChangeNotifierProvider.value(
                value: NotificationService(),
                child: Consumer<NotificationService>(
                  builder: (context, svc, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _IkonBtnHeader(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifikasiScreen())),
                        color: AppTheme.hijauSoft,
                        iconColor: AppTheme.hijauTua,
                      ),
                      if (svc.unreadCount > 0)
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppTheme.merah, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text('${svc.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Logout Button
              _IkonBtnHeader(
                icon: Icons.logout_rounded,
                onTap: onLogout,
                color: Colors.red.shade50,
                iconColor: AppTheme.merah,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // KARTU GLOWING VALUE & STOK (HIGHLIGHT UTAMA)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient, 
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.35), blurRadius: 25, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Total Valuasi Transaksi Masuk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Dasbor Manajer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _fmtRupiah(totalNilai),
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                ),
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    // FIX TYPO ERROR: DI SINI BAGIAN YANG DIPERBAIKI (MENGGUNAKAN Colors.white70)
                    const Text('Akumulasi Volume Stok Gudang: ', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${totalStokKg.toStringAsFixed(0)} kg', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
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

// ── 2. BENTO SYNC STATUS ROW ──
class _BentoSyncRow extends StatelessWidget {
  
  final int jumlahPending, jumlahSynced;

  const _BentoSyncRow({required this.jumlahPending, required this.jumlahSynced});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BentoStatCard(
          label: 'Menunggu Sync',
          value: '$jumlahPending Transaksi',
          icon: Icons.cloud_off_rounded,
          color: const Color(0xFFF59E0B), // Amber
        ),
        const SizedBox(width: 14),
        _BentoStatCard(
          label: 'Sudah Sinkron',
          value: '$jumlahSynced Transaksi',
          icon: Icons.cloud_done_rounded,
          color: AppTheme.hijauMuda,
        ),
      ],
    );
  }
}

class _BentoStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _BentoStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── 3. ROW HARGA KOMODITAS GUDANG ──
class _KomoditasRowModern extends StatelessWidget {
  final String namaKomoditas;
  final int jumlahGrade;
  final double hargaMaks;
  final bool hasGrade;

  const _KomoditasRowModern({
    required this.namaKomoditas,
    required this.jumlahGrade,
    required this.hargaMaks,
    required this.hasGrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('🌾', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(namaKomoditas, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary, letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(6)),
                  child: Text('$jumlahGrade Kualitas Grade', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecond)),
                ),
              ],
            ),
          ),
          if (hasGrade)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Mulai dari', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_fmtRupiah(hargaMaks), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary, letterSpacing: -0.5)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── 4. KARTU UANG JALAN AGEN (EXPANDABLE BENTO) ──
class _KasAgenCardModern extends StatefulWidget {
  final UserHiveModel user;
  final List<TransaksiHiveModel> history;
  final DateTime? lastSync;
  
  const _KasAgenCardModern({required this.user, required this.history, this.lastSync});

  @override
  State<_KasAgenCardModern> createState() => _KasAgenCardModernState();
}

class _KasAgenCardModernState extends State<_KasAgenCardModern> {
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
    return '${widget.lastSync!.day}/${widget.lastSync!.month}/${widget.lastSync!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('👤', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.username, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _isOnline ? AppTheme.hijauMuda : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'Aktif Lapangan' : _timeAgo,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isOnline ? AppTheme.hijauTua : AppTheme.textSecond),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmtRupiah(widget.user.sisaUangJalan), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.hijauTua, letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      const Text('Sisa Uang Jalan', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecond, size: 22),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Container(height: 1, color: AppTheme.bgPage),
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.bgPage.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 14, color: AppTheme.textSecond),
                      const SizedBox(width: 6),
                      Text('5 Aktivitas Terakhir Agen:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Belum ada rekaman transaksi dari agen ini.', style: TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
                    )
                  else
                    ...widget.history.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${t.namaKomoditas} · ${t.berat.toInt()} kg', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('${t.namaPetani} · ${_fmtDate(t.createdAt)}', style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              Text(_fmtRupiah(t.totalBayar), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.hijauTua)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── 5. WIDGET HEADERS & BUTTONS HELPERS ──
class _SectionHeaderModern extends StatelessWidget {
  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeaderModern({required this.title, required this.icon, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.hijauMuda, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
          ],
        ),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(20)),
            child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.hijauTua)),
          ),
        ),
      ],
    );
  }
}

class _IkonBtnHeader extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool spinning;
  final Color color;
  final Color iconColor;

  const _IkonBtnHeader({required this.icon, required this.onTap, this.spinning = false, required this.color, required this.iconColor});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: spinning
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: iconColor, strokeWidth: 2.5))
              : Icon(icon, color: iconColor, size: 20),
        ),
      );
}

class _EmptyCardBento extends StatelessWidget {
  final String msg;
  const _EmptyCardBento({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border.withOpacity(0.6)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inbox_rounded, color: AppTheme.textHint, size: 36),
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