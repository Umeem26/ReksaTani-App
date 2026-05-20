import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../../../shared/widgets/app_theme.dart';
import '../controllers/pcd_controller.dart';
import '../../pengepul_dashboard/screens/main_shell.dart';

class PcdCameraScreen extends StatefulWidget {
  const PcdCameraScreen({super.key});

  @override
  State<PcdCameraScreen> createState() => _PcdCameraScreenState();
}

// ─── TASK 4.1: Optimasi Lifecycle dengan WidgetsBindingObserver ───
class _PcdCameraScreenState extends State<PcdCameraScreen> 
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // State Pemindai: 0 = Mode Nota, 1 = Mode Barang, 2 = Selesai
  int _step = 0; 
  String? _fotoNotaPath;
  String? _fotoBarangPath;

  final PcdController _pcdController = PcdController();
  
  // Kontrol Animasi untuk efek denyut bingkai (Glowing Pulse)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Inisialisasi animasi berdenyut 0.6 sampai 1.0 balik lagi secara berkala
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
          ResolutionPreset.medium, 
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
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      // TASK 4.3: Taktil Haptic Feedback premium saat shutter ditekan
      HapticFeedback.vibrate(); 

      final XFile photo = await _cameraController!.takePicture();

      setState(() {
        if (_step == 0) {
          _fotoNotaPath = photo.path;
          _step = 1; 
        } else if (_step == 1) {
          _fotoBarangPath = photo.path;
          _step = 2; 
        }
      });

      if (_step == 2) {
        _processAiAndNavigate();
      }
    } catch (e) {
      debugPrint("Error mengambil gambar: $e");
    }
  }

  // TASK 5.1: Pipeline Auto-Fill terarah ke TransaksiScreen
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
                  'ANALISIS MATRIKS CITRA...', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, decoration: TextDecoration.none),
                ),
                SizedBox(height: 6),
                Text(
                  'Mengekstrak data otomatis via Edge AI', 
                  style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w400, fontSize: 11, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final tebakanGrade = await _pcdController.prosesTebakGrade(_fotoBarangPath!);

    if (mounted) Navigator.pop(context);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransaksiScreen(
            fotoNotaPath: _fotoNotaPath,
            fotoBarangPath: _fotoBarangPath,
            gradeTebakanPcd: tebakanGrade,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.hijauMuda)),
      );
    }

    final size = MediaQuery.of(context).size;
    final String textInstruksi = _step == 0 ? "FOKUSKAN PADA NOTA TIMBANGAN" : "BIDIK FISIK DETAIL KOMODITAS";
    final String subInstruksi = _step == 0 ? "Pastikan tulisan angka berat terlihat jelas" : "Pastikan pencahayaan cukup dan barang stabil";
    final IconData iconInstruksi = _step == 0 ? Icons.analytics_outlined : Icons.center_focus_strong_rounded;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Lensa Kamera Utama
          CameraPreview(_cameraController!),

          // 2. TASK 4.2: Pemotong Tirai dengan Animasi Glow Berdenyut
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: ScannerOverlayPainter(
                  isModeNota: _step == 0,
                  opacityGlow: _pulseAnimation.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // 3. TASK 4.3: Intelligent HUD bergaya Glassmorphism premium
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.hijauMuda.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(iconInstruksi, color: AppTheme.hijauMuda, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              textInstruksi,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subInstruksi,
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      // Step Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.kuning,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_step + 1}/2',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Tombol Kontrol Bawah
          Positioned(
            bottom: 120,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol Keluar / Batal
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        MainShellState.of(context)?.changeTab(0);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  
                  // Tombol Shutter Utama dengan Feedback Visual
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 84, width: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: _cameraController?.value.isTakingPicture == true ? 54 : 68,
                          width: _cameraController?.value.isTakingPicture == true ? 54 : 68,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Invisible Spacer Penjaga Keseimbangan Posisi Tengah Shutter
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TASK 4.2: Pembuatan Guidance Overlay (CustomPainter - Anti Layar Hitam) ───
class ScannerOverlayPainter extends CustomPainter {
  final bool isModeNota;
  final double opacityGlow;

  ScannerOverlayPainter({required this.isModeNota, required this.opacityGlow});

  @override
  void paint(Canvas canvas, Size size) {
    // FIX UTAMA: Pakai saveLayer agar BlendMode.clear melubangi tirai secara sempurna murni transparan!
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Bentangkan Tirai Gelap Semi-Transparan
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.65);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. Kalkulasi Dimensi Lobang Sesuai Mode Task (Nota Tinggi Memanjang, Barang Kotak Presisi)
    final double cutoutWidth = size.width * 0.82;
    final double cutoutHeight = isModeNota ? size.height * 0.52 : size.width * 0.82; 
    
    final double left = (size.width - cutoutWidth) / 2;
    final double top = (size.height - cutoutHeight) / 2.4;

    final RRect cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight),
      const Radius.circular(20),
    );

    // 3. Tusuk Lubang Tengah Menjadi Tembus Pandang Transparan Total
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(cutoutRect, clearPaint);

    // 4. Tutup Instruksi Lapisan Terisolasi
    canvas.restore();

    // 5. Desain Garis Siku-siku Pemandu dengan Efek Animasi Denyut Pintar (Glow Pulse)
    final borderPaint = Paint()
      ..color = AppTheme.hijauMuda.withOpacity(opacityGlow) // Berdenyut dinamis
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final double len = 32.0; // Panjang siku-siku pemandu

    // Gambar Garis Siku Kiri Atas
    canvas.drawLine(Offset(left, top + len), Offset(left, top), borderPaint);
    canvas.drawLine(Offset(left, top), Offset(left + len, top), borderPaint);
    
    // Gambar Garis Siku Kanan Atas
    canvas.drawLine(Offset(left + cutoutWidth - len, top), Offset(left + cutoutWidth, top), borderPaint);
    canvas.drawLine(Offset(left + cutoutWidth, top), Offset(left + cutoutWidth, top + len), borderPaint);
    
    // Gambar Garis Siku Kiri Bawah
    canvas.drawLine(Offset(left, top + cutoutHeight - len), Offset(left, top + cutoutHeight), borderPaint);
    canvas.drawLine(Offset(left, top + cutoutHeight), Offset(left + len, top + cutoutHeight), borderPaint);
    
    // Gambar Garis Siku Kanan Bawah
    canvas.drawLine(Offset(left + cutoutWidth - len, top + cutoutHeight), Offset(left + cutoutWidth, top + cutoutHeight), borderPaint);
    canvas.drawLine(Offset(left + cutoutWidth, top + cutoutHeight), Offset(left + cutoutWidth, top + cutoutHeight - len), borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.isModeNota != isModeNota || oldDelegate.opacityGlow != opacityGlow;
  }
}