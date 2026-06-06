import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/image_brightness_service.dart';
import '../services/confidence_validator.dart'; // 👈 Modul 10
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../../../shared/widgets/app_theme.dart';
import '../controllers/pcd_controller.dart';

class PcdCameraScreen extends StatefulWidget {
  final String? initialFotoNota;
  final String? initialFotoBarang;

  const PcdCameraScreen({
    super.key,
    this.initialFotoNota,
    this.initialFotoBarang,
  });

  @override
  State<PcdCameraScreen> createState() => _PcdCameraScreenState();
}

// 🛠️ REVISI: TickerProviderStateMixin dihapus karena kita sudah tidak butuh animasi garis
class _PcdCameraScreenState extends State<PcdCameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _showLiveCamera = false; 

  int _step = 0; 
  String? _fotoNotaPath;
  String? _fotoBarangPath;

  final PcdController _pcdController = PcdController();
  final ImageBrightnessService _brightnessService = ImageBrightnessService();

  // ─── VARIABEL INOVASI REAL-TIME STREAM ───
  bool _isProcessingFrame = false;
  String _liveLightingStatus = "Menghitung...";
  Color _liveLightingColor = Colors.grey;
  String _liveDetectedObject = "Mencari objek...";
  List<Offset>? _detectedCorners;
  List<Offset>? _detectedNotaCorners;

  // ─── TFLITE LIVE CLASSIFICATION ───
  int _lastInferenceTime = 0;
  String _tfliteLabel = "Mencari objek...";
  double _tfliteConfidence = 0.0;

  // ─── KONTROL PERANGKAT HARDWARE ───
  bool _isFlashOn = false;
  bool _isBackCamera = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _fotoNotaPath = widget.initialFotoNota;
    _fotoBarangPath = widget.initialFotoBarang;

    _initCamera();
    _pcdController.loadModel(); // 👈 Memuat model ML lebih awal
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        final targetLens = _isBackCamera ? CameraLensDirection.back : CameraLensDirection.front;
        final selectedCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == targetLens,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.high, 
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        );

        await _cameraController!.initialize();
        
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;

        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error inisialisasi kamera: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint("Gagal mengontrol senter hardware: $e");
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    
    _stopLiveStream();
    
    // 🛠️ FIX ERROR MERAH: Ubah status UI DULU agar layar menampilkan loading,
    // BARU mematikan mesin kamera di belakang layar. Ini mencegah red screen of death!
    setState(() {
      _isCameraInitialized = false;
      _isBackCamera = !_isBackCamera;
    });

    await _cameraController?.dispose();
    await _initCamera(); 

    if (_showLiveCamera) {
      _startLiveStream();
    }
  }

  void _startLiveStream() {
    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;

        try {
          final bytes = image.planes[0].bytes;
          final frameW = image.width;
          final frameH = image.height;
          final bytesPerRow = image.planes[0].bytesPerRow;

          // 1. Hitung rata-rata kecerahan untuk luma (Lompati piksel agar sangat cepat)
          int totalLuma = 0;
          int countLuma = 0;
          for (int y = 0; y < frameH; y += 8) {
            for (int x = 0; x < frameW; x += 8) {
              totalLuma += bytes[y * bytesPerRow + x];
              countLuma++;
            }
          }
          final int luma = countLuma > 0 ? totalLuma ~/ countLuma : 127;

          String lightStatus;
          Color lightColor;
          String detectedObj = "Menganalisis...";
          List<Offset>? newCorners;

          if (luma < 60) {
            lightStatus = "TERLALU GELAP";
            lightColor = AppTheme.merah;
            detectedObj = "Cahaya kurang, objek blur";
          } else if (luma > 210) {
            lightStatus = "TERLALU TERANG";
            lightColor = AppTheme.kuning;
            detectedObj = "Awas pantulan cahaya (silau)";
          } else {
            lightStatus = "PENCAHAYAAN IDEAL";
            lightColor = AppTheme.hijauMuda;
            detectedObj = _step == 0 ? "Sejajarkan nota di area kamera" : "Arahkan kamera ke Komoditas";
          }

          if (_step == 0) {
            // 2. Deteksi sudut nota real-time HANYA jika step == 0
            int minVal = 255;
            int maxVal = 0;
            const int gridR = 15;
            const int gridC = 15;
            final double stepX = frameW / gridC;
            final double stepY = frameH / gridR;

            for (int gy = 0; gy < gridR; gy++) {
              for (int gx = 0; gx < gridC; gx++) {
                int fx = (gx * stepX).round().clamp(0, frameW - 1);
                int fy = (gy * stepY).round().clamp(0, frameH - 1);
                int val = bytes[fy * bytesPerRow + fx];
                if (val < minVal) minVal = val;
                if (val > maxVal) maxVal = val;
              }
            }

            int threshold = (minVal + maxVal) ~/ 2 + 10;
            if (threshold < 70) threshold = 70;

            final densities = List.generate(gridR, (_) => List.filled(gridC, 0));
            for (int gy = 0; gy < gridR; gy++) {
              for (int gx = 0; gx < gridC; gx++) {
                int count = 0;
                for (int dy = 0; dy < 2; dy++) {
                  for (int dx = 0; dx < 2; dx++) {
                    int fx = ((gx + dx * 0.5) * stepX).round().clamp(0, frameW - 1);
                    int fy = ((gy + dy * 0.5) * stepY).round().clamp(0, frameH - 1);
                    if (bytes[fy * bytesPerRow + fx] >= threshold) {
                      count++;
                    }
                  }
                }
                densities[gy][gx] = count;
              }
            }

            final isDense = List.generate(gridR, (_) => List.filled(gridC, false));
            for (int r = 0; r < gridR; r++) {
              for (int c = 0; c < gridC; c++) {
                if (densities[r][c] >= 2) {
                  isDense[r][c] = true;
                }
              }
            }

            final visited = List.generate(gridR, (_) => List.filled(gridC, false));
            List<List<int>> largestComp = [];
            for (int r = 0; r < gridR; r++) {
              for (int c = 0; c < gridC; c++) {
                if (isDense[r][c] && !visited[r][c]) {
                  final List<List<int>> comp = [];
                  final List<List<int>> queue = [[r, c]];
                  visited[r][c] = true;
                  while (queue.isNotEmpty) {
                    final curr = queue.removeAt(0);
                    comp.add(curr);
                    final currR = curr[0];
                    final currC = curr[1];
                    final dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
                    for (final d in dirs) {
                      final nr = currR + d[0];
                      final nc = currC + d[1];
                      if (nr >= 0 && nr < gridR && nc >= 0 && nc < gridC) {
                        if (isDense[nr][nc] && !visited[nr][nc]) {
                          visited[nr][nc] = true;
                          queue.add([nr, nc]);
                        }
                      }
                    }
                  }
                  if (comp.length > largestComp.length) {
                    largestComp = comp;
                  }
                }
              }
            }

            if (largestComp.length >= 25) {
              int minSumIdx = 0, maxSumIdx = 0, maxDiffIdx = 0, minDiffIdx = 0;
              double minSum = 9999, maxSum = -9999, maxDiff = -9999, minDiff = 9999;

              for (int i = 0; i < largestComp.length; i++) {
                final cell = largestComp[i];
                double gx = cell[1] / gridC;
                double gy = cell[0] / gridR;
                double sum = gx + gy;
                double diff = gx - gy;

                if (sum < minSum) { minSum = sum; minSumIdx = i; }
                if (sum > maxSum) { maxSum = sum; maxSumIdx = i; }
                if (diff > maxDiff) { maxDiff = diff; maxDiffIdx = i; }
                if (diff < minDiff) { minDiff = diff; minDiffIdx = i; }
              }

              final tlCell = largestComp[minSumIdx];
              final trCell = largestComp[maxDiffIdx];
              final brCell = largestComp[maxSumIdx];
              final blCell = largestComp[minDiffIdx];

              Offset cellToScreenOffset(List<int> cell) {
                double nx = 1.0 - (cell[0] / gridR);
                double ny = cell[1] / gridC;
                return Offset(nx, ny);
              }

              newCorners = [
                cellToScreenOffset(tlCell),
                cellToScreenOffset(trCell),
                cellToScreenOffset(brCell),
                cellToScreenOffset(blCell),
              ];
              detectedObj = "Terdeteksi: Lembar Kertas/Nota";
              if (luma >= 60 && luma <= 210) {
                lightColor = AppTheme.hijauMuda;
              }
            } else {
              if (luma >= 60 && luma <= 210) {
                detectedObj = "Sejajarkan nota di area kamera";
                lightColor = Colors.white;
              }
            }
          } else {
            // 3. Analisis dengan Model TFLite untuk klasifikasi komoditas live HANYA jika step == 1
            final uBytes = image.planes.length >= 3 ? image.planes[1].bytes : null;
            final vBytes = image.planes.length >= 3 ? image.planes[2].bytes : null;
            final uBytesPerRow = image.planes.length >= 3 ? image.planes[1].bytesPerRow : 0;
            final vBytesPerRow = image.planes.length >= 3 ? image.planes[2].bytesPerRow : 0;

            // 4. Deteksi area/kotak pembatas komoditas real-time (Bounding Box)
            const int gridR = 15;
            const int gridC = 15;
            final double stepX = frameW / gridC;
            final double stepY = frameH / gridR;
            
            final isCommodity = List.generate(gridR, (_) => List.filled(gridC, false));
            for (int gy = 0; gy < gridR; gy++) {
              for (int gx = 0; gx < gridC; gx++) {
                int fx = (gx * stepX).round().clamp(0, frameW - 1);
                int fy = (gy * stepY).round().clamp(0, frameH - 1);
                
                int yVal = bytes[fy * bytesPerRow + fx];
                int uVal = 128;
                int vVal = 128;
                if (uBytes != null && vBytes != null) {
                  int csy = fy ~/ 2;
                  int csx = fx ~/ 2;
                  uVal = uBytes[csy * uBytesPerRow + csx];
                  vVal = vBytes[csy * vBytesPerRow + csx];
                }

                if (_isCommodityPixel(yVal, uVal, vVal)) {
                  isCommodity[gy][gx] = true;
                }
              }
            }

            final visited = List.generate(gridR, (_) => List.filled(gridC, false));
            List<List<int>> largestComp = [];
            for (int r = 0; r < gridR; r++) {
              for (int c = 0; c < gridC; c++) {
                if (isCommodity[r][c] && !visited[r][c]) {
                  final List<List<int>> comp = [];
                  final List<List<int>> queue = [[r, c]];
                  visited[r][c] = true;
                  while (queue.isNotEmpty) {
                    final curr = queue.removeAt(0);
                    comp.add(curr);
                    final currR = curr[0];
                    final currC = curr[1];
                    final dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
                    for (final d in dirs) {
                      final nr = currR + d[0];
                      final nc = currC + d[1];
                      if (nr >= 0 && nr < gridR && nc >= 0 && nc < gridC) {
                        if (isCommodity[nr][nc] && !visited[nr][nc]) {
                          visited[nr][nc] = true;
                          queue.add([nr, nc]);
                        }
                      }
                    }
                  }
                  if (comp.length > largestComp.length) {
                    largestComp = comp;
                  }
                }
              }
            }

            if (largestComp.length >= 15) {
              int minX = gridC;
              int maxX = -1;
              int minY = gridR;
              int maxY = -1;

              for (final cell in largestComp) {
                int gy = cell[0];
                int gx = cell[1];
                if (gx < minX) minX = gx;
                if (gx > maxX) maxX = gx;
                if (gy < minY) minY = gy;
                if (gy > maxY) maxY = gy;
              }

              int padX1 = (minX > 0) ? minX - 1 : 0;
              int padX2 = (maxX < gridC - 1) ? maxX + 1 : gridC - 1;
              int padY1 = (minY > 0) ? minY - 1 : 0;
              int padY2 = (maxY < gridR - 1) ? maxY + 1 : gridR - 1;

              Offset cellToScreenOffset(int gx, int gy) {
                double nx = 1.0 - (gy / gridR);
                double ny = gx / gridC;
                return Offset(nx, ny);
              }

              newCorners = [
                cellToScreenOffset(padX1, padY1),
                cellToScreenOffset(padX2, padY1),
                cellToScreenOffset(padX2, padY2),
                cellToScreenOffset(padX1, padY2),
              ];

              // Jalankan klasifikasi TFLite live setiap 400ms jika step == 1
              final int now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastInferenceTime > 400) {
                _lastInferenceTime = now;
                _pcdController.prosesKlasifikasiLive(image).then((hasil) {
                  if (!mounted) return;
                  final String comm = hasil['commodity'] as String;
                  final double conf = (hasil['confidence'] as num?)?.toDouble() ?? 0.0;
                  
                  setState(() {
                    _tfliteLabel = _formatCommodityName(comm);
                    _tfliteConfidence = conf;
                  });
                });
              }

              if (_tfliteConfidence > 0.15 && _tfliteLabel != "Mencari objek...") {
                lightColor = AppTheme.hijauMuda;
              } else {
                lightColor = Colors.white;
              }
            } else {
              lightColor = Colors.white;
              _tfliteConfidence = 0.0;
              _tfliteLabel = "Mencari objek...";
            }
          }

          if (mounted) {
            setState(() {
              _detectedCorners = newCorners;
              if (_step == 0 && newCorners != null) {
                _detectedNotaCorners = newCorners;
              }
              _liveLightingStatus = lightStatus;
              _liveLightingColor = lightColor;
              _liveDetectedObject = detectedObj;
            });
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 100)); // Delay kecil untuk rendering overlay responsif
        _isProcessingFrame = false;
      });
    }
  }

  void _stopLiveStream() {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopLiveStream();
      cameraController.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveStream();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final finalCorners = _detectedCorners ?? _detectedNotaCorners;
      _stopLiveStream(); 
      HapticFeedback.vibrate(); 

      final XFile photo = await _cameraController!.takePicture();
      final File adjustedPhoto = await _brightnessService.adjustBrightness(File(photo.path));

      setState(() {
        if (_step == 0) {
          _fotoNotaPath = adjustedPhoto.path;
          _detectedNotaCorners = finalCorners;
          _showLiveCamera = false; 
        } else if (_step == 1) {
          _fotoBarangPath = adjustedPhoto.path;
          _step = 2; 
          _processAiAndNavigate();
        }
      });
    } catch (e) {
      debugPrint("Error mengambil gambar: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final prefix = _step == 0 ? 'nota' : 'barang';
        final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
        final File savedImage = await File(image.path).copy('${appDir.path}/$fileName');

        setState(() {
          if (_step == 0) {
            _fotoNotaPath = savedImage.path;
            _detectedNotaCorners = null;
            _showLiveCamera = false;
          } else if (_step == 1) {
            _fotoBarangPath = savedImage.path;
            _step = 2;
            _processAiAndNavigate();
          }
        });
      }
    } catch (e) {
      debugPrint("Error mengambil gambar dari galeri: $e");
    }
  }

  Future<void> _processAiAndNavigate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3))),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.hijauMuda, strokeWidth: 3),
                SizedBox(height: 20),
                Text('SEDANG MEMPROSES FOTO...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5, decoration: TextDecoration.none)),
                SizedBox(height: 6),
                Text('Mohon tunggu, sistem sedang membaca data otomatis', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w400, fontSize: 11, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      ),
    );

    String finalNotaPath = _fotoNotaPath!;
    if (_fotoNotaPath != null) {
      finalNotaPath = await _pcdController.prosesWarpingNota(
        _fotoNotaPath!,
        manualCorners: _detectedNotaCorners,
      );
    }

    String finalBarangPath = _fotoBarangPath!;
    if (_fotoBarangPath != null) {
      finalBarangPath = await _pcdController.prosesSegmentasiBarang(_fotoBarangPath!);
    }

    final dataHasilOcr = await _pcdController.prosesOcrNota(finalNotaPath);

    // ─── MODUL 10: Gunakan prosesGradingLengkap untuk mendapat confidence ───
    final hasilGrading = await _pcdController.prosesGradingLengkap(finalBarangPath);
    final tebakanGrade = hasilGrading['grade'] as String;
    final tebakanCommodity = hasilGrading['commodity'] as String? ?? '';
    double confidence = (hasilGrading['confidence'] as num?)?.toDouble() ?? 0.0;

    // Jika tidak dikenali sebagai komoditas pertanian, hentikan proses dan beri peringatan
    if (tebakanCommodity == 'Bukan Komoditas' || tebakanGrade == 'Bukan Komoditas') {
      if (mounted) Navigator.pop(context); // Tutup dialog loading
      
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Objek Tidak Dikenali', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Objek tidak dikenali sebagai komoditas pertanian, silakan foto ulang.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: AppTheme.hijauMuda, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      
      setState(() {
        _step = 1;
        _fotoBarangPath = null;
        _showLiveCamera = true;
      });
      _startLiveStream();
      return;
    }

    if (mounted) Navigator.pop(context); // Tutup dialog loading

    // ─── MODUL 10: Validasi Confidence Sweeper ───
    final confidenceResult = _pcdController.confidenceValidator.validate(
      confidence: confidence,
      grade: tebakanGrade,
      commodity: tebakanCommodity,
    );

    if (confidenceResult.state == ConfidenceState.accepted) {
      _pcdController.confidenceValidator.reset();
      _navigateKeTransaksi(
        finalNotaPath: finalNotaPath,
        finalBarangPath: finalBarangPath,
        tebakanGrade: tebakanGrade,
        dataHasilOcr: dataHasilOcr,
        tebakanKomoditas: tebakanCommodity,
      );
    } else {
      if (mounted) {
        _showConfidenceSweeperSheet(
          confidenceResult: confidenceResult,
          finalNotaPath: finalNotaPath,
          finalBarangPath: finalBarangPath,
          dataHasilOcr: dataHasilOcr,
        );
      }
    }
  }

  /// Navigasi langsung ke TransaksiScreen. Dipanggil jika confidence accepted
  /// atau user memilih "Gunakan Hasil Manual" dari sweeper sheet.
  void _navigateKeTransaksi({
    required String finalNotaPath,
    required String finalBarangPath,
    required String tebakanGrade,
    required Map<String, String> dataHasilOcr,
    String? tebakanKomoditas,
  }) {
    if (!mounted) return;
    _stopLiveStream();
    _cameraController?.dispose();

    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TransaksiScreen(
          fotoNotaPath: finalNotaPath,
          fotoBarangPath: finalBarangPath,
          gradeTebakanPcd: tebakanGrade,
          initialBeratOcr: dataHasilOcr['berat'],
          initialHargaOcr: dataHasilOcr['harga'],
          initialNamaPenjualOcr: dataHasilOcr['nama'],
          initialDesaOcr: dataHasilOcr['desa'],
          initialKomoditasOcr: dataHasilOcr['komoditas'],
          initialKomoditasPcd: tebakanKomoditas,
        ),
      ),
    );
  }

  // ─── MODUL 10: Bottom Sheet Confidence Sweeper ───
  void _showConfidenceSweeperSheet({
    required ConfidenceResult confidenceResult,
    required String finalNotaPath,
    required String finalBarangPath,
    required Map<String, String> dataHasilOcr,
  }) {
    final isManualOverride = confidenceResult.state == ConfidenceState.manualOverride;
    final percent = confidenceResult.confidencePercent;

    // Warna dinamis berdasarkan confidence level
    Color barColor;
    Color barBgColor;
    IconData statusIcon;
    String statusLabel;
    if (percent >= 75) {
      barColor = AppTheme.hijauMuda;
      barBgColor = AppTheme.hijauMuda.withOpacity(0.15);
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Keyakinan Tinggi';
    } else if (percent >= 50) {
      barColor = AppTheme.kuning;
      barBgColor = AppTheme.kuning.withOpacity(0.15);
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = 'Keyakinan Sedang';
    } else {
      barColor = AppTheme.merah;
      barBgColor = AppTheme.merah.withOpacity(0.15);
      statusIcon = Icons.error_outline_rounded;
      statusLabel = 'Keyakinan Rendah';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ─── Header: Icon + Status ───
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: barBgColor,
              ),
              child: Icon(statusIcon, color: barColor, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: barColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              confidenceResult.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // ─── Confidence Bar Visual ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgPage,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Skor Keyakinan ML',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond),
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: barColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 12,
                      child: LinearProgressIndicator(
                        value: confidenceResult.confidence.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Threshold: ${(confidenceResult.thresholdUsed * 100).round()}%',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                      Text(
                        'Percobaan: ${confidenceResult.retryCount}/${confidenceResult.maxRetry}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Warning Banner jika Manual Override ───
            if (isManualOverride)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.kuning.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.kuning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Batas percobaan foto ulang telah habis.\nSilakan lanjutkan dengan input manual.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Action Buttons ───
            // Tombol Retry (hanya tampil jika state = needsRetry)
            if (!isManualOverride)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); // Tutup bottom sheet
                    // Reset langkah ke foto komoditas & buka kamera ulang
                    setState(() {
                      _step = 1;
                      _fotoBarangPath = null;
                      _showLiveCamera = true;
                    });
                    _startLiveStream();
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: Text(
                    'Foto Ulang (Percobaan ${confidenceResult.retryCount}/${confidenceResult.maxRetry})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hijauMuda,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            if (!isManualOverride) const SizedBox(height: 10),

            // Tombol Gunakan Hasil Manual (selalu tampil)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx); // Tutup bottom sheet
                  _pcdController.confidenceValidator.reset();
                  _navigateKeTransaksi(
                    finalNotaPath: finalNotaPath,
                    finalBarangPath: finalBarangPath,
                    tebakanGrade: confidenceResult.grade,
                    dataHasilOcr: dataHasilOcr,
                    tebakanKomoditas: confidenceResult.commodity,
                  );
                },
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: Text(
                  isManualOverride ? 'Lanjut Input Manual' : 'Gunakan Hasil Ini',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- MODE PILIHAN FORM AWAL (SEBELUM KAMERA PREVIEW AKTIF) ---
    if (!_showLiveCamera) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          title: const Text('Kamera Pemindai ReksaTani', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            const Text('TAHAPAN AMBIL FOTO TRANSAKSI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.textSecond, letterSpacing: 1)),
            const SizedBox(height: 16),
            
            // FORM INPUT 1: FOTO NOTA
            _buildSelectionFormItem(
              title: 'Foto Nota Timbangan',
              subtitle: 'Ambil foto nota kertas hasil timbangan dari galeri atau kamera',
              icon: Icons.receipt_long_rounded,
              imagePath: _fotoNotaPath,
              onTap: () {
                setState(() { _step = 0; _showLiveCamera = true; });
                _startLiveStream(); 
              },
            ),
            const SizedBox(height: 20), 
            
            // FORM INPUT 2: FOTO KOMODITAS BARANG
            _buildSelectionFormItem(
              title: 'Foto Sayur / Komoditas',
              subtitle: 'Ambil foto fisik barang hasil panen petani untuk dicek kualitasnya',
              icon: Icons.grass_rounded,
              imagePath: _fotoBarangPath,
              onTap: () {
                setState(() { _step = 1; _showLiveCamera = true; });
                _startLiveStream(); 
              },
            ),
            
            // ─── 🛠️ INOVASI BARU: TOMBOL SKIP FOTO UNTUK KASBON MURNI ───
            const SizedBox(height: 28),
            const Text('OPSI KHUSUS PETANI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.textSecond, letterSpacing: 1)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                _stopLiveStream();
                _cameraController?.dispose();
                // Langsung lompat ke form input dengan membawa penanda Kasbon Baru
                Navigator.of(context, rootNavigator: true).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const TransaksiScreen(
                      fotoNotaPath: '',
                      fotoBarangPath: '',
                      gradeTebakanPcd: '-',
                      isMurniKasbon: true, // 👈 Mengirim indikator kasbon murni
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5), // Berwarna amber khas kasbon
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.payments_outlined, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pencairan Kasbon Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                          SizedBox(height: 4),
                          Text('Petani ingin meminjam uang jalan (Skip ambil foto nota & komoditas)', style: TextStyle(fontSize: 11, color: AppTheme.textSecond, height: 1.3)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD97706)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            if (_fotoNotaPath != null && _fotoBarangPath != null)
              SizedBox(
                height: 52, width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processAiAndNavigate,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('PROSES DATA TRANSAKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hijauMuda, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                ),
              )
          ],
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: AppTheme.hijauMuda)));
    }

    final String textInstruksi = _step == 0 ? "FOTO NOTA TIMBANGAN" : "FOTO FISIK SAYUR/KOMODITAS";
    final IconData iconInstruksi = _step == 0 ? Icons.receipt_long_rounded : Icons.grass_rounded;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Lensa Kamera Utama yang super bersih
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio > 1
                    ? 1 / _cameraController!.value.aspectRatio
                    : _cameraController!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cameraController!),
                    if (_detectedCorners != null && _step == 0)
                      CustomPaint(
                        painter: DocumentOutlinePainter(
                          corners: _detectedCorners!,
                          color: _liveLightingColor,
                          label: "Nota Timbangan",
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 2. HUD Live Sensor Data Atas
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: _liveLightingColor.withOpacity(0.5))),
                  child: Row(
                    children: [
                      Icon(Icons.wb_sunny_rounded, color: _liveLightingColor, size: 14),
                      const SizedBox(width: 6),
                      Text(_liveLightingStatus, style: TextStyle(color: _liveLightingColor, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.kuning, borderRadius: BorderRadius.circular(20)),
                  child: Text('FOTO ${_step + 1}/2', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                )
              ],
            ),
          ),

          // 3. DOCK TOMBOL KONTROL HARDWARE (KANAN LAYAR)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: Column(
              children: [
                // Tombol Sakelar Senter
                GestureDetector(
                  onTap: _toggleFlash,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: _isFlashOn ? AppTheme.kuning : Colors.white24, width: 1.5),
                    ),
                    child: Icon(
                      _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isFlashOn ? AppTheme.kuning : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tombol Tukar Lensa (Depan/Belakang)
                GestureDetector(
                  onTap: _toggleCameraLens,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Panel Label Komoditas Cerdas (Latar Belakang Blur Transparan)
          Positioned(
            bottom: 140,
            left: 32, right: 32,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _liveLightingColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Icon(iconInstruksi, color: _liveLightingColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(textInstruksi, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(_liveDetectedObject, style: TextStyle(color: _liveLightingColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Dock Tombol Kontras Utama (Bawah)
          Positioned(
            bottom: 30,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      _stopLiveStream();
                      setState(() => _showLiveCamera = false);
                    }, 
                    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
                  ),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 76, width: 76,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _liveLightingColor, width: 4), color: Colors.transparent),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: _cameraController?.value.isTakingPicture == true ? 50 : 62,
                          width: _cameraController?.value.isTakingPicture == true ? 50 : 62,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _stopLiveStream();
                      _pickImageFromGallery();
                    },
                    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionFormItem({required String title, required String subtitle, required IconData icon, String? imagePath, required VoidCallback? onTap, bool isDisabled = false}) {
    final bool hasImage = imagePath != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18), 
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasImage ? AppTheme.hijauMuda : AppTheme.border, width: hasImage ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: (isDisabled ? Colors.grey : (hasImage ? AppTheme.hijauMuda : AppTheme.hijauSoft)).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isDisabled ? Colors.grey : (hasImage ? AppTheme.hijauMuda : AppTheme.hijauTua), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDisabled ? Colors.grey : AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDisabled ? Colors.grey.shade400 : AppTheme.textSecond, height: 1.3)),
                ],
              ),
            ),
            if (hasImage) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(imagePath), width: 50, height: 50, fit: BoxFit.cover))
            else Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDisabled ? Colors.grey.shade300 : AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  bool _isCommodityPixel(int y, int u, int v) {
    final int chromadiff = (u - 128).abs() + (v - 128).abs();
    
    // 1. Sawit/Gabah (warna merah/oranye/kuning hangat yang jenuh)
    // Diperketat agar tidak sensitif terhadap warna tembok kekuningan/cream
    if (v > 142 && u < 105) return true;

    // 2. Kopi Robusta (kadar kecerahan rendah dengan warna jenuh cokelat/hijau zaitun)
    // Diperketat dari y < 80 ke y < 70 dan chromadiff > 20
    if (y < 70 && chromadiff > 20) return true;

    // 3. Warna sangat jenuh secara umum (jauh dari abu-abu/netral)
    // Diperketat dari chromadiff > 24 ke chromadiff > 32 untuk mengabaikan tembok abu-abu/berwarna tipis
    if (chromadiff > 32) return true;

    return false;
  }

  String _formatCommodityName(String raw) {
    if (raw == 'gabah') return "Gabah Padi (GKP/GKG)";
    if (raw == 'kopi robusta') return "Kopi Robusta (Biji Kopi)";
    if (raw == 'sawit') return "Kelapa Sawit (TBS)";
    return raw;
  }
}

