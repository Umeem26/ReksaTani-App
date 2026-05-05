import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../../../shared/widgets/app_theme.dart';

class PcdCameraScreen extends StatefulWidget {
  const PcdCameraScreen({super.key});

  @override
  State<PcdCameraScreen> createState() => _PcdCameraScreenState();
}

class _PcdCameraScreenState extends State<PcdCameraScreen> {
  final _picker = ImagePicker();
  String? _fotoNotaPath;
  String? _fotoBarangPath;

  Future<void> _ambilFoto(bool isNota) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60, // Kompresi agar database lokal tidak bengkak
      );

      if (photo != null) {
        setState(() {
          if (isNota) {
            _fotoNotaPath = photo.path;
          } else {
            _fotoBarangPath = photo.path;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka kamera.')),
      );
    }
  }

  void _lanjutKeForm() {
    if (_fotoNotaPath != null && _fotoBarangPath != null) {
      // Beralih ke layar form transaksi dan bawa path fotonya
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransaksiScreen(
            fotoNotaPath: _fotoNotaPath,
            fotoBarangPath: _fotoBarangPath,
            // gradeTebakanPcd sengaja tidak dikirim agar pengepul memilih manual
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLengkap = _fotoNotaPath != null && _fotoBarangPath != null;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Dokumentasi Transaksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ambil Foto Bukti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mohon lengkapi dua foto di bawah ini sebelum mengisi data transaksi komoditas.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecond, height: 1.5),
            ),
            const SizedBox(height: 24),

            // KOTAK 1: FOTO NOTA
            _buildPhotoBox(
              title: 'Foto Nota / Catatan Timbangan',
              icon: Icons.receipt_long_rounded,
              imagePath: _fotoNotaPath,
              onTap: () => _ambilFoto(true),
            ),
            const SizedBox(height: 20),

            // KOTAK 2: FOTO BARANG (PCD PREPARATION)
            _buildPhotoBox(
              title: 'Foto Fisik Komoditas',
              icon: Icons.grass_rounded,
              imagePath: _fotoBarangPath,
              onTap: () => _ambilFoto(false),
            ),
            const SizedBox(height: 40),

            // TOMBOL LANJUT
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLengkap ? _lanjutKeForm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauMuda,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Lanjut Isi Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required String title,
    required IconData icon,
    required String? imagePath,
    required VoidCallback onTap,
  }) {
    final hasImage = imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasImage ? Colors.black : AppTheme.hijauSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasImage ? AppTheme.hijauMuda : AppTheme.hijauMuda.withOpacity(0.3),
                width: hasImage ? 2 : 1,
              ),
              image: hasImage
                  ? DecorationImage(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.cover,
                      opacity: 0.8,
                    )
                  : null,
            ),
            child: hasImage
                ? const Center(
                    child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 40, color: AppTheme.hijauMuda),
                      const SizedBox(height: 12),
                      const Text('Ketuk untuk memotret', style: TextStyle(color: AppTheme.hijauTua, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}