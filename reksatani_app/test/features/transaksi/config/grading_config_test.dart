import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reksatani_app/features/transaksi/config/grading_config.dart';
import 'dart:io';

void main() {
  const String testBoxName = GradingConfig.boxName;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('GradingConfig Threshold Tests', () {
    setUp(() async {
      await Hive.openBox(testBoxName);
      final box = Hive.box(testBoxName);
      await box.clear();
    });

    test('Test default thresholds', () {
      expect(GradingConfig.getThreshold('A'), 0.85);
      expect(GradingConfig.getThreshold('B'), 0.75);
      expect(GradingConfig.getThreshold('C'), 0.65);
    });

    test('Test threshold comparison (shouldAccept)', () {
      expect(GradingConfig.shouldAccept('B', 0.76), isTrue);
      expect(GradingConfig.shouldAccept('B', 0.74), isFalse);
      expect(GradingConfig.shouldAccept('A', 0.84), isFalse);
    });

    test('Test boundary cases (confidence == threshold)', () {
      expect(GradingConfig.shouldAccept('A', 0.85), isTrue);
      expect(GradingConfig.shouldAccept('B', 0.75), isTrue);
      expect(GradingConfig.shouldAccept('C', 0.65), isTrue);
    });

    test('Test config persistence after update', () async {
      await GradingConfig.updateThreshold('B', 0.80);
      expect(GradingConfig.getThreshold('B'), 0.80);
      
      expect(GradingConfig.shouldAccept('B', 0.79), isFalse);
      expect(GradingConfig.shouldAccept('B', 0.81), isTrue);
    });

    test('Test audit log generation', () {
      GradingConfig.shouldAccept('A', 0.90);
      GradingConfig.shouldAccept('C', 0.50);

      final logs = GradingConfig.getAuditLogs();
      expect(logs.length, 2);
      expect(logs[0]['is_auto_accepted'], isTrue);
      expect(logs[1]['is_auto_accepted'], isFalse);
      expect(logs[1]['grade_predicted'], 'C');
    });
  });
}
