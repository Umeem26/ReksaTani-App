import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class IsolateProcessor {
  Future<Map<String, dynamic>> processImageInIsolate(
    String imagePath, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final receivePort = ReceivePort();
    
    final rootToken = RootIsolateToken.instance;

    Isolate? isolate;

    try {
      isolate = await Isolate.spawn(
        _isolateEntryPoint,
        _IsolateData(
          token: rootToken,
          answerPort: receivePort.sendPort,
          imagePath: imagePath,
        ),
        debugName: "PCD_Background_Processor",
      );

      final result = await receivePort.first.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException("Pemrosesan background isolate timeout setelah ${timeout.inSeconds} detik.");
        },
      );

      if (result is Map<String, dynamic>) {
        if (result.containsKey('error')) {
          throw Exception(result['error']);
        }
        return result;
      } else if (result is Exception) {
        throw result;
      } else {
        throw Exception("Gagal menerima format data yang valid dari isolate.");
      }
    } catch (e) {
      debugPrint("🚨 [IsolateProcessor] Error: $e");
      rethrow;
    } finally {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
      debugPrint("🧹 [IsolateProcessor] Isolate cleaned up.");
    }
  }

  static void _isolateEntryPoint(_IsolateData data) async {
    if (data.token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(data.token!);
    }

    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final processedData = {
        'status': 'success',
        'image_path': data.imagePath,
        'ocr_result': {
          'berat': '12.5',
          'harga': '125000',
        },
        'ml_grade': {
          'grade': 'A',
          'confidence': 0.98,
        },
        'warped_path': data.imagePath.replaceAll('.jpg', '_warped.jpg'),
        'processed_at': DateTime.now().toIso8601String(),
      };

      data.answerPort.send(processedData);
    } catch (e) {
      data.answerPort.send({'error': e.toString()});
    }
  }
}

class _IsolateData {
  final RootIsolateToken? token;
  final SendPort answerPort;
  final String imagePath;

  _IsolateData({
    required this.token,
    required this.answerPort,
    required this.imagePath,
  });
}
