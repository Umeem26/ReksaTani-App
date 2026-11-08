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

  /// Ambang keyakinan router: di bawah ini hasil dianggap bukan komoditas.
  static const double routerThreshold = 0.25;

  /// Rasio piksel non-latar minimum: di bawah ini frame dianggap kosong.
  static const double minForegroundRatio = 0.01;

  /// Menjalankan pemindaian foto diam (still) dua tahap: router lalu grader.
  ///
  /// Tidak dipakai alur aplikasi lagi: grade ditentukan manusia lewat rubrik.
  /// Melempar [FileSystemException] jika berkas tidak ada. Kesalahan inferensi
  /// dikembalikan sebagai [ScanStatus.error] tanpa grade (tidak pernah default ke A).
  Future<ScanResult> scanImage(File imageFile) => _scanStill(imageFile, runGrader: true);

  /// Saran komoditas dari foto diam: hanya router, model grader tidak dimuat.
  /// Hasilnya tidak pernah membawa grade.
  Future<ScanResult> sarankanKomoditas(File imageFile) => _scanStill(imageFile, runGrader: false);

  Future<ScanResult> _scanStill(File imageFile, {required bool runGrader}) async {
    if (!await imageFile.exists()) {
      throw FileSystemException("Berkas gambar tidak ditemukan", imageFile.path);
    }

    try {
      final bytes = await imageFile.readAsBytes();
      // Preprocessing citra: resize ke 224x224, float RGB [0,255].
      // Model sudah memiliki layer Rescaling(1/255) di dalam graph, jadi JANGAN dibagi 255 lagi.
      final prep = await _preprocessImage(bytes);
      if (_isTestMode) {
        final sim = _simulateInference(prep.tensor);
        return runGrader ? sim : _tanpaGrade(sim);
      }
      return await classify(prep, runGrader: runGrader, source: 'still');
    } catch (e) {
      debugPrint("🚨 [GradingMlService] Terjadi kesalahan saat inferensi grade: $e");
      return ScanResult.error('Kesalahan inferensi lokal ML: $e');
    }
  }

  /// Kompatibilitas lama: hasil [scanImage] dalam bentuk Map.
  Future<Map<String, dynamic>> inferGrade(File imageFile) async {
    return (await scanImage(imageFile)).toMap();
  }

  /// Klasifikasi live dari tensor kamera. Memakai logika keputusan yang sama
  /// dengan foto diam, tetapi tanpa grader (label live hanya butuh komoditas).
  Future<ScanResult> inferFromTensor(PreprocessResult prep) async {
    if (_isTestMode) {
      return _simulateInference(prep.tensor);
    }
    try {
      return await classify(prep, runGrader: false, source: 'live');
    } catch (e) {
      debugPrint("🚨 Error pada inferFromTensor: $e");
      return ScanResult.error('$e');
    }
  }

  /// Satu-satunya fungsi keputusan untuk jalur live dan still.
  Future<ScanResult> classify(PreprocessResult prep, {required bool runGrader, String source = ''}) async {
    final routerInterpreter = await _loadModel(routerModelPath);
    final routerScores = _run(routerInterpreter, prep.tensor, routerClasses.length);
    if (kDebugMode) {
      debugPrint('[ROUTER $source] ${_formatScores(routerScores)} fg=${prep.foregroundRatio.toStringAsFixed(3)}');
    }

    final decision = decideCommodity(routerScores, prep.foregroundRatio);
    if (decision.status != ScanStatus.ok || !runGrader) {
      return decision;
    }

    final graderInterpreter = await _loadModel(_graderPathFor(decision.commodity!));
    final graderScores = _run(graderInterpreter, prep.tensor, gradeClasses.length);
    final gradeIdx = _argmax(graderScores);

    return ScanResult(
      status: ScanStatus.ok,
      commodity: decision.commodity,
      grade: gradeClasses[gradeIdx],
      routerConfidence: decision.routerConfidence,
      gradeConfidence: graderScores[gradeIdx],
      routerScores: routerScores,
      gradeScores: graderScores,
      inferenceMode: 'native_tflite_full_pipeline',
    );
  }

  /// Keputusan router murni (tanpa I/O) agar bisa diuji: argmax atas SEMUA kelas
  /// (termasuk kelas 0 bukan_komoditas), lalu ambang router dan cek foreground.
  ScanResult decideCommodity(List<double> routerScores, double foregroundRatio) {
    final idx = _argmax(routerScores);
    final score = routerScores[idx];
    final label = routerClasses[idx];

    String? reason;
    if (label == 'bukan_komoditas') {
      reason = 'Router: bukan komoditas';
    } else if (score < routerThreshold) {
      reason = 'Keyakinan router terlalu rendah (${(score * 100).toStringAsFixed(1)}%)';
    } else if (foregroundRatio < minForegroundRatio) {
      reason = 'Rasio foreground terlalu kecil (${(foregroundRatio * 100).toStringAsFixed(1)}%)';
    }

    if (reason != null) {
      return ScanResult(
        status: ScanStatus.notCommodity,
        routerConfidence: score,
        routerScores: routerScores,
        message: reason,
        inferenceMode: 'native_tflite_router_only',
      );
    }
    return ScanResult(
      status: ScanStatus.ok,
      commodity: label,
      routerConfidence: score,
      routerScores: routerScores,
      inferenceMode: 'native_tflite_router_only',
    );
  }

  String _graderPathFor(String commodity) {
    switch (commodity) {
      case 'gabah':
        return gabahModelPath;
      case 'kelapa_sawit':
        return sawitModelPath;
      case 'kopi':
        return kopiModelPath;
    }
    throw Exception("Grader untuk komoditas $commodity belum tersedia.");
  }

  /// Menjalankan model dengan input ByteBuffer (shape [1,224,224,3] tetap) dan output [1,n].
  List<double> _run(Interpreter interpreter, Float32List input, int numClasses) {
    final output = List<double>.filled(numClasses, 0.0).reshape([1, numClasses]);
    interpreter.run(input.buffer, output);
    return List<double>.from(output[0] as List);
  }

  static int _argmax(List<double> v) {
    int best = 0;
    for (int i = 1; i < v.length; i++) {
      if (v[i] > v[best]) best = i;
    }
    return best;
  }

  /// Tensor kamera + rasio foreground dengan aturan yang sama seperti jalur still.
  PreprocessResult prepareCameraImage(CameraImage image) {
    final tensor = convertCameraImageToTensor(image);
    return PreprocessResult(tensor, foregroundRatioOf(tensor));
  }

  /// Rasio piksel yang bukan latar putih (salah satu kanal < 240), sama dengan preprocessing still.
  static double foregroundRatioOf(Float32List rgb) {
    int fg = 0;
    final int pixels = rgb.length ~/ 3;
    for (int i = 0; i < rgb.length; i += 3) {
      if (rgb[i] < 240 || rgb[i + 1] < 240 || rgb[i + 2] < 240) fg++;
    }
    return pixels == 0 ? 0.0 : fg / pixels;
  }

  /// Mengonversi format CameraImage (YUV420/BGRA) ke tensor 224x224 float RGB [0,255] (NHWC, flat).
  /// Saat menjalankan model, kirim `tensor.buffer` (ByteBuffer) agar shape input [1,224,224,3] tidak di-resize.
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
          final double r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toDouble();
          final double g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).clamp(0, 255).toDouble();
          final double b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toDouble();

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
            buffer[bufferIdx++] = bytes[index + 2].toDouble();
            buffer[bufferIdx++] = bytes[index + 1].toDouble();
            buffer[bufferIdx++] = bytes[index].toDouble();
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

  String _formatScores(List<double> scores) {
    final parts = <String>[];
    for (int i = 0; i < scores.length && i < routerClasses.length; i++) {
      parts.add('${routerClasses[i]}=${scores[i].toStringAsFixed(4)}');
    }
    return parts.join(' ');
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
        final double r = rgbaBytes[offset].toDouble();
        final double g = rgbaBytes[offset + 1].toDouble();
        final double b = rgbaBytes[offset + 2].toDouble();
        
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
          final double r = pixel.r.toDouble();
          final double g = pixel.g.toDouble();
          final double b = pixel.b.toDouble();

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

  static ScanResult _tanpaGrade(ScanResult r) => ScanResult(
        status: r.status,
        commodity: r.commodity,
        routerConfidence: r.routerConfidence,
        routerScores: r.routerScores,
        message: r.message,
        inferenceMode: r.inferenceMode,
      );

  /// Simulasi untuk test mode (heuristik warna, bukan model sungguhan).
  ScanResult _simulateInference(Float32List input) {
    double totalR = 0;
    double totalG = 0;
    double totalB = 0;
    int count = 0;
    for (int i = 0; i + 2 < input.length; i += 30) {
      totalR += input[i];
      totalG += input[i + 1];
      totalB += input[i + 2];
      count++;
    }
    final double avgR = count == 0 ? 0 : totalR / count;
    final double avgG = count == 0 ? 0 : totalG / count;
    final double avgB = count == 0 ? 0 : totalB / count;

    String mockGrade = 'B';
    List<double> mockScores = [0.12, 0.78, 0.10];
    if (avgG > avgR * 1.3 && avgG > avgB * 1.3) {
      mockGrade = 'A';
      mockScores = [0.88, 0.08, 0.04];
    } else if (avgR > avgG * 1.5 && avgR > avgB * 1.5) {
      mockGrade = 'C';
      mockScores = [0.05, 0.10, 0.85];
    }

    return ScanResult(
      status: ScanStatus.ok,
      commodity: 'gabah',
      grade: mockGrade,
      routerConfidence: 1.0,
      gradeConfidence: mockScores[gradeClasses.indexOf(mockGrade)],
      routerScores: const [0.0, 1.0, 0.0, 0.0],
      gradeScores: mockScores,
      inferenceMode: 'simulated',
    );
  }
}

