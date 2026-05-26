import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/image_brightness_service.dart';
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
    final tebakanGrade = await _pcdController.prosesTebakGrade(finalBarangPath);

    if (mounted) Navigator.pop(context);

    if (mounted) {
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