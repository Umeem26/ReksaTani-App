import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class GradingConfig {
  static const String boxName = 'grading_config_box';
  
  static const String keyThresholdA = 'threshold_a';
  static const String keyThresholdB = 'threshold_b';
  static const String keyThresholdC = 'threshold_c';
  static const String keyAuditLog = 'grading_audit_log';

  static const double defaultThresholdA = 0.85;
  static const double defaultThresholdB = 0.75;
  static const double defaultThresholdC = 0.65;

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  static double getThreshold(String grade) {
    final box = Hive.box(boxName);
    switch (grade.toUpperCase()) {
      case 'A':
        return box.get(keyThresholdA, defaultValue: defaultThresholdA);
      case 'B':
        return box.get(keyThresholdB, defaultValue: defaultThresholdB);
      case 'C':
        return box.get(keyThresholdC, defaultValue: defaultThresholdC);
      default:
        return 0.75;
    }
  }

  static bool shouldAccept(String grade, double confidence) {
    final threshold = getThreshold(grade);
    final isAccepted = confidence >= threshold;
    
    _logDecision(grade, confidence, threshold, isAccepted);
    
    return isAccepted;
  }

  static void _logDecision(String grade, double confidence, double threshold, bool isAccepted) {
    final box = Hive.box(boxName);
    final List logs = box.get(keyAuditLog, defaultValue: []);
    
    final newEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'grade_predicted': grade,
      'confidence': confidence,
      'threshold_applied': threshold,
      'is_auto_accepted': isAccepted,
    };

    logs.add(newEntry);
    
    if (logs.length > 100) {
      logs.removeAt(0);
    }
    
    box.put(keyAuditLog, logs);
    debugPrint("📊 [GradingConfig] Decision Logged: Predicted $grade (${(confidence * 100).toStringAsFixed(1)}%) vs Threshold ${(threshold * 100).toStringAsFixed(1)}% -> Accepted: $isAccepted");
  }

  static Future<void> updateThreshold(String grade, double newValue) async {
    final box = Hive.box(boxName);
    switch (grade.toUpperCase()) {
      case 'A':
        await box.put(keyThresholdA, newValue);
        break;
      case 'B':
        await box.put(keyThresholdB, newValue);
        break;
      case 'C':
        await box.put(keyThresholdC, newValue);
        break;
    }
  }

  static List<Map<dynamic, dynamic>> getAuditLogs() {
    final box = Hive.box(boxName);
    final List logs = box.get(keyAuditLog, defaultValue: []);
    return logs.map((e) => e as Map<dynamic, dynamic>).toList();
  }
}