class PreprocessResult {
  final Float32List tensor;
  final double foregroundRatio;
  PreprocessResult(this.tensor, this.foregroundRatio);
}

/// Status eksplisit hasil pemindaian. Tidak ada grade default: [ScanResult.grade]
/// hanya terisi bila grader benar-benar berjalan.
enum ScanStatus { ok, lowConfidence, notCommodity, error }

class ScanResult {
  final ScanStatus status;

  /// Label router: 'gabah' | 'kelapa_sawit' | 'kopi', atau null.
  final String? commodity;

  /// 'A' | 'B' | 'C', atau null bila grader tidak berjalan / gagal.
  final String? grade;
  final double routerConfidence;
  final double gradeConfidence;
  final List<double> routerScores;
  final List<double> gradeScores;
  final String? message;
  final String inferenceMode;

  const ScanResult({
    required this.status,
    this.commodity,
    this.grade,
    this.routerConfidence = 0.0,
    this.gradeConfidence = 0.0,
    this.routerScores = const [],
    this.gradeScores = const [],
    this.message,
    this.inferenceMode = '',
  });

  factory ScanResult.error(String message) =>
      ScanResult(status: ScanStatus.error, message: message, inferenceMode: 'error');

  bool get isAccepted => status == ScanStatus.ok && commodity != null && grade != null;

  ScanResult withStatus(ScanStatus newStatus) => ScanResult(
        status: newStatus,
        commodity: commodity,
        grade: grade,
        routerConfidence: routerConfidence,
        gradeConfidence: gradeConfidence,
        routerScores: routerScores,
        gradeScores: gradeScores,
        message: message,
        inferenceMode: inferenceMode,
      );

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'commodity': commodity,
        'komoditas': commodity,
        'grade': grade,
        'confidence': gradeConfidence,
        'router_confidence': routerConfidence,
        'scores': {
          for (int i = 0; i < gradeScores.length && i < 3; i++) ['A', 'B', 'C'][i]: gradeScores[i],
        },
        'inference_mode': inferenceMode,
      };

  @override
  String toString() =>
      'ScanResult($status, commodity: $commodity, grade: $grade, router: ${routerConfidence.toStringAsFixed(3)}, '
      'grade: ${gradeConfidence.toStringAsFixed(3)}, msg: $message)';
}