class DocumentOutlinePainter extends CustomPainter {
  final List<Offset> corners;
  final Color color;
  final String? label;

  DocumentOutlinePainter({
    required this.corners,
    required this.color,
    this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;

    final paintBorder = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintFill = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(corners[0].dx * size.width, corners[0].dy * size.height)
      ..lineTo(corners[1].dx * size.width, corners[1].dy * size.height)
      ..lineTo(corners[2].dx * size.width, corners[2].dy * size.height)
      ..lineTo(corners[3].dx * size.width, corners[3].dy * size.height)
      ..close();

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintBorder);

    final paintCircle = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    for (final corner in corners) {
      canvas.drawCircle(Offset(corner.dx * size.width, corner.dy * size.height), 6.0, paintCircle);
    }

    // Gambar label teks melayang di atas bounding box
    if (label != null && label!.isNotEmpty) {
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);

      // Cari koordinat paling kiri-atas dari box
      double minX = corners[0].dx * size.width;
      double minY = corners[0].dy * size.height;
      for (final corner in corners) {
        if (corner.dx * size.width < minX) minX = corner.dx * size.width;
        if (corner.dy * size.height < minY) minY = corner.dy * size.height;
      }

      final rectHeight = textPainter.height + 8;
      final rectWidth = textPainter.width + 16;
      final rect = Rect.fromLTWH(
        minX,
        (minY - rectHeight - 6).clamp(8.0, size.height - rectHeight),
        rectWidth,
        rectHeight,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      
      final rectPaint = Paint()..color = color.withOpacity(0.85);
      canvas.drawRRect(rrect, rectPaint);

      textPainter.paint(
        canvas,
        Offset(
          minX + 8,
          (minY - rectHeight - 6 + 4).clamp(12.0, size.height - rectHeight + 4),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DocumentOutlinePainter oldDelegate) {
    return oldDelegate.corners != corners || oldDelegate.color != color || oldDelegate.label != label;
  }
}