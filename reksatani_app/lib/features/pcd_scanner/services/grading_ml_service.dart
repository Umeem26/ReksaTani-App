import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';

/// Service untuk melakukan grading otomatis Multi-Komoditas menggunakan TensorFlow Lite.
/// Menggunakan Arsitektur 2 Tahap (Router Model -> Expert Grader Model).
class GradingMlService {
  // 1. Path untuk semua model yang dibutuhkan
  static const String routerModelPath = 'assets/models/router_model.tflite';
  static const String gabahModelPath = 'assets/models/gabah_grader.tflite';
  static const String sawitModelPath = 'assets/models/kelapa_sawit_grader.tflite';
  static const String kopiModelPath = 'assets/models/kopi_grader.tflite';

  // Menyimpan interpreter yang sedang aktif agar tidak diload berulang kali
  final Map<String, Interpreter> _interpreters = {};
  final bool _isTestMode;
  bool _isModelLoaded = false;

  // 2. Definisi urutan kelas (SANGAT PENTING: Harus sama persis dengan urutan alfabet di Colab)
  final List<String> routerClasses = ['bukan_komoditas', 'gabah', 'kelapa_sawit', 'kopi'];
  final List<String> gradeClasses = ['A', 'B', 'C'];

  GradingMlService({
    bool isTestMode = false,
  }) : _isTestMode = isTestMode;

  /// Memuat model router default pada saat inisialisasi awal.
  Future<void> loadModel() async {
    _isModelLoaded = true;
    if (_isTestMode) return;
    await _loadModel(routerModelPath);
  }

  /// Getter untuk mengecek apakah setidaknya model router (atau model apapun) sudah dimuat.
  bool get isModelLoaded => _isModelLoaded || _interpreters.isNotEmpty;

  /// Fungsi dinamis untuk memuat model TFLite sesuai kebutuhan (Lazy Loading).
  Future<Interpreter> _loadModel(String path) async {
    // Jika model sudah dimuat sebelumnya, gunakan yang ada di cache memori
    if (_interpreters.containsKey(path)) {
      return _interpreters[path]!;
    }

    try {
      final options = InterpreterOptions();
      // Opsi untuk GPU Delegate bisa diaktifkan di sini jika dibutuhkan di masa depan
      // options.addDelegate(GpuDelegateV2()); 
      
      final interpreter = await Interpreter.fromAsset(path, options: options);
      _interpreters[path] = interpreter;
      debugPrint("🚀 [GradingMlService] Model TFLite '$path' berhasil dimuat ke memori.");
      
      return interpreter;
    } catch (e) {
      debugPrint("🚨 [GradingMlService] Gagal memuat model '$path': $e");
      throw Exception("Gagal memuat model ML. Pastikan file $path ada di folder assets/models/.");
    }
  }

