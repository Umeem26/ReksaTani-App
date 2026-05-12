import 'package:flutter/foundation.dart';
import '../models/hive/notifikasi_hive_model.dart';
import 'hive_service.dart';
import 'package:uuid/uuid.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _hive = HiveService();
  final _uuid = const Uuid();

  List<NotifikasiHiveModel> get allNotifications => 
      _hive.notifikasiBox.values.toList()..sort((a, b) => b.waktu.compareTo(a.waktu));

  int get unreadCount => 
      _hive.notifikasiBox.values.where((n) => !n.isRead).length;

  Future<void> addNotification({
    required String judul,
    required String pesan,
    required String tipe,
  }) async {
    final notif = NotifikasiHiveModel(
      id: _uuid.v4(),
      judul: judul,
      pesan: pesan,
      waktu: DateTime.now(),
      tipe: tipe,
    );
    await _hive.notifikasiBox.put(notif.id, notif);
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final notif = _hive.notifikasiBox.get(id);
    if (notif != null) {
      notif.isRead = true;
      await notif.save();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var notif in _hive.notifikasiBox.values) {
      if (!notif.isRead) {
        notif.isRead = true;
        await notif.save();
      }
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _hive.notifikasiBox.clear();
    notifyListeners();
  }
}
