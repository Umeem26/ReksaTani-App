import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reksatani_app/services/notification_service.dart';
import 'package:reksatani_app/models/hive/notifikasi_hive_model.dart';

void main() {
  late NotificationService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notification_service_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(NotifikasiHiveModelAdapter());

    await Hive.openBox<NotifikasiHiveModel>('notifikasiBox');

    service = NotificationService();
  });

  tearDown(() async {
    await service.clearAll();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('NotificationService - Unit Tests', () {
    test('TC-NOT-001: Positive - Add notification and verify unreadCount', () async {
      expect(service.unreadCount, 0);

      await service.addNotification(
        judul: 'Test Judul',
        pesan: 'Test Pesan',
        tipe: 'info',
      );

      expect(service.unreadCount, 1);
      expect(service.allNotifications.length, 1);
      expect(service.allNotifications.first.judul, 'Test Judul');
    });

    test('TC-NOT-002: Positive - Mark a specific notification as read', () async {
      await service.addNotification(
        judul: 'Notif 1',
        pesan: 'Pesan 1',
        tipe: 'sync',
      );
      
      final notifId = service.allNotifications.first.id;
      expect(service.unreadCount, 1);

      await service.markAsRead(notifId);

      expect(service.unreadCount, 0);
      expect(service.allNotifications.first.isRead, true);
    });

    test('TC-NOT-003: Positive - Mark all notifications as read', () async {
      await service.addNotification(judul: 'A', pesan: 'P1', tipe: 'info');
      await service.addNotification(judul: 'B', pesan: 'P2', tipe: 'info');
      
      expect(service.unreadCount, 2);

      await service.markAllAsRead();

      expect(service.unreadCount, 0);
      expect(service.allNotifications.every((n) => n.isRead), true);
    });

    test('TC-NOT-004: Edge Case - Clear all notifications', () async {
      await service.addNotification(judul: 'A', pesan: 'P1', tipe: 'info');
      expect(service.allNotifications.length, 1);

      await service.clearAll();

      expect(service.allNotifications.length, 0);
      expect(service.unreadCount, 0);
    });

    test('TC-NOT-005: Positive - Notifications are sorted by time (newest first)', () async {
      await service.addNotification(judul: 'Lama', pesan: '...', tipe: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      await service.addNotification(judul: 'Baru', pesan: '...', tipe: 'info');

      final all = service.allNotifications;
      expect(all.length, 2);
      expect(all.first.judul, 'Baru');
      expect(all.last.judul, 'Lama');
    });
  });
}
