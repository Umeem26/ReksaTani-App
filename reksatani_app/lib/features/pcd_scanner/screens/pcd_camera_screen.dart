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
          final int luma = image.planes[0].bytes.fold<int>(0, (p, e) => p + e) ~/ image.planes[0].bytes.length;

          String lightStatus;
          Color lightColor;
          String detectedObj = "Menganalisis...";

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
            
            if (_step == 0) {
              detectedObj = "Terdeteksi: Lembar Kertas/Nota";
            } else {
              detectedObj = "Terdeteksi: Komoditas Organik";
            }
          }

          if (mounted) {
            setState(() {
              _liveLightingStatus = lightStatus;
              _liveLightingColor = lightColor;
              _liveDetectedObject = detectedObj;
            });
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 1000));
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
      _stopLiveStream(); 
      HapticFeedback.vibrate(); 

      final XFile photo = await _cameraController!.takePicture();
      final File adjustedPhoto = await _brightnessService.adjustBrightness(File(photo.path));

      setState(() {
        if (_step == 0) {
          _fotoNotaPath = adjustedPhoto.path;
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
      finalNotaPath = await _pcdController.prosesWarpingNota(_fotoNotaPath!);
    }

    String finalBarangPath = _fotoBarangPath!;
    if (_fotoBarangPath != null) {
      finalBarangPath = await _pcdController.prosesSegmentasiBarang(_fotoBarangPath!);
    }

    final dataHasilOcr = await _pcdController.prosesOcrNota(finalNotaPath);

    // ─── MODUL 10: Gunakan prosesGradingLengkap untuk mendapat confidence ───
    final hasilGrading = await _pcdController.prosesGradingLengkap(finalBarangPath);
    final tebakanGrade = hasilGrading['grade'] as String;
    final confidence = (hasilGrading['confidence'] as num?)?.toDouble() ?? 0.0;

    if (mounted) Navigator.pop(context); // Tutup dialog loading

    // ─── MODUL 10: Validasi Confidence Sweeper ───
    final confidenceResult = _pcdController.confidenceValidator.validate(
      confidence: confidence,
      grade: tebakanGrade,
    );

    if (confidenceResult.state == ConfidenceState.accepted) {
      // Confidence tinggi → langsung navigate ke TransaksiScreen
      _navigateKeTransaksi(
        finalNotaPath: finalNotaPath,
        finalBarangPath: finalBarangPath,
        tebakanGrade: tebakanGrade,
        dataHasilOcr: dataHasilOcr,
      );
    } else {
      // Confidence rendah → tampilkan Confidence Sweeper Bottom Sheet
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
            const Text('TAHAPAN AMBIL FOTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.textSecond, letterSpacing: 1)),
            const SizedBox(height: 20),
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
            const SizedBox(height: 28), 
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
            const SizedBox(height: 48),
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
          Container(color: Colors.black, child: Center(child: CameraPreview(_cameraController!))),

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
}