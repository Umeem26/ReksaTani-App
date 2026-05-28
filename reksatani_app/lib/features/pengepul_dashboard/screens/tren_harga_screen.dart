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

class _TrenHargaScreenState extends State<TrenHargaScreen> with SingleTickerProviderStateMixin {
  late final TrenHargaController _ctrl;
  late final AnimationController _chartAnimCtrl;
  late final Animation<double> _chartAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = TrenHargaController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    _chartAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _chartAnim = CurvedAnimation(parent: _chartAnimCtrl, curve: Curves.easeInOutQuart);
    _chartAnimCtrl.forward();
  }

  @override
  void dispose() {
    _chartAnimCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KITA KEMBALI MENGGUNAKAN LOGIKA ASLI DARI CONTROLLERMU
    final item = _ctrl.itemTerpilih;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text('Analitik Tren Pasar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
          ),
        ),
        body: _ctrl.daftarTren.isEmpty
            ? const Center(child: Text('Data komoditas belum tersedia.', style: TextStyle(color: AppTheme.textHint)))
            : Column(
                children: [
                  // ── INOVASI: Floating Dropdown Selector ──
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('KOMODITAS AKTIF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecond, letterSpacing: 1.0)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.bgPage,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border, width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            // MENGGUNAKAN SELECTED INDEX SESUAI LOGIKAMU
                            child: DropdownButton<int>(
                              value: _ctrl.selectedIndex,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.hijauTua, size: 28),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              items: List.generate(_ctrl.daftarTren.length, (index) {
                                final currentItem = _ctrl.daftarTren[index];
                                return DropdownMenuItem<int>(
                                  value: index,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                        child: const Text('🌾', style: TextStyle(fontSize: 14)),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('${currentItem.namaKomoditas} - Grade ${currentItem.grade}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                                    ],
                                  ),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) {
                                  _ctrl.setSelectedIndex(val); // Fungsi ASLI dari controllermu
                                  _chartAnimCtrl.forward(from: 0.0); // Reset animasi chart
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── KONTEN UTAMA TREN ──
                  if (item != null)
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                        children: [
                          // ── Bento Chart Card ──
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 25, offset: const Offset(0, 10))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.show_chart_rounded, color: AppTheme.hijauTua, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Pergerakan Harga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                                      ],
                                    ),
                                    // Badge Persentase Naik/Turun
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
                                            size: 14, color: item.isNaik ? AppTheme.hijauTua : AppTheme.merah,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${item.isNaik ? '+' : ''}${item.persentasePerubahan.toStringAsFixed(1)}%',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: item.isNaik ? AppTheme.hijauTua : AppTheme.merah),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                
                                // Canvas Grafik (Menggunakan riwayat7Hari asli)
                                SizedBox(
                                  height: 200,
                                  width: double.infinity,
                                  child: AnimatedBuilder(
                                    animation: _chartAnim,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: _TrendChartPainter(
                                          data: item.riwayat7Hari, // List<double> ASLI
                                          progress: _chartAnim.value,
                                          lineColor: AppTheme.hijauMuda,
                                          gradientStart: AppTheme.hijauMuda.withOpacity(0.35),
                                          gradientEnd: AppTheme.hijauMuda.withOpacity(0.0),
                                        ),
                                      );
                                    }
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Info Harga Saat ini
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.headerGradient,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Harga Hari Ini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('Rp ${_fmt(item.hargaSaatIni.toInt())}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white, letterSpacing: -0.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Header History ──
                          const Row(
                            children: [
                              Icon(Icons.history_rounded, color: AppTheme.textSecond, size: 22),
                              SizedBox(width: 10),
                              Text('Riwayat 7 Hari Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Daftar Riwayat bergaya TIMELINE (Menggunakan riwayat7Hari asli) ──
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
                            ),
                            child: Column(
                              children: List.generate(item.riwayat7Hari.length, (idx) {
                                // Membalik urutan agar Hari ini paling atas
                                final indexReversed = item.riwayat7Hari.length - 1 - idx;
                                final harga = item.riwayat7Hari[indexReversed];
                                final labelHari = indexReversed == 6 ? 'Hari Ini' : 'H-${6 - indexReversed}';

                                return _TimelineRow(
                                  tanggal: labelHari,
                                  harga: harga,
                                  isFirst: idx == 0,
                                  isLast: idx == item.riwayat7Hari.length - 1,
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _fmt(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── WIDGET: Baris Timeline Riwayat Prediksi ──
class _TimelineRow extends StatelessWidget {
  final String tanggal;
  final double harga;
  final bool isFirst;
  final bool isLast;
  
  const _TimelineRow({required this.tanggal, required this.harga, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kolom Kiri: Garis dan Titik Timeline
          SizedBox(
            width: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isLast)
                  Positioned(
                    top: 24, bottom: -24,
                    child: Container(width: 2, color: AppTheme.border),
                  ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: isFirst ? AppTheme.hijauMuda : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isFirst ? AppTheme.hijauMuda : AppTheme.textHint, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Kolom Kanan: Konten Kartu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tanggal, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isFirst ? AppTheme.textPrimary : AppTheme.textSecond)),
                      const SizedBox(height: 4),
                      Text(isFirst ? 'Harga Terkini' : 'Riwayat', style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(
                    'Rp ${_fmt(harga.toInt())}',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isFirst ? AppTheme.hijauTua : AppTheme.textSecond, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── CUSTOM PAINTER UNTUK GRAFIK (Menerima List<double> ASLI) ──
class _TrendChartPainter extends CustomPainter {
  final List<double> data;
  final double progress; 
  final Color lineColor;
  final Color gradientStart;
  final Color gradientEnd;

  _TrendChartPainter({
    required this.data,
    required this.progress,
    required this.lineColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double maxHarga = data.reduce((a, b) => a > b ? a : b) * 1.05;
    final double minHarga = data.reduce((a, b) => a < b ? a : b) * 0.95;
    final double rangeHarga = maxHarga - minHarga == 0 ? 1 : maxHarga - minHarga;

    final double stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    // 1. Gambar Garis Grid Latar Belakang (Dashed Line)
    final Paint gridPaint = Paint()..color = AppTheme.border.withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 1; i <= 4; i++) {
      double y = size.height * (i / 4);
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Koordinat Titik
    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final double h = data[i];
      final double x = i * stepX;
      final double y = size.height - ((h - minHarga) / rangeHarga * size.height);
      points.add(Offset(x, y));
    }

    // 2. Buat Jalur Utama (Bézier Curve Mulus)
    final Path fullPath = Path();
    if (points.length > 1) {
      fullPath.moveTo(points.first.dx, points.first.dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final control1 = Offset(p0.dx + stepX / 2, p0.dy);
        final control2 = Offset(p0.dx + stepX / 2, p1.dy);
        fullPath.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, p1.dx, p1.dy);
      }
    }

    // Memotong Jalur Berdasarkan Progress Animasi
    final PathMetrics pathMetrics = fullPath.computeMetrics();
    final Path animatedPath = Path();
    for (PathMetric metric in pathMetrics) {
      animatedPath.addPath(metric.extractPath(0.0, metric.length * progress), Offset.zero);
    }

    // 3. Area Gradien (Hanya digambar sejauh progress garis)
    if (points.length > 1) {
      final Path fillPath = Path.from(animatedPath);
      final double currentMaxX = points.last.dx * progress;
      fillPath.lineTo(currentMaxX, size.height);
      fillPath.lineTo(points.first.dx, size.height);
      fillPath.close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [gradientStart, gradientEnd],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));
      
      canvas.drawPath(fillPath, fillPaint);
    }

    // 4. Garis Utama (Stroke)
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(animatedPath, linePaint);

    // 5. Gambar Titik-titik Data (Dots) yang masuk area progress
    final Paint dotPaintOuter = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final Paint dotPaintInner = Paint()..color = lineColor..style = PaintingStyle.fill;
    
    for (var point in points) {
      if (point.dx <= size.width * progress) {
        canvas.drawCircle(point, 6, dotPaintOuter);
        canvas.drawCircle(point, 4, dotPaintInner);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const int dashWidth = 6;
    const int dashSpace = 6;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(Offset(startX, p1.dy), Offset(startX + dashWidth, p1.dy), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => oldDelegate.progress != progress;
}