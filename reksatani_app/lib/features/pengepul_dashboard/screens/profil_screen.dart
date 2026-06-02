import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../../../../core/routing/app_router.dart';
import '../controllers/profil_controller.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late final ProfilController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ProfilController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleBersihkanCache() async {
    final count = await _ctrl.bersihkanCacheTersinkronisasi();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('$count data tersinkronisasi berhasil dibersihkan.', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
            ],
          ),
          backgroundColor: AppTheme.hijauTua,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
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
        content: const Text(
          'Kamu yakin ingin keluar dari akun ini?\nSisa uang jalan dan data tertunda tetap aman di perangkat.',
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
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (konfirmasi == true && mounted) {
      await _ctrl.logout();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppRouter.getGatekeeper()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _ctrl.user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: const Text('Profil Akun', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
          ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          children: [
            // ── 1. KARTU PROFIL UTAMA (BENTO STYLE) ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.kuning,
                      child: Text(
                        user.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Agen Pengepul Lapangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.hijauTua)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. KARTU SALDO UANG JALAN (HIGHLIGHT) ──
            const Text('INFORMASI FINANSIAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecond, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Sisa Saldo Uang Jalan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fmtRupiah(user.sisaUangJalan),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── 3. KARTU SISTEM & PENYIMPANAN (FUNGSI ASLI) ──
            const Text('SISTEM & PENYIMPANAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecond, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  // Item: Status MongoDB
                  InkWell(
                    onTap: _ctrl.cekKoneksi,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.textSecond, size: 22),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status MongoDB Server', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                SizedBox(height: 2),
                                Text('Ketuk untuk mengecek koneksi', style: TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          _ctrl.isChecking
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.hijauTua))
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _ctrl.isConnected ? AppTheme.hijauSoft : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: _ctrl.isConnected ? AppTheme.hijauTua : AppTheme.merah),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _ctrl.isConnected ? 'Terhubung' : 'Terputus',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ctrl.isConnected ? AppTheme.hijauTua : AppTheme.merah),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  
                  Container(height: 1, color: AppTheme.bgPage, margin: const EdgeInsets.symmetric(horizontal: 20)),

                  // Item: Bersihkan Cache
                  InkWell(
                    onTap: _handleBersihkanCache,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF3B82F6), size: 22), // Biru
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bersihkan Cache Transaksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                SizedBox(height: 2),
                                Text('Menghapus riwayat yang telah tersinkronisasi', style: TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textHint),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // ── 4. TOMBOL LOGOUT PREMIUM ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.merah,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.merah, width: 1.5),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 22),
                    SizedBox(width: 10),
                    Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Version Info
            const Center(
              child: Text(
                'ReksaTani v1.0.0 (Offline-first Edition)',
                style: TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w600),
              ),
            ),
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