  /// Melakukan inferensi Dua-Tahap.
  /// Menerima parameter [imageFile] dan mengembalikan map hasil berupa status komoditas, grade, dan confidence.
  Future<Map<String, dynamic>> inferGrade(File imageFile) async {
    if (!await imageFile.exists()) {
      throw FileSystemException("Berkas gambar tidak ditemukan", imageFile.path);
    }

    try {
      final bytes = await imageFile.readAsBytes();
      
      // Preprocessing Citra (Resize ke 224x224 dan Normalisasi 1./255)
      final prepResult = await _preprocessImage(bytes);
      final inputTensor = prepResult.tensor;

      if (_isTestMode) {
        return _simulateInference(inputTensor);
      }

      // ==========================================================
      // TAHAP 1: JALANKAN ROUTER MODEL (Saringan Komoditas)
      // ==========================================================
      final routerInterpreter = await _loadModel(routerModelPath);
      var routerOutput = List<double>.filled(4, 0.0).reshape([1, 4]); // 4 Kelas Router
      
      routerInterpreter.run(inputTensor, routerOutput);
      List<double> routerScores = List<double>.from(routerOutput[0]);

      // Cari tebakan komoditas dengan confidence tertinggi
      int routerMaxIdx = 0;
      double routerMaxScore = -1.0;
      for (int i = 0; i < routerScores.length; i++) {
        if (routerScores[i] > routerMaxScore) {
          routerMaxScore = routerScores[i];
          routerMaxIdx = i;
        }
      }

      String detectedKomoditas = routerClasses[routerMaxIdx];

      // Jika keyakinan router terlalu rendah, degradasi ke bukan_komoditas untuk menghindari false positive (dibuat lebih sensitif di 0.25)
      double routerThreshold = 0.25;
      if (detectedKomoditas != 'bukan_komoditas' && routerMaxScore < routerThreshold) {
        debugPrint("🛑 [GradingMlService] Objek didegradasi ke 'bukan_komoditas' karena keyakinan router terlalu rendah (${(routerMaxScore * 100).toStringAsFixed(1)}% < ${(routerThreshold * 100).toStringAsFixed(1)}%)");
        detectedKomoditas = 'bukan_komoditas';
      }

      // ─── FOREGROUND RATIO CHECK (EMPTY FRAME DETECTION) ───
      if (prepResult.foregroundRatio < 0.01) {
        debugPrint("🛑 [GradingMlService] Objek didegradasi ke 'bukan_komoditas' karena rasio foreground terlalu kecil (${(prepResult.foregroundRatio * 100).toStringAsFixed(1)}% < 1.0%)");
        detectedKomoditas = 'bukan_komoditas';
      }

      // Jika terdeteksi sebagai BUKAN KOMODITAS, langsung hentikan proses dan kembalikan hasil
      if (detectedKomoditas == 'bukan_komoditas') {
        debugPrint("🛑 [GradingMlService] Objek ditolak: Bukan Komoditas (Keyakinan: ${(routerMaxScore * 100).toStringAsFixed(1)}%)");
        return {
          'komoditas': 'Bukan Komoditas',
          'grade': 'Bukan Komoditas', // Nilai ini akan dibaca oleh PcdController
          'confidence': 0.0,
          'scores': {
            'A': 0.0,
            'B': 0.0,
            'C': 0.0,
          },
          'inference_mode': 'native_tflite_router_only',
        };
      }

      debugPrint("✅ [GradingMlService] Terdeteksi sebagai '$detectedKomoditas'. Memasuki Tahap 2 (Grading)...");

      // ==========================================================
      // TAHAP 2: JALANKAN EXPERT GRADER MODEL SESUAI KOMODITAS
      // ==========================================================
      String graderPath;
      if (detectedKomoditas == 'gabah') {
        graderPath = gabahModelPath;
      } else if (detectedKomoditas == 'kelapa_sawit') {
        graderPath = sawitModelPath;
      } else if (detectedKomoditas == 'kopi') {
        graderPath = kopiModelPath;
      } else {
        throw Exception("Grader untuk komoditas $detectedKomoditas belum tersedia.");
      }

      final graderInterpreter = await _loadModel(graderPath);
      var graderOutput = List<double>.filled(3, 0.0).reshape([1, 3]); // 3 Kelas (A/B/C)

      graderInterpreter.run(inputTensor, graderOutput);
      List<double> graderScores = List<double>.from(graderOutput[0]);

      // Cari grade (A/B/C) dengan confidence tertinggi
      int gradeMaxIdx = 0;
      double gradeMaxScore = -1.0;
      for (int i = 0; i < graderScores.length; i++) {
        if (graderScores[i] > gradeMaxScore) {
          gradeMaxScore = graderScores[i];
          gradeMaxIdx = i;
        }
      }

      String finalGrade = gradeClasses[gradeMaxIdx];

      return {
        'komoditas': detectedKomoditas,
        'grade': finalGrade, // Output akhirnya adalah A, B, atau C
        'confidence': gradeMaxScore,
        'scores': {
          'A': graderScores[0],
          'B': graderScores[1],
          'C': graderScores[2],
        },
        'inference_mode': 'native_tflite_full_pipeline',
      };
    } catch (e) {
      debugPrint("🚨 [GradingMlService] Terjadi kesalahan saat inferensi grade: $e");
      throw Exception("Kesalahan inferensi lokal ML: $e");
    }
  }

