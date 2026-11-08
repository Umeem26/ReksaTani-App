import 'package:flutter/material.dart';

import '../../../shared/widgets/app_theme.dart';
import '../services/grading_rubric.dart';

/// Label wajib di UI: rubrik masih draf.
const String labelDrafRubrik = 'Draf rubrik v0.1, belum disahkan ahli';

/// Saran komoditas dari AI. Tanpa saran ([labelSaran] null), kartu meminta
/// pengguna memilih manual. Hanya komoditas yang disarankan, tidak pernah grade.
class KartuSaranKomoditas extends StatelessWidget {
  /// Label router ('gabah', 'kelapa_sawit', 'kopi'), atau null.
  final String? labelSaran;
  final double? keyakinan;
  final VoidCallback? onGanti;

  const KartuSaranKomoditas({super.key, this.labelSaran, this.keyakinan, this.onGanti});

  @override
  Widget build(BuildContext context) {
    final label = labelSaran;
    final adaSaran = label != null && label.isNotEmpty;
    final nama = adaSaran ? (rubrikUntukLabel(label)?.nama ?? label) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adaSaran ? AppTheme.hijauSoft : AppTheme.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: adaSaran ? AppTheme.hijauMuda.withValues(alpha: 0.4) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                adaSaran ? Icons.auto_awesome_rounded : Icons.touch_app_rounded,
                size: 20,
                color: adaSaran ? AppTheme.hijauTua : AppTheme.textSecond,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adaSaran ? 'Saran komoditas (AI)' : 'Tidak ada saran komoditas',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecond),
                    ),
                    const SizedBox(height: 4),
                    if (adaSaran)
                      Text(
                        '$nama · keyakinan ${((keyakinan ?? 0) * 100).round()}%',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      adaSaran
                          ? 'Hanya saran. Periksa foto, ganti bila tidak sesuai.'
                          : 'Pilih komoditas secara manual.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (adaSaran && onGanti != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onGanti,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Ganti komoditas', style: TextStyle(fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.hijauTua,
                side: const BorderSide(color: AppTheme.hijauMuda),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Checklist rubrik. Grade tampil hanya bila [grade] terisi, yaitu sesudah
/// semua pertanyaan dijawab.
class ChecklistRubrik extends StatelessWidget {
  final RubrikKomoditas rubrik;
  final Map<String, String> jawaban;
  final void Function(String pertanyaan, String opsi) onJawab;

  /// Hasil [gradeDariJawaban]; null bila checklist belum lengkap.
  final String? grade;

  /// Batas harga grade dari master data, untuk keterangan saja.
  final double? hargaMaks;

  /// Grade transaksi lama yang belum pernah diisi checklist (mode edit).
  final String? gradeTersimpan;

  const ChecklistRubrik({
    super.key,
    required this.rubrik,
    required this.jawaban,
    required this.onJawab,
    this.grade,
    this.hargaMaks,
    this.gradeTersimpan,
  });

  @override
  Widget build(BuildContext context) {
    final terjawab = rubrik.pertanyaan.where((p) => p.opsiDenganKode(jawaban[p.kode]) != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            labelDrafRubrik,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
          ),
        ),
        for (final c in rubrik.catatan)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(c, style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, height: 1.3)),
          ),
        for (final p in rubrik.pertanyaan) ...[
          const SizedBox(height: 16),
          Text(p.teks, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.3)),
          const SizedBox(height: 6),
          for (final o in p.opsi)
            _OpsiTile(
              label: o.label,
              terpilih: jawaban[p.kode] == o.kode,
              onTap: () => onJawab(p.kode, o.kode),
            ),
        ],
        const SizedBox(height: 16),
        _HasilGrade(
          grade: grade,
          hargaMaks: hargaMaks,
          gradeTersimpan: gradeTersimpan,
          terjawab: terjawab,
          total: rubrik.pertanyaan.length,
        ),
      ],
    );
  }
}

class _OpsiTile extends StatelessWidget {
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  const _OpsiTile({required this.label, required this.terpilih, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: terpilih,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: terpilih ? AppTheme.hijauSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: terpilih ? AppTheme.hijauMuda : AppTheme.border, width: terpilih ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(
                terpilih ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: terpilih ? AppTheme.hijauTua : AppTheme.textSecond,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HasilGrade extends StatelessWidget {
  final String? grade;
  final double? hargaMaks;
  final String? gradeTersimpan;
  final int terjawab;
  final int total;

  const _HasilGrade({
    required this.grade,
    required this.hargaMaks,
    required this.gradeTersimpan,
    required this.terjawab,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final g = grade;
    final String judul;
    final String keterangan;
    if (g != null) {
      judul = 'Grade $g';
      final maks = hargaMaks ?? 0;
      keterangan = maks > 0 ? 'Hasil checklist · maks Rp ${_rupiah(maks.toInt())}/kg' : 'Hasil checklist';
    } else if (gradeTersimpan != null && gradeTersimpan!.isNotEmpty) {
      judul = 'Grade tersimpan: $gradeTersimpan';
      keterangan = 'Transaksi ini belum punya checklist. Isi checklist untuk menilai ulang.';
    } else {
      judul = 'Grade belum ditentukan';
      keterangan = 'Jawab semua pertanyaan ($terjawab/$total) untuk melihat grade.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: g != null ? AppTheme.hijauSoft : AppTheme.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g != null ? AppTheme.hijauMuda : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: g != null ? AppTheme.hijauTua : AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(keterangan, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond, height: 1.3)),
        ],
      ),
    );
  }

  static String _rupiah(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
