import 'package:flutter/material.dart';
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
              Expanded(child: Text('$count data transaksi tersinkronisasi berhasil dibersihkan.', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('Kamu yakin ingin keluar dari akun ini?\nSisa uang jalan dan data tertunda tetap aman di perangkat.', style: TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
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

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Profil Akun', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppTheme.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          // ── Header User ──
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.hijauSoft,
                  child: Text(
                    user.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.hijauTua),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Pengepul Lapangan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.hijauTua)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Bagian Informasi Finansial ──
          const _SectionTitle(title: 'Informasi Finansial'),
          _MenuCard(
            children: [
              _ListTileItem(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFD97706),
                title: 'Saldo Uang Jalan',
                trailingWidget: Text(
                  _fmtRupiah(user.sisaUangJalan),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.hijauTua),
                ),
                showBorder: false,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Bagian Pengaturan & Sistem ──
          const _SectionTitle(title: 'Sistem & Penyimpanan'),
          _MenuCard(
            children: [
              _ListTileItem(
                icon: Icons.cloud_queue_rounded,
                iconColor: AppTheme.hijauMuda,
                title: 'Status MongoDB Server',
                trailingWidget: _ctrl.isChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.hijauMuda))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _ctrl.isConnected ? AppTheme.hijauMuda : AppTheme.merah),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _ctrl.isConnected ? 'Terhubung' : 'Terputus',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ctrl.isConnected ? AppTheme.hijauTua : AppTheme.merah),
                          ),
                        ],
                      ),
                onTap: _ctrl.cekKoneksi,
              ),
              _ListTileItem(
                icon: Icons.cleaning_services_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Bersihkan Cache Sinkronisasi',
                subtitle: 'Hapus data tersinkronisasi untuk menghemat RAM',
                showArrow: true,
                onTap: _handleBersihkanCache,
              ),
              const _ListTileItem(
                icon: Icons.security_rounded,
                iconColor: Color(0xFF8B5CF6),
                title: 'Perizinan Perangkat',
                subtitle: 'Akses GPS & Kamera dikelola otomatis',
                showBorder: false,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Bagian Bantuan & Legal ──
          const _SectionTitle(title: 'Bantuan & Legal'),
          _MenuCard(
            children: [
              _ListTileItem(icon: Icons.help_outline_rounded, iconColor: AppTheme.textSecond, title: 'Pusat Bantuan Agen', showArrow: true, onTap: () {}),
              _ListTileItem(icon: Icons.article_outlined, iconColor: AppTheme.textSecond, title: 'Syarat & Ketentuan', showArrow: true, onTap: () {}, showBorder: false),
            ],
          ),
          const SizedBox(height: 32),

          // ── Tombol Keluar ──
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.merah.withOpacity(0.1),
                foregroundColor: AppTheme.merah,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppTheme.merah.withOpacity(0.3))),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          const Center(child: Text('ReksaTani v1.0.0 (Offline-first Edition)', style: TextStyle(fontSize: 13, color: AppTheme.textHint))),
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

// ── Komponen Reusable Profil ──
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textSecond)),
      );
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Column(children: children),
      );
}

class _ListTileItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailingWidget;
  final bool showArrow;
  final bool showBorder;
  final VoidCallback? onTap;

  const _ListTileItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingWidget,
    this.showArrow = false,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: showBorder ? const Border(bottom: BorderSide(color: AppTheme.border)) : null),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond)),
                    ]
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget!,
              ] else if (showArrow) ...[
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
              ]
            ],
          ),
        ),
      );
}