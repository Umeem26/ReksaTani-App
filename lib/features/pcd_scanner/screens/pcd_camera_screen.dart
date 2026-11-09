import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/image_brightness_service.dart';
import '../services/grading_ml_service.dart' show ScanResult, ScanStatus;
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../../../shared/widgets/app_theme.dart';
import '../controllers/pcd_controller.dart';
import '../widgets/dialog_proses_foto.dart';
import 'corner_adjuster_screen.dart';

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

  // ─── TEMPORAL FILTERS FOR NOTE SCANNER ───
  int _stableFrameCount = 0;
  List<Offset>? _lastStableCorners;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _fotoNotaPath = widget.initialFotoNota;
    _fotoBarangPath = widget.initialFotoBarang;

    _initCamera();
    _pcdController.loadModel(); // 👈 Memuat model ML lebih awal
  }

  /// Membuat controller baru. Controller yang sudah di-dispose tidak pernah
  /// dipakai lagi: `value.isInitialized` tetap true sesudah dispose, jadi
  /// penanda yang sah hanya `_cameraController != null`.
  Future<void> _initCamera() async {
    CameraController? controller;
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        final targetLens = _isBackCamera ? CameraLensDirection.back : CameraLensDirection.front;
        final selectedCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == targetLens,
          orElse: () => _cameras!.first,
        );

        controller = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        );
        // Controller lama (bila ada) dilepas dulu supaya kamera tidak dibuka dua kali.
        await _lepasKamera();
        _cameraController = controller;

        await controller.initialize();
        // Dilepas atau diganti selagi menunggu inisialisasi: jangan dipakai.
        if (!identical(_cameraController, controller)) {
          await controller.dispose();
          return;
        }
        await controller.setFlashMode(FlashMode.off);
        _isFlashOn = false;

        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error inisialisasi kamera: $e");
      if (controller != null && identical(_cameraController, controller)) {
        _cameraController = null;
        await controller.dispose();
      }
    }
  }

  /// Melepas controller dan mengosongkan rujukannya, sehingga tidak ada kode
  /// yang memanggil controller yang sudah di-dispose.
  Future<void> _lepasKamera() async {
    final c = _cameraController;
    if (c == null) return;
    _cameraController = null;
    if (mounted) {
      setState(() => _isCameraInitialized = false);
    } else {
      _isCameraInitialized = false;
    }
    if (c.value.isStreamingImages) {
      try {
        await c.stopImageStream();
      } catch (_) {}
    }
    await c.dispose();
  }

  /// Memastikan ada controller yang siap, misalnya sesudah kembali dari
  /// penyesuai sudut atau galeri ketika kamera dilepas oleh siklus hidup app.
  Future<bool> _pastikanKamera() async {
    if (_cameraController == null) await _initCamera();
    final c = _cameraController;
    return c != null && c.value.isInitialized;
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

    await _lepasKamera();
    await _initCamera();

    if (_showLiveCamera) {
      _startLiveStream();
    }
  }

  void _startLiveStream() {
    final c = _cameraController;
    if (c != null && c.value.isInitialized && !c.value.isStreamingImages) {
      c.startImageStream((CameraImage image) async {
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

            final int contrast = maxVal - minVal;
            final bool isDocumentPresent = contrast > 60 && maxVal > 150;

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

            if (isDocumentPresent && largestComp.length >= 25) {
              int minSumIdx = 0, maxSumIdx = 0, maxDiffIdx = 0, minDiffIdx = 0;
              double minSum = 9999, maxSum = -9999, maxDiff = -9999, minDiff = 9999;

              for (int i = 0; i < largestComp.length; i++) {
                final cell = largestComp[i];
                double gx = cell[1] / (gridC - 1);
                double gy = cell[0] / (gridR - 1);
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
                double nx = 1.0 - (cell[0] / (gridR - 1));
                double ny = cell[1] / (gridC - 1);
                return Offset(nx, ny);
              }

              final tempCorners = [
                cellToScreenOffset(tlCell),
                cellToScreenOffset(trCell),
                cellToScreenOffset(brCell),
                cellToScreenOffset(blCell),
              ];

              _stableFrameCount++;
              if (_stableFrameCount >= 3) {
                newCorners = tempCorners;
                _lastStableCorners = tempCorners;
              } else {
                newCorners = _lastStableCorners;
              }

              detectedObj = "Terdeteksi: Lembar Kertas/Nota";
              if (luma >= 60 && luma <= 210) {
                lightColor = AppTheme.hijauMuda;
              }
            } else {
              _stableFrameCount = 0;
              _lastStableCorners = null;
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
                double nx = 1.0 - (gy / (gridR - 1));
                double ny = gx / (gridC - 1);
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
                _pcdController.prosesKlasifikasiLive(image).then((ScanResult hasil) {
                  if (!mounted) return;
                  // Keputusan sama dengan jalur still; label memakai keyakinan ROUTER untuk komoditas.
                  final bool found = hasil.status == ScanStatus.ok && hasil.commodity != null;
                  setState(() {
                    _tfliteLabel = found ? _formatCommodityName(hasil.commodity!) : "Mencari objek...";
                    _tfliteConfidence = found ? hasil.routerConfidence : 0.0;
                  });
                });
              }

              if (_tfliteConfidence > 0.15 && _tfliteLabel != "Mencari objek...") {
                lightColor = AppTheme.hijauMuda;
                detectedObj = "Terdeteksi: $_tfliteLabel";
              } else {
                lightColor = Colors.white;
                detectedObj = "Mencari Komoditas...";
              }
            } else {
              lightColor = Colors.white;
              _tfliteConfidence = 0.0;
              _tfliteLabel = "Mencari objek...";
              detectedObj = "Arahkan kamera ke Komoditas";
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
      }).catchError((Object e) => debugPrint("Gagal memulai stream kamera: $e"));
    }
  }

  void _stopLiveStream() {
    final c = _cameraController;
    if (c != null && c.value.isStreamingImages) {
      c.stopImageStream().catchError((Object e) => debugPrint("Gagal menghentikan stream kamera: $e"));
    }
  }

  /// True bila kamera dilepas oleh siklus hidup app dan perlu dibuka lagi.
  bool _dilepasSiklus = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Controller yang belum siap (mis. dialog izin kamera sedang tampil) dibiarkan.
      if (cameraController == null || !cameraController.value.isInitialized) return;
      _dilepasSiklus = true;
      _lepasKamera();
    } else if (state == AppLifecycleState.resumed && _dilepasSiklus) {
      _dilepasSiklus = false;
      _pulihkanKamera();
    }
  }

  /// Membuka kamera lagi; stream hanya dimulai bila layar ini yang tampil,
  /// bukan saat penyesuai sudut masih terbuka di atasnya.
  Future<void> _pulihkanKamera() async {
    if (!await _pastikanKamera() || !mounted) return;
    if (_showLiveCamera && (ModalRoute.of(context)?.isCurrent ?? true)) _startLiveStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _cameraController;
    _cameraController = null;
    if (c != null) {
      if (c.value.isStreamingImages) c.stopImageStream().catchError((Object _) {});
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePicture() async {
    // Kamera bisa sudah dilepas (mis. sesudah membuka galeri); buka lagi dulu.
    if (!await _pastikanKamera()) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final finalCorners = _detectedCorners ?? _detectedNotaCorners;
      _stopLiveStream(); 
      HapticFeedback.vibrate(); 

      final XFile photo = await _cameraController!.takePicture();
      final File adjustedPhoto = await _brightnessService.adjustBrightness(File(photo.path));

      if (_step == 0) {
        if (!mounted) return;
        final adjustedCorners = await Navigator.push<List<Offset>>(
          context,
          MaterialPageRoute(
            builder: (_) => CornerAdjusterScreen(
              imagePath: adjustedPhoto.path,
              initialCorners: finalCorners,
            ),
          ),
        );
        if (!mounted) return;

        if (adjustedCorners != null) {
          setState(() {
            _fotoNotaPath = adjustedPhoto.path;
            _detectedNotaCorners = adjustedCorners;
            _showLiveCamera = false;
          });
        } else {
          // Kembali dengan tombol back: kamera bisa sudah dilepas selama penyesuai terbuka.
          await _pulihkanKamera();
        }
      } else if (_step == 1) {
        setState(() {
          _fotoBarangPath = adjustedPhoto.path;
          _step = 2;
          _processAiAndNavigate();
        });
      }
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

        if (_step == 0) {
          if (!mounted) return;
          final adjustedCorners = await Navigator.push<List<Offset>>(
            context,
            MaterialPageRoute(
              builder: (_) => CornerAdjusterScreen(
                imagePath: savedImage.path,
                initialCorners: null,
              ),
            ),
          );
          if (!mounted) return;

          if (adjustedCorners != null) {
            setState(() {
              _fotoNotaPath = savedImage.path;
              _detectedNotaCorners = adjustedCorners;
              _showLiveCamera = false;
            });
          } else {
            setState(() {
              _showLiveCamera = true;
            });
            // Membuka galeri melepas kamera lewat siklus hidup app; buka lagi.
            await _pulihkanKamera();
          }
        } else if (_step == 1) {
          setState(() {
            _fotoBarangPath = savedImage.path;
            _step = 2;
            _processAiAndNavigate();
          });
        }
      }
    } catch (e) {
      debugPrint("Error mengambil gambar dari galeri: $e");
    }
  }

  Future<void> _processAiAndNavigate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DialogProsesFoto(),
    );

    String finalNotaPath = '';
    String finalBarangPath = _fotoBarangPath ?? '';
    Map<String, String> dataHasilOcr = const {};
    SaranKomoditas? saran;

    try {
      // Alur tanpa nota diperbolehkan: lewati warping & OCR bila nota belum ada.
      final String? notaPath = _fotoNotaPath;
      if (notaPath != null && notaPath.isNotEmpty) {
        finalNotaPath = await _pcdController.prosesWarpingNota(
          notaPath,
          manualCorners: _detectedNotaCorners,
        );
        dataHasilOcr = await _pcdController.prosesOcrNota(finalNotaPath);
      }

      final String? barangPath = _fotoBarangPath;
      if (barangPath != null && barangPath.isNotEmpty) {
        finalBarangPath = await _pcdController.prosesSegmentasiBarang(barangPath);
        // Router saja: AI menyarankan komoditas, grade diisi manusia lewat rubrik.
        saran = PcdController.saranDari(await _pcdController.prosesSaranKomoditas(finalBarangPath));
      }
    } catch (e) {
      debugPrint("Error memproses foto: $e");
      saran = null;
    }

    if (!mounted) return;
    Navigator.pop(context); // Tutup dialog loading

    _navigateKeTransaksi(
      finalNotaPath: finalNotaPath,
      finalBarangPath: finalBarangPath,
      dataHasilOcr: dataHasilOcr,
      saran: saran,
    );
  }

  /// Navigasi ke TransaksiScreen. [saran] null berarti tidak ada saran AI
  /// (bukan komoditas, keyakinan rendah, atau gagal): pengguna memilih manual.
  void _navigateKeTransaksi({
    required String finalNotaPath,
    required String finalBarangPath,
    required Map<String, String> dataHasilOcr,
    SaranKomoditas? saran,
  }) {
    if (!mounted) return;
    _lepasKamera();

    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TransaksiScreen(
          fotoNotaPath: finalNotaPath,
          fotoBarangPath: finalBarangPath,
          initialBeratOcr: dataHasilOcr['berat'],
          initialHargaOcr: dataHasilOcr['harga'],
          initialNamaPenjualOcr: dataHasilOcr['nama'],
          initialDesaOcr: dataHasilOcr['desa'],
          initialKomoditasOcr: dataHasilOcr['komoditas'],
          saranKomoditasAi: saran?.label,
          keyakinanSaranAi: saran?.keyakinan,
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
                _pulihkanKamera();
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
                _pulihkanKamera();
              },
            ),
            
            // ─── 🛠️ INOVASI BARU: TOMBOL SKIP FOTO UNTUK KASBON MURNI ───
            const SizedBox(height: 28),
            const Text('OPSI KHUSUS PETANI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.textSecond, letterSpacing: 1)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                _lepasKamera();
                // Langsung lompat ke form input dengan membawa penanda Kasbon Baru
                Navigator.of(context, rootNavigator: true).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const TransaksiScreen(
                      fotoNotaPath: '',
                      fotoBarangPath: '',
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
                    if (_detectedCorners != null)
                      CustomPaint(
                        painter: DocumentOutlinePainter(
                          corners: _detectedCorners!,
                          color: _liveLightingColor,
                          label: _step == 0
                              ? "Nota Timbangan"
                              : (_tfliteConfidence > 0.15 && _tfliteLabel != "Mencari objek..."
                                  ? "$_tfliteLabel (${(_tfliteConfidence * 100).toStringAsFixed(0)}%)"
                                  : null),
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
    if (v > 132 && u < 115) return true;

    // 2. Kopi Robusta (kadar kecerahan rendah dengan warna jenuh cokelat/hijau zaitun)
    if (y < 95 && chromadiff > 12) return true;

    // 3. Warna sangat jenuh secara umum (jauh dari abu-abu/netral)
    if (chromadiff > 16) return true;

    return false;
  }

  String _formatCommodityName(String raw) {
    if (raw == 'gabah') return "Gabah Padi (GKP/GKG)";
    if (raw == 'kopi' || raw == 'kopi robusta') return "Kopi Robusta (Biji Kopi)";
    if (raw == 'kelapa_sawit' || raw == 'sawit') return "Kelapa Sawit (TBS)";
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