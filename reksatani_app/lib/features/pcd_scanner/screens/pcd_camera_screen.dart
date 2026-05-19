import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        imageQuality: 65, // Kompresi optimal agar memori database lokal tetap ringan
      );

      if (photo != null) {
        setState(() {
          if (isNota) {
            _fotoNotaPath = photo.path;
          } else {
            _fotoBarangPath = photo.path;
          }
        });
        HapticFeedback.lightImpact(); // Umpan balik taktil saat foto berhasil ditangkap
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Gagal mengakses modul kamera perangkat.', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
              ],
            ),
            backgroundColor: AppTheme.merah,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    }
  }

  // ─── PERBAIKAN LOGIKA: MENUNGGU STATE DAN RESET FOTO ───
  Future<void> _lanjutKeForm() async {
    if (_fotoNotaPath != null && _fotoBarangPath != null) {
      // Tunggu kembalian dari TransaksiScreen
      final isDisimpan = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TransaksiScreen(
            fotoNotaPath: _fotoNotaPath,
            fotoBarangPath: _fotoBarangPath,
          ),
        ),
      );

      // Jika transaksi sukses disimpan (mengembalikan true), langsung bersihkan form kamera
      if (isDisimpan == true && mounted) {
        setState(() {
          _fotoNotaPath = null;
          _fotoBarangPath = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int fotoLengkapCount = (_fotoNotaPath != null ? 1 : 0) + (_fotoBarangPath != null ? 1 : 0);
    final bool isLengkap = fotoLengkapCount == 2;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Dokumentasi Transaksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border),
          ),
          actions: [
            // Indikator kelengkapan foto
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLengkap ? AppTheme.hijauSoft : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isLengkap ? AppTheme.hijauMuda.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Text(
                  '$fotoLengkapCount/2 Foto',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLengkap ? AppTheme.hijauTua : const Color(0xFF92400E),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Informasi
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.document_scanner_rounded, color: AppTheme.hijauMuda, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Langkah 1: Bukti Autentik',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Ambil foto nota timbangan dan fisik komoditas secara jelas. Data visual ini akan digunakan untuk persiapan validasi mutu otomatis (PCD).',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecond, height: 1.5),
              ),
              const SizedBox(height: 24),

              // KOTAK 1: FOTO NOTA
              _buildPhotoCard(
                title: 'Foto Nota / Bukti Timbang',
                subtitle: 'Pastikan angka berat terbaca jelas',
                icon: Icons.receipt_long_rounded,
                imagePath: _fotoNotaPath,
                onTap: () => _ambilFoto(true),
              ),
              const SizedBox(height: 20),

              // KOTAK 2: FOTO BARANG
              _buildPhotoCard(
                title: 'Foto Fisik Komoditas',
                subtitle: 'Pencahayaan terang & fokus pada tekstur',
                icon: Icons.grass_rounded,
                imagePath: _fotoBarangPath,
                onTap: () => _ambilFoto(false),
              ),
              const SizedBox(height: 32),

              // Tombol Lanjut
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLengkap ? _lanjutKeForm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hijauMuda,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.border.withOpacity(0.6),
                    elevation: isLengkap ? 4 : 0,
                    shadowColor: AppTheme.hijauMuda.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLengkap ? 'Lanjut Isi Data Transaksi' : 'Lengkapi Foto Terlebih Dahulu',
                        style: TextStyle(
                          fontWeight: FontWeight.w800, 
                          fontSize: 14, 
                          color: isLengkap ? Colors.white : AppTheme.textHint,
                        ),
                      ),
                      if (isLengkap) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET PEMBANGUN KARTU FOTO PREMIUM ---
  Widget _buildPhotoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? imagePath,
    required VoidCallback onTap,
  }) {
    final hasImage = imagePath != null;

    return Container(
      decoration: AppTheme.cardDecoration(radius: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul Kartu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                  ],
                ),
              ),
              // Tombol ganti foto melayang jika sudah ada gambar
              if (hasImage)
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.hijauSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cameraswitch_rounded, size: 13, color: AppTheme.hijauTua),
                        SizedBox(width: 4),
                        Text('Retake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.hijauTua)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Area Gambar / Wadah Kamera
          GestureDetector(
            onTap: hasImage ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 175,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: hasImage ? Colors.black : AppTheme.bgPage,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasImage ? AppTheme.hijauMuda : AppTheme.border,
                  width: hasImage ? 2 : 1.5,
                ),
                boxShadow: hasImage 
                    ? [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Tampilan Gambar Asli
                  if (hasImage)
                    Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                    )
                  // Tampilan Placeholder belum ada foto
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 55, height: 55,
                          decoration: BoxDecoration(
                            color: AppTheme.hijauSoft.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 26, color: AppTheme.hijauMuda),
                        ),
                        const SizedBox(height: 12),
                        const Text('Ketuk untuk membuka kamera', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        const Text('Format terkompresi otomatis', style: TextStyle(color: AppTheme.textHint, fontSize: 10.5)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}