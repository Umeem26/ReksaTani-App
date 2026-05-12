import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../controllers/tren_harga_controller.dart';

class TrenHargaScreen extends StatefulWidget {
  const TrenHargaScreen({super.key});

  @override
  State<TrenHargaScreen> createState() => _TrenHargaScreenState();
}

class _TrenHargaScreenState extends State<TrenHargaScreen> {
  late final TrenHargaController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TrenHargaController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _ctrl.itemTerpilih;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Analitik Tren Pasar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border),
          ),
        ),
        body: _ctrl.daftarTren.isEmpty
            ? const Center(child: Text('Data komoditas belum tersedia.', style: TextStyle(color: AppTheme.textHint)))
            : Column(
                children: [
                  // ─── 1. KAPSUL PILIHAN KOMODITAS (SCROLLABLE) ───
                  Container(
                    color: AppTheme.bgCard,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: List.generate(_ctrl.daftarTren.length, (i) {
                          final current = _ctrl.daftarTren[i];
                          final isActive = _ctrl.selectedIndex == i;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${current.namaKomoditas} (${current.grade})'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                color: isActive ? Colors.white : AppTheme.textSecond,
                              ),
                              selected: isActive,
                              showCheckmark: false,
                              selectedColor: AppTheme.hijauTua,
                              backgroundColor: AppTheme.bgPage,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isActive ? AppTheme.hijauTua : AppTheme.border),
                              ),
                              onSelected: (_) {
                                _ctrl.setSelectedIndex(i);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // ─── 2. KONTEN UTAMA TREN ───
                  if (item != null)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kartu Utama Harga & Indikator
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: AppTheme.cardDecoration(radius: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          'Grade ${item.grade}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.hijauTua),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: item.isNaik ? AppTheme.hijauSoft : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              item.isNaik ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                              size: 14,
                                              color: item.isNaik ? AppTheme.hijauTua : AppTheme.merah,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '+${item.persentasePerubahan.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: item.isNaik ? AppTheme.hijauTua : AppTheme.merah,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    item.namaKomoditas,
                                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecond, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        _fmtRupiah(item.hargaSaatIni),
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
                                      ),
                                      Text(
                                        ' /${item.satuan}',
                                        style: const TextStyle(fontSize: 13, color: AppTheme.textHint, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),

                                  // ─── GRAFIK GARIS KUSTOM (BEZIER SHADER) ───
                                  SizedBox(
                                    height: 160,
                                    width: double.infinity,
                                    child: CustomPaint(
                                      painter: _TrendChartPainter(
                                        data: item.riwayat7Hari,
                                        lineColor: AppTheme.hijauMuda,
                                        gradientStart: AppTheme.hijauMuda.withOpacity(0.35),
                                        gradientEnd: AppTheme.hijauMuda.withOpacity(0.0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Label Hari di Bawah Grafik
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: ['H-6', 'H-5', 'H-4', 'H-3', 'H-2', 'H-1', 'Hari ini']
                                        .map((hari) => Text(hari, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sub-judul Breakdown
                            const Text('Rincian Pergerakan Harga', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            const SizedBox(height: 12),

                            // Daftar Kartu Histori 7 Hari
                            ...List.generate(item.riwayat7Hari.length, (idx) {
                              // Membalik urutan agar Hari ini paling atas
                              final indexReversed = item.riwayat7Hari.length - 1 - idx;
                              final harga = item.riwayat7Hari[indexReversed];
                              final labelHari = indexReversed == 6 ? 'Harga Hari Ini' : 'H-${6 - indexReversed}';
                              
                              // Selisih dengan hari sebelumnya
                              double selisih = 0;
                              if (indexReversed > 0) {
                                selisih = harga - item.riwayat7Hari[indexReversed - 1];
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: AppTheme.cardDecoration(radius: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: indexReversed == 6 ? AppTheme.hijauMuda : AppTheme.border,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(labelHari, style: TextStyle(fontSize: 12.5, fontWeight: indexReversed == 6 ? FontWeight.w700 : FontWeight.w600, color: AppTheme.textPrimary)),
                                          const SizedBox(height: 2),
                                          Text('Estimasi sistem', style: const TextStyle(fontSize: 10.5, color: AppTheme.textHint)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_fmtRupiah(harga), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: indexReversed == 6 ? AppTheme.hijauTua : AppTheme.textPrimary)),
                                        if (indexReversed > 0 && selisih != 0) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            selisih > 0 ? '+${_fmtRupiah(selisih)}' : _fmtRupiah(selisih),
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selisih > 0 ? AppTheme.hijauTua : AppTheme.merah),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _fmtRupiah(double angka) {
    final isMinus = angka < 0;
    final s = angka.abs().toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${isMinus ? "-" : ""}Rp ${buf.toString()}';
  }
}

// ─── ALGORITMA SHADER GRAFIK GARIS KUSTOM ───
class _TrendChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color gradientStart;
  final Color gradientEnd;

  _TrendChartPainter({
    required this.data,
    required this.lineColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Batas bawah dan atas dinamis agar grafik terisi penuh secara estetik
    final double minVal = data.reduce((a, b) => a < b ? a : b) * 0.98;
    final double maxVal = data.reduce((a, b) => a > b ? a : b) * 1.01;
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final Path path = Path();
    final Path fillPath = Path();

    final double stepX = size.width / (data.length - 1);
    final List<Offset> points = [];

    // Kalkulasi titik koordinat piksel
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = size.height - ((data[i] - minVal) / range) * size.height;
      points.add(Offset(x, y));
    }

    // Pindah ke titik awal
    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    // Menggambar kurva Bezier (Cubic) halus melintasi semua titik
    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final Offset control1 = Offset(p0.dx + stepX / 2, p0.dy);
      final Offset control2 = Offset(p0.dx + stepX / 2, p1.dy);

      path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // 1. Eksekusi rendering Shader Gradien di bawah kurva
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientStart, gradientEnd],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 2. Eksekusi rendering Garis Utama
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // 3. Eksekusi rendering Titik Node
    final Paint outerDot = Paint()..color = lineColor..style = PaintingStyle.fill;
    final Paint innerDot = Paint()..color = Colors.white..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 5.5, outerDot);
      canvas.drawCircle(p, 3.0, innerDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}