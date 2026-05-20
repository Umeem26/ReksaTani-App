import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/hive/transaksi_hive_model.dart';
import 'app_theme.dart';

class TransaksiDetailSheet extends StatelessWidget {
  final TransaksiHiveModel trx;

  const TransaksiDetailSheet({super.key, required this.trx});

  /// Fungsi bantuan untuk memanggil BottomSheet ini dari mana saja
  static void show(BuildContext context, TransaksiHiveModel trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (_) => TransaksiDetailSheet(trx: trx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSynced = trx.statusSinkronisasi == 'synced';

    return Container(
      height: size.height * 0.85, // Mengambil 85% layar
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ─── 1. HEADER (HANDLE & TITLE) ───
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgPage,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rincian Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      // Badge Status Sync
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSynced ? AppTheme.hijauSoft : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded, size: 14, color: isSynced ? AppTheme.hijauTua : const Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(isSynced ? 'Tersinkron' : 'Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSynced ? AppTheme.hijauTua : const Color(0xFFD97706))),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. KONTEN SCROLLABLE ───
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Komoditas Utama
                  Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(color: AppTheme.hijauMuda, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('🌾', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trx.namaKomoditas, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Grade ${trx.gradeTerpilih} • ${_fmtWaktu(trx.createdAt)}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Data Mitra & Finansial
                  const Text('Rincian Pembayaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecoration(radius: 20),
                    child: Column(
                      children: [
                        _buildRow('Nama Petani', trx.namaPetani, isBold: true),
                        const Divider(color: AppTheme.border, height: 24),
                        _buildRow('Volume Panen', '${trx.berat.toStringAsFixed(1)} kg'),
                        const SizedBox(height: 12),
                        _buildRow('Harga /kg', _fmtRupiah(trx.hargaBeliSatuan)),
                        const SizedBox(height: 12),
                        _buildRow('Potongan Kasbon', '- ${_fmtRupiah(trx.nominalPotongKasbon)}', textColor: AppTheme.merah),
                        const Divider(color: AppTheme.border, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Diterima', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            Text(_fmtRupiah(trx.totalBayar - trx.nominalPotongKasbon), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.hijauMuda)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bukti Dokumentasi (Foto)
                  const Text('Dokumentasi Luring', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildPhotoCard('Foto Fisik', trx.fotoFisikBarang)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPhotoCard('Foto Nota', trx.fotoNota)),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Komponen baris teks
  Widget _buildRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: textColor ?? AppTheme.textPrimary)),
      ],
    );
  }

  // Komponen penampil foto pintar (Deteksi lokal vs web)
  Widget _buildPhotoCard(String label, String path) {
    final bool isNetwork = path.startsWith('http');
    final bool isEmpty = path.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.bgPage,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.image_not_supported_rounded, color: AppTheme.textHint, size: 30), SizedBox(height: 8), Text('Tidak ada', style: TextStyle(color: AppTheme.textHint, fontSize: 11))],
                )
              : (isNetwork
                  ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textHint))
                  : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textHint))),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecond)),
      ],
    );
  }

  String _fmtWaktu(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtRupiah(double angka) {
    final s = angka.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${buf.toString()}';
  }
}