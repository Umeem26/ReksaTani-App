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
  // 🛠️ Menerima data foto lama dari form agar tidak hilang saat ambil ulang salah satu foto
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Memuat data foto yang sudah ada sebelumnya (jika ada)
    _fotoNotaPath = widget.initialFotoNota;
    _fotoBarangPath = widget.initialFotoBarang;
    
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high, 
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        );

        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error inisialisasi kamera: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      cameraController.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
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
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

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
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.hijauMuda, strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  'SEDANG MEMPROSES FOTO...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5, decoration: TextDecoration.none),
                ),
                SizedBox(height: 6),
                Text(
                  'Mohon tunggu, sistem sedang membaca data otomatis',
                  style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w400, fontSize: 11, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ─── 🛠️ FIX UTAMA: MENYALAKAN MESIN MODUL 6 & MODUL 7 ───
    
    // 1. Eksekusi Modul 6: Pelurusan (Warping) Nota
    String finalNotaPath = _fotoNotaPath!;
    if (_fotoNotaPath != null) {
      finalNotaPath = await _pcdController.prosesWarpingNota(_fotoNotaPath!);
    }

    // 2. Eksekusi Modul 7: Pemotongan Latar Belakang Komoditas
    String finalBarangPath = _fotoBarangPath!;
    if (_fotoBarangPath != null) {
      finalBarangPath = await _pcdController.prosesSegmentasiBarang(_fotoBarangPath!);
    }

    // 3. Eksekusi Modul 8: Tebak Grade (Saat ini masih statis 'A')
    final tebakanGrade = await _pcdController.prosesTebakGrade(finalBarangPath);

    if (mounted) Navigator.pop(context); // Tutup dialog loading

    if (mounted) {
      _cameraController?.dispose(); 

      // Pindah ke form dengan mengirimkan foto HASIL OLAHAN AI, bukan mentahannya lagi!
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TransaksiScreen(
            fotoNotaPath: finalNotaPath,       // 👈 Mengirim nota yang sudah diluruskan
            fotoBarangPath: finalBarangPath,   // 👈 Mengirim komoditas yang latarnya sudah diputihkan
            gradeTebakanPcd: tebakanGrade,
          ),
        ),
      );
    }
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
          title: const Text('Kamera Pemindai ReksaTani', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // 👈 REVISI BAHASA Sederhana
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20), // Atas dibuat lebih renggang agar proporsional
          children: [
            const Text(
              'TAHAPAN AMBIL FOTO', // 👈 REVISI BAHASA Sederhana
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.textSecond, letterSpacing: 1),
            ),
            const SizedBox(height: 20),
            
            // FORM INPUT 1: FOTO NOTA
            _buildSelectionFormItem(
              title: 'Foto Nota Timbangan', // 👈 REVISI BAHASA Sederhana
              subtitle: 'Ambil foto nota kertas hasil timbangan dari galeri atau kamera',
              icon: Icons.receipt_long_rounded,
              imagePath: _fotoNotaPath,
              onTap: () => setState(() {
                _step = 0;
                _showLiveCamera = true;
              }),
            ),
            
            // 🛠️ REVISI VISUAL: Space / Jarak antar form diperbesar menjadi 28 agar tidak terlihat kosong kaku
            const SizedBox(height: 28), 
            
            // FORM INPUT 2: FOTO KOMODITAS BARANG
            _buildSelectionFormItem(
              title: 'Foto Sayur / Komoditas', // 👈 REVISI BAHASA Sederhana
              subtitle: 'Ambil foto fisik barang hasil panen petani untuk dicek kualitasnya',
              icon: Icons.grass_rounded,
              imagePath: _fotoBarangPath,
              onTap: () => setState(() {
                _step = 1;
                _showLiveCamera = true;
              }),
            ),
            
            const SizedBox(height: 48), // Jarak ke tombol proses diperlebar
            if (_fotoNotaPath != null && _fotoBarangPath != null)
              SizedBox(
                height: 52, width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processAiAndNavigate,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('PROSES DATA TRANSAKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // 👈 REVISI BAHASA Sederhana
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hijauMuda, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                ),
              )
          ],
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.hijauMuda)),
      );
    }

    final String textInstruksi = _step == 0 ? "FOTO NOTA TIMBANGAN" : "FOTO FISIK SAYUR/KOMODITAS"; // 👈 REVISI BAHASA Sederhana
    final String subInstruksi = _step == 0 ? "Pastikan tulisan angka timbangan terbaca terang" : "Posisikan barang di tengah agar kualitas terbaca pas"; // 👈 REVISI BAHASA Sederhana
    final IconData iconInstruksi = _step == 0 ? Icons.receipt_long_rounded : Icons.grass_rounded;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: Center(child: CameraPreview(_cameraController!)),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15), width: 1)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: (_step == 0 ? AppTheme.biru : AppTheme.hijauMuda).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(iconInstruksi, color: _step == 0 ? AppTheme.biru : AppTheme.hijauMuda, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(textInstruksi, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(subInstruksi, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.kuning, borderRadius: BorderRadius.circular(20)),
                        child: Text('FOTO ${_step + 1}/2', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)), // 👈 REVISI BAHASA Sederhana
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showLiveCamera = false), 
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 84, width: 84,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: Colors.transparent),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: _cameraController?.value.isTakingPicture == true ? 54 : 68,
                          width: _cameraController?.value.isTakingPicture == true ? 54 : 68,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                      child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                    ),
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
        padding: const EdgeInsets.all(18), // Padding dalam sedikit diperluas agar terlihat solid
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasImage ? AppTheme.hijauMuda : AppTheme.border, width: hasImage ? 1.5 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ]
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
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(imagePath), width: 50, height: 50, fit: BoxFit.cover),
              )
            else
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDisabled ? Colors.grey.shade300 : AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}