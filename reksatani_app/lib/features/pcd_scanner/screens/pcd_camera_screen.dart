import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/pcd_controller.dart';
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../../../shared/widgets/app_theme.dart';

class PcdCameraScreen extends StatefulWidget {
  const PcdCameraScreen({super.key});

  @override
  State<PcdCameraScreen> createState() => _PcdCameraScreenState();
}

class _PcdCameraScreenState extends State<PcdCameraScreen> {
  final _picker = ImagePicker();
  final _pcdController = PcdController();
  
  bool _isProcessing = false;
  String _statusText = '';

  Future<void> _mulaiScan() async {
    try {
      // 1. Ambil Foto Nota
      final notaFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (notaFile == null) return; // User batal

      // 2. Ambil Foto Fisik Barang (untuk PCD)
      // Kasih sedikit delay agar kamera sempat tertutup dan buka lagi dengan mulus
      await Future.delayed(const Duration(milliseconds: 300)); 
      final barangFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (barangFile == null) return; // User batal

      // 3. Masuk ke Fase Pemrosesan PCD
      setState(() {
        _isProcessing = true;
        _statusText = 'Model PCD sedang menganalisis kualitas...';
      });

      final tebakanGrade = await _pcdController.prosesTebakGrade(barangFile.path);

      setState(() => _isProcessing = false);

      // 4. Lempar data ke Form Transaksi Luring
      if (mounted) {
        // Karena ini dalam tab, kita push di atas shell
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransaksiScreen(
              fotoNotaPath: notaFile.path,
              fotoBarangPath: barangFile.path,
              gradeTebakanPcd: tebakanGrade, // Hasil dari ML
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Terjadi kesalahan kamera.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.hijauSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 64, color: AppTheme.hijauMuda),
              ),
              const SizedBox(height: 24),
              const Text('Pemindai Pintar PCD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Siapkan nota fisik dan komoditas di tempat terang untuk akurasi pendeteksian Grade yang maksimal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecond, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 48),
              
              if (_isProcessing) ...[
                const CircularProgressIndicator(color: AppTheme.hijauMuda),
                const SizedBox(height: 16),
                Text(_statusText, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.hijauTua)),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _mulaiScan,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Mulai Pindai Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.hijauMuda,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}