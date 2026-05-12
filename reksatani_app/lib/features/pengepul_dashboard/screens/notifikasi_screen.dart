import 'package:flutter/material.dart';
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
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Notifikasi', 
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0.5,
          actions: [
            Consumer<NotificationService>(
              builder: (context, svc, _) => TextButton(
                onPressed: () => svc.markAllAsRead(),
                child: const Text('Baca Semua', 
                  style: TextStyle(color: AppTheme.hijauMuda, fontWeight: FontWeight.w600)),
              ),
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
                    Icon(Icons.notifications_none_rounded, 
                      size: 64, color: AppTheme.textSecond.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text('Belum ada notifikasi', 
                      style: TextStyle(color: AppTheme.textSecond)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final notif = list[index];
                return _NotifTile(notif: notif);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotifikasiHiveModel notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService();
    
    IconData iconData;
    Color color;
    
    switch (notif.tipe) {
      case 'sync':
        iconData = Icons.sync_rounded;
        color = AppTheme.hijauMuda;
        break;
      case 'saldo':
        iconData = Icons.account_balance_wallet_rounded;
        color = Colors.orange;
        break;
      case 'harga':
        iconData = Icons.local_offer_rounded;
        color = Colors.blue;
        break;
      default:
        iconData = Icons.notifications_rounded;
        color = AppTheme.textSecond;
    }

    return GestureDetector(
      onTap: () => svc.markAsRead(notif.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(radius: 14).copyWith(
          color: notif.isRead ? Colors.white : const Color(0xFFF0F9FF),
          border: notif.isRead ? null : Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(notif.judul, 
                        style: TextStyle(
                          fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        )),
                      Text(_fmtWaktu(notif.waktu), 
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecond)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.pesan, 
                    style: TextStyle(
                      fontSize: 12, 
                      color: AppTheme.textSecond,
                      height: 1.4,
                      fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w500,
                    )),
                ],
              ),
            ),
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
    return '${dt.day}/${dt.month}';
  }
}
