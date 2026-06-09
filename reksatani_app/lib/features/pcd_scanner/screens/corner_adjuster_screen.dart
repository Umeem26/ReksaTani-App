import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/widgets/app_theme.dart';

class CornerAdjusterScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset>? initialCorners;

  const CornerAdjusterScreen({
    super.key,
    required this.imagePath,
    this.initialCorners,
  });

  @override
  State<CornerAdjusterScreen> createState() => _CornerAdjusterScreenState();
}

class _CornerAdjusterScreenState extends State<CornerAdjusterScreen> {
  double? _imageWidth;
  double? _imageHeight;
  late List<Offset> _corners;
  int? _activeDragIndex;

  @override
  void initState() {
    super.initState();
    _corners = widget.initialCorners != null && widget.initialCorners!.length == 4
        ? List<Offset>.from(widget.initialCorners!)
        : [
            const Offset(0.15, 0.15), // TL
            const Offset(0.85, 0.15), // TR
            const Offset(0.85, 0.85), // BR
            const Offset(0.15, 0.85), // BL
          ];

    _resolveImageDimensions();
  }

  void _resolveImageDimensions() {
    final ImageProvider provider = FileImage(File(widget.imagePath));
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_imageWidth == null || _imageHeight == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.hijauMuda),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sesuaikan Sudut Nota',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context, _corners);
            },
            icon: const Icon(Icons.check_rounded, color: AppTheme.hijauMuda),
            label: const Text(
              'SELESAI',
              style: TextStyle(
                color: AppTheme.hijauMuda,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final parentWidth = constraints.maxWidth;
          final parentHeight = constraints.maxHeight;

          // Calculate aspect ratio fit of image in constraints
          double displayedWidth = parentWidth;
          double displayedHeight = parentHeight;
          double dx = 0;
          double dy = 0;

          final imgRatio = _imageWidth! / _imageHeight!;
          final parentRatio = parentWidth / parentHeight;

          if (imgRatio > parentRatio) {
            displayedWidth = parentWidth;
            displayedHeight = parentWidth / imgRatio;
            dy = (parentHeight - displayedHeight) / 2;
          } else {
            displayedHeight = parentHeight;
            displayedWidth = parentHeight * imgRatio;
            dx = (parentWidth - displayedWidth) / 2;
          }

          // Convert normalized corner to screen pixel offset
          Offset toScreen(Offset normalized) {
            return Offset(
              dx + normalized.dx * displayedWidth,
              dy + normalized.dy * displayedHeight,
            );
          }

          // Convert screen pixel offset back to normalized corner
          Offset toNormalized(Offset screenOffset) {
            return Offset(
              ((screenOffset.dx - dx) / displayedWidth).clamp(0.0, 1.0),
              ((screenOffset.dy - dy) / displayedHeight).clamp(0.0, 1.0),
            );
          }

          final List<Offset> screenPoints = _corners.map(toScreen).toList();

          return Stack(
            fit: StackFit.expand,
            children: [
              // Display Image
              Positioned.fill(
                child: Center(
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Paint transparent overlay outside the cropped area, and connection lines
              Positioned.fill(
                child: CustomPaint(
                  painter: CornerCropperOverlayPainter(
                    points: screenPoints,
                    lineColor: AppTheme.hijauMuda,
                  ),
                ),
              ),

              // Interactive Draggable Corner Knobs
              for (int i = 0; i < 4; i++)
                Positioned(
                  left: screenPoints[i].dx - 24, // Touch target diameter = 48
                  top: screenPoints[i].dy - 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      setState(() {
                        _activeDragIndex = i;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        final newPos = screenPoints[i] + details.delta;
                        _corners[i] = toNormalized(newPos);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _activeDragIndex = null;
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.hijauMuda,
                            width: 3.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Zoom Loupe/Magnifying Glass
              if (_activeDragIndex != null)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(60),
                        side: const BorderSide(color: AppTheme.hijauMuda, width: 3),
                      ),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                        child: ClipOval(
                          child: Stack(
                            children: [
                              Transform.scale(
                                scale: 2.2,
                                alignment: Alignment(
                                  -1.0 + 2.0 * _corners[_activeDragIndex!].dx,
                                  -1.0 + 2.0 * _corners[_activeDragIndex!].dy,
                                ),
                                child: Image.file(
                                  File(widget.imagePath),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // Crosshair in center
                              Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.hijauMuda,
                                      width: 2.0,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.add,
                                      size: 8,
                                      color: AppTheme.hijauMuda,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom Guide Text
              Positioned(
                bottom: 24,
                left: 32,
                right: 32,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Geser lingkaran ke 4 sudut nota agar hasil pelurusan (warping) rapi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CornerCropperOverlayPainter extends CustomPainter {
  final List<Offset> points;
  final Color lineColor;

  CornerCropperOverlayPainter({
    required this.points,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;

    // 1. Draw darkening mask overlay outside the crop box
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cropPath = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    final maskPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cropPath,
    );

    final maskPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawPath(maskPath, maskPaint);

    // 2. Draw crop area borders
    final borderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(cropPath, borderPaint);

    // 3. Draw light green inner region fill
    final fillPaint = Paint()..color = lineColor.withOpacity(0.1);
    canvas.drawPath(cropPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CornerCropperOverlayPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
