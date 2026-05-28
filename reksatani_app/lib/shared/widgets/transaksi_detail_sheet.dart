import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/hive/transaksi_hive_model.dart';
import 'app_theme.dart';

class TransaksiDetailSheet extends StatelessWidget {
  final TransaksiHiveModel trx;

  const TransaksiDetailSheet({super.key, required this.trx});

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
    final bool isKasbonMurni = trx.namaKomoditas.toLowerCase().contains('pencairan kasbon');

    return Container(
      height: size.height * 0.88, 
      decoration: const BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ─── 1. HEADER ───
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Detail Transaksi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.bgPage, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecond)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. KONTEN (DIGITAL INVOICE) ───
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                // Badge Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSynced ? AppTheme.hijauSoft : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSynced ? AppTheme.hijauMuda.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded, color: isSynced ? AppTheme.hijauTua : const Color(0xFFB45309), size: 18),
                      const SizedBox(width: 8),
                      Text(isSynced ? 'Data telah tersinkronisasi ke server' : 'Data pending (menunggu sinkronisasi)', style: TextStyle(color: isSynced ? AppTheme.hijauTua : const Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Kartu Info Invoice Utama
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      // Section: Profil
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: isKasbonMurni ? const Color(0xFFFEF3C7) : AppTheme.hijauSoft, borderRadius: BorderRadius.circular(16)),
                              child: Center(child: isKasbonMurni ? const Icon(Icons.payments_rounded, color: Color(0xFFF59E0B)) : const Text('🌾', style: TextStyle(fontSize: 22))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isKasbonMurni ? 'Pencairan Kasbon' : trx.namaKomoditas, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isKasbonMurni ? const Color(0xFFB45309) : AppTheme.textPrimary, letterSpacing: -0.5)),
                                  const SizedBox(height: 4),
                                  Text('Mitra: ${trx.namaPetani}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Dashed Divider
                      Row(
                        children: List.generate(30, (i) => Expanded(child: Container(height: 1, color: i.isEven ? AppTheme.border : Colors.transparent))),
                      ),

                      // Section: Detail Rincian
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _InfoRow(label: 'Waktu Transaksi', value: _fmtWaktu(trx.createdAt)),
                            if (!isKasbonMurni) ...[
                              const SizedBox(height: 12),
                              _InfoRow(label: 'Grade Kualitas', value: 'Grade ${trx.gradeTerpilih}'),
                              const SizedBox(height: 12),
                              _InfoRow(label: 'Kuantitas / Berat', value: '${trx.berat.toInt()} kg'),
                              const SizedBox(height: 12),
                              _InfoRow(label: 'Harga per kg', value: _fmtRupiah(trx.hargaBeliSatuan)),
                            ],
                            if (trx.nominalPotongKasbon > 0) ...[
                              const SizedBox(height: 12),
                              _InfoRow(label: 'Potong Hutang Kasbon', value: '- ${_fmtRupiah(trx.nominalPotongKasbon)}', isMinus: true),
                            ],
                          ],
                        ),
                      ),
                      
                      Container(height: 1, color: AppTheme.border.withOpacity(0.5)),

                      // Section: Total Bayar Highlight
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(color: isKasbonMurni ? const Color(0xFFFEF3C7).withOpacity(0.5) : AppTheme.hijauSoft.withOpacity(0.5), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isKasbonMurni ? 'Nominal Kasbon' : 'Total Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isKasbonMurni ? const Color(0xFF92400E) : AppTheme.hijauTua)),
                            Text(_fmtRupiah(trx.totalBayar), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isKasbonMurni ? const Color(0xFFB45309) : AppTheme.hijauTua, letterSpacing: -0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─── 3. BUKTI FOTO ───
                if (!isKasbonMurni) ...[
                  const Text('LAMPIRAN BUKTI FISIK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecond, letterSpacing: 1.0)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _PhotoBox(path: trx.fotoNota, label: 'Nota / Kwitansi')),
                      const SizedBox(width: 16),
                      Expanded(child: _PhotoBox(path: trx.fotoFisikBarang, label: 'Komoditas')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

// ── KOMPONEN BANTUAN ──
class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool isMinus;
  const _InfoRow({required this.label, required this.value, this.isMinus = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isMinus ? AppTheme.merah : AppTheme.textPrimary)),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String? path;
  final String label;

  const _PhotoBox({required this.path, required this.label});

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = path == null || path!.isEmpty;
    final bool isNetwork = !isEmpty && path!.startsWith('http');

    return Column(
      children: [
        Container(
          height: 130, // Aspect ratio lebih elegan
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.bgPage, shape: BoxShape.circle), child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.textHint, size: 24)), 
                      const SizedBox(height: 8), 
                      const Text('Tidak ada', style: TextStyle(color: AppTheme.textHint, fontSize: 12, fontWeight: FontWeight.w600))
                    ],
                  )
                : (isNetwork
                    ? Image.network(path!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textHint))
                    : Image.file(File(path!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textHint))),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
      ],
    );
  }
}