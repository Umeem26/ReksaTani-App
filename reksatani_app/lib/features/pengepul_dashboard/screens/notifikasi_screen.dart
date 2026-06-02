import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../../../../services/notification_service.dart';
import '../../../../models/hive/notifikasi_hive_model.dart';

class NotifikasiScreen extends StatelessWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: NotificationService(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppTheme.bgPage,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
            ),
            actions: [
              Consumer<NotificationService>(
                builder: (context, svc, _) => svc.unreadCount > 0 
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton.icon(
                        onPressed: () => svc.markAllAsRead(),
                        icon: const Icon(Icons.done_all_rounded, size: 18, color: AppTheme.hijauTua),
                        label: const Text('Baca Semua', style: TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w700, fontSize: 13)),
                        style: TextButton.styleFrom(backgroundColor: AppTheme.hijauSoft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
            ],
          ),
          body: Consumer<NotificationService>(
            builder: (context, svc, _) {
              final list = svc.allNotifications;
              
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                        child: const Icon(Icons.notifications_off_rounded, size: 48, color: AppTheme.textHint),
                      ),
                      const SizedBox(height: 20),
                      const Text('Belum Ada Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('Notifikasi sistem dan info sinkronisasi\nakan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.4)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: list.length,
                itemBuilder: (_, i) => _NotifCard(notif: list[i], svc: svc),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotifikasiHiveModel notif;
  final NotificationService svc;

  const _NotifCard({required this.notif, required this.svc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!notif.isRead) svc.markAsRead(notif.id);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : AppTheme.hijauSoft.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: notif.isRead ? AppTheme.border.withOpacity(0.5) : AppTheme.hijauMuda.withOpacity(0.3)),
          boxShadow: notif.isRead ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon Kiri
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notif.isRead ? AppTheme.bgPage : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                notif.judul.toLowerCase().contains('gagal') ? Icons.error_rounded : Icons.notifications_active_rounded, 
                color: notif.judul.toLowerCase().contains('gagal') ? AppTheme.merah : AppTheme.hijauTua,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            
            // Konten Teks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notif.judul, 
                          style: TextStyle(fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary, letterSpacing: -0.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtWaktu(notif.waktu), 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: notif.isRead ? AppTheme.textHint : AppTheme.hijauTua),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.pesan, 
                    style: TextStyle(fontSize: 13, color: notif.isRead ? AppTheme.textSecond : AppTheme.textPrimary, height: 1.4, fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w600),
                  ),
                ],
              ),
            ),
            
            // Titik Unread
            if (!notif.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 10, height: 10,
                decoration: const BoxDecoration(color: AppTheme.kuning, shape: BoxShape.circle),
              )
            ]
          ],
        ),
      ),
    );
  }

  String _fmtWaktu(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}