  /// Memproses klasifikasi komoditas secara real-time langsung dari camera image stream.
  Future<Map<String, dynamic>> inferFromTensor(dynamic inputTensor) async {
    if (_isTestMode) {
      return _simulateInference(inputTensor);
    }
    
    try {
      // TAHAP 1: JALANKAN ROUTER MODEL
      final routerInterpreter = await _loadModel(routerModelPath);
      var routerOutput = List<double>.filled(4, 0.0).reshape([1, 4]);
      routerInterpreter.run(inputTensor, routerOutput);
      List<double> routerScores = List<double>.from(routerOutput[0]);
      
      int routerMaxIdx = 1; // Mulai dari indeks 1 (gabah)
      double routerMaxScore = routerScores[1];
      for (int i = 2; i < routerScores.length; i++) {
        if (routerScores[i] > routerMaxScore) {
          routerMaxScore = routerScores[i];
          routerMaxIdx = i;
        }
      }

      debugPrint("📊 [GradingMlService] Live Router: bukan_komoditas: ${(routerScores[0] * 100).toStringAsFixed(1)}%, "
          "gabah: ${(routerScores[1] * 100).toStringAsFixed(1)}%, "
          "sawit: ${(routerScores[2] * 100).toStringAsFixed(1)}%, "
          "kopi: ${(routerScores[3] * 100).toStringAsFixed(1)}%");
      
      String detectedKomoditas = routerClasses[routerMaxIdx];
      
      // TAHAP 2: JALANKAN EXPERT GRADER MODEL
      String graderPath;
      if (detectedKomoditas == 'gabah') {
        graderPath = gabahModelPath;
      } else if (detectedKomoditas == 'kelapa_sawit') {
        graderPath = sawitModelPath;
      } else if (detectedKomoditas == 'kopi') {
        graderPath = kopiModelPath;
      } else {
        throw Exception("Grader tidak ditemukan");
      }
      
      final graderInterpreter = await _loadModel(graderPath);
      var graderOutput = List<double>.filled(3, 0.0).reshape([1, 3]);
      graderInterpreter.run(inputTensor, graderOutput);
      List<double> graderScores = List<double>.from(graderOutput[0]);
      
      int gradeMaxIdx = 0;
      double gradeMaxScore = -1.0;
      for (int i = 0; i < graderScores.length; i++) {
        if (graderScores[i] > gradeMaxScore) {
          gradeMaxScore = graderScores[i];
          gradeMaxIdx = i;
        }
      }
      
      return {
        'commodity': detectedKomoditas,
        'grade': gradeClasses[gradeMaxIdx],
        'confidence': gradeMaxScore,
        'scores': {
          'gabah': routerScores[1],
          'kopi robusta': routerScores[3],
          'sawit': routerScores[2],
        },
        'inference_mode': 'live_full_pipeline',
      };
    } catch (e) {
      debugPrint("🚨 Error pada inferFromTensor: $e");
      return {
        'commodity': 'Menganalisis...',
        'grade': 'A',
        'confidence': 0.0,
        'scores': {'gabah': 0.0, 'kopi robusta': 0.0, 'sawit': 0.0},
        'inference_mode': 'error',
      };
    }
  }

  /// Mengonversi format CameraImage (YUV420/BGRA) ke tensor format 224x224 RGB ternormalisasi secara efisien.
  Float32List convertCameraImageToTensor(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final bool isLandscape = width > height;
    final Float32List buffer = Float32List(150528);
    int bufferIdx = 0;

    if (image.format.group == ImageFormatGroup.yuv420) {
      final yPlane = image.planes[0];
      final uPlane = image.planes.length > 1 ? image.planes[1] : null;
      final vPlane = image.planes.length > 2 ? image.planes[2] : null;

      final yBytes = yPlane.bytes;
      final uBytes = uPlane?.bytes;
      final vBytes = vPlane?.bytes;

      final int yRowStride = yPlane.bytesPerRow;
      final int uRowStride = uPlane?.bytesPerRow ?? 0;
      final int vRowStride = vPlane?.bytesPerRow ?? 0;

      final int? uPixelStride = uPlane?.bytesPerPixel;
      final int? vPixelStride = vPlane?.bytesPerPixel;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          int sx, sy;
          if (isLandscape) {
            sy = ((223 - x) * height ~/ 224).clamp(0, height - 1);
            sx = (y * width ~/ 224).clamp(0, width - 1);
          } else {
            sx = (x * width ~/ 224).clamp(0, width - 1);
            sy = (y * height ~/ 224).clamp(0, height - 1);
          }

          final int yIndex = sy * yRowStride + sx;
          final int uvY = sy >> 1;
          final int uvX = sx >> 1;

          final int yVal = yBytes[yIndex];

          int uVal = 128;
          int vVal = 128;

          if (uBytes != null && uPixelStride != null) {
            final int uIndex = uvY * uRowStride + uvX * uPixelStride;
            if (uIndex < uBytes.length) uVal = uBytes[uIndex];
          }
          if (vBytes != null && vPixelStride != null) {
            final int vIndex = uvY * vRowStride + uvX * vPixelStride;
            if (vIndex < vBytes.length) vVal = vBytes[vIndex];
          }

          // Konversi YUV ke RGB
          final double r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255) / 255.0;
          final double g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).clamp(0, 255) / 255.0;
          final double b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255) / 255.0;

          buffer[bufferIdx++] = r;
          buffer[bufferIdx++] = g;
          buffer[bufferIdx++] = b;
        }
      }
      return buffer;
    } else {
      // Format BGRA (iOS)
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final int rowStride = plane.bytesPerRow;
      final int pixelStride = plane.bytesPerPixel ?? 4;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          int sx, sy;
          if (isLandscape) {
            sy = ((223 - x) * height ~/ 224).clamp(0, height - 1);
            sx = (y * width ~/ 224).clamp(0, width - 1);
          } else {
            sx = (x * width ~/ 224).clamp(0, width - 1);
            sy = (y * height ~/ 224).clamp(0, height - 1);
          }

          final int index = sy * rowStride + sx * pixelStride;
          if (index + 2 < bytes.length) {
            buffer[bufferIdx++] = bytes[index + 2] / 255.0;
            buffer[bufferIdx++] = bytes[index + 1] / 255.0;
            buffer[bufferIdx++] = bytes[index] / 255.0;
          } else {
            buffer[bufferIdx++] = 0.0;
            buffer[bufferIdx++] = 0.0;
            buffer[bufferIdx++] = 0.0;
          }
        }
      }
      return buffer;
    }
  }

  /// Membersihkan memori semua interpreter saat service tidak lagi digunakan.
  void dispose() {
    for (var interpreter in _interpreters.values) {
      interpreter.close();
    }
    _interpreters.clear();
    debugPrint("🧹 [GradingMlService] Semua sumber daya interpreter berhasil dibersihkan.");
  }

  /// Melakukan preprocessing citra secara efisien.
  Future<PreprocessResult> _preprocessImage(Uint8List bytes) async {
    try {
      return await _preprocessImageNative(bytes);
    } catch (e) {
      debugPrint("⚠️ [GradingMlService] Native image preprocessing gagal. Fallback ke pure Dart...");
      return await compute(_preprocessImagePureDart, bytes);
    }
  }

  Future<PreprocessResult> _preprocessImageNative(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 224, targetHeight: 224);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    final int actualWidth = uiImage.width;
    final int actualHeight = uiImage.height;

    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Gagal mendapatkan byte data dari ui.Image");

    final Uint8List rgbaBytes = byteData.buffer.asUint8List();
    final Float32List buffer = Float32List(150528);
    int bufferIdx = 0;
    int foregroundPixels = 0;

    for (int y = 0; y < actualHeight; y++) {
      for (int x = 0; x < actualWidth; x++) {
        final int offset = (y * actualWidth + x) * 4;
        final double r = rgbaBytes[offset] / 255.0;
        final double g = rgbaBytes[offset + 1] / 255.0;
        final double b = rgbaBytes[offset + 2] / 255.0;
        
        buffer[bufferIdx++] = r;
        buffer[bufferIdx++] = g;
        buffer[bufferIdx++] = b;

        // Cek apakah bukan warna putih latar belakang (R, G, B tidak semuanya dekat 255)
        if (rgbaBytes[offset] < 240 || rgbaBytes[offset + 1] < 240 || rgbaBytes[offset + 2] < 240) {
          foregroundPixels++;
        }
      }
    }

    final double foregroundRatio = foregroundPixels / (actualWidth * actualHeight);
    uiImage.dispose();

    return PreprocessResult(buffer, foregroundRatio);
  }

  static PreprocessResult _preprocessImagePureDart(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Gagal mendekode berkas gambar.");
    final resized = img.copyResize(image, width: 224, height: 224);

    final Float32List buffer = Float32List(150528);
    int bufferIdx = 0;
    int foregroundPixels = 0;
    final iterator = resized.iterator;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        if (iterator.moveNext()) {
          final pixel = iterator.current;
          final double r = pixel.r / 255.0;
          final double g = pixel.g / 255.0;
          final double b = pixel.b / 255.0;

          buffer[bufferIdx++] = r;
          buffer[bufferIdx++] = g;
          buffer[bufferIdx++] = b;

          if (pixel.r < 240 || pixel.g < 240 || pixel.b < 240) {
            foregroundPixels++;
          }
        } else {
          buffer[bufferIdx++] = 0.0;
          buffer[bufferIdx++] = 0.0;
          buffer[bufferIdx++] = 0.0;
        }
      }
    }

    final double foregroundRatio = foregroundPixels / 50176;
    return PreprocessResult(buffer, foregroundRatio);
  }

  /// Simulasi logika inferensi (tidak diubah)
  Map<String, dynamic> _simulateInference(dynamic input) {
    double totalR = 0;
    double totalG = 0;
    double totalB = 0;
    int count = 0;
    
    if (input is Float32List) {
      for (int i = 0; i < input.length; i += 30) {
        totalR += input[i];
        totalG += input[i + 1];
        totalB += input[i + 2];
        count++;
      }
    } else {
      // Fallback/Legacy
      final List<List<List<List<double>>>> inputList = input;
      for (int y = 0; y < inputList[0].length; y += 10) {
        for (int x = 0; x < inputList[0][y].length; x += 10) {
          totalR += inputList[0][y][x][0];
          totalG += inputList[0][y][x][1];
          totalB += inputList[0][y][x][2];
          count++;
        }
      }
    }
    
    double avgR = totalR / count;
    double avgG = totalG / count;
    double avgB = totalB / count;

    String mockGrade = 'B';
    double mockConfidence = 0.78;
    Map<String, double> mockScores = {'A': 0.12, 'B': 0.78, 'C': 0.10};

    // Logika kustom berdasarkan warna mock
    if (avgG > avgR * 1.3 && avgG > avgB * 1.3) {
      mockGrade = 'A';
      mockConfidence = 0.88;
      mockScores = {'A': 0.88, 'B': 0.08, 'C': 0.04};
    } else if (avgR > avgG * 1.5 && avgR > avgB * 1.5) {
      mockGrade = 'C';
      mockConfidence = 0.85;
      mockScores = {'A': 0.05, 'B': 0.10, 'C': 0.85};
    }

    return {
      'komoditas': 'gabah',
      'grade': mockGrade,
      'confidence': mockConfidence,
      'scores': mockScores,
      'inference_mode': 'simulated',
    };
  }
}

class PreprocessResult {
  final Float32List tensor;
  final double foregroundRatio;
  PreprocessResult(this.tensor, this.foregroundRatio);
}
