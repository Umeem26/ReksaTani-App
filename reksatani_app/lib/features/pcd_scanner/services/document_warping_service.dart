import 'dart:io';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class DocumentWarpingService {
  // Mengeksekusi proses pelurusan nota di latar belakang agar UI tidak freeze
  Future<File> warpNota(File imageFile, {List<Offset>? manualCorners}) async {
    final bytes = await imageFile.readAsBytes();

    // Konversi Offset ke List<double> agar aman dikirim ke isolate background
    final List<List<double>>? cornersData = manualCorners?.map((o) => [o.dx, o.dy]).toList();

    final processedBytes = await compute(_eksekusiIsolateWarping, {
      'bytes': bytes,
      'corners': cornersData,
    });

    if (processedBytes != null) {
      final tempDir = imageFile.parent;
      final newFile = File('${tempDir.path}/warped_nota_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(processedBytes);
      return newFile;
    }

    return imageFile; // Kembalikan gambar asli jika deteksi sudut gagal
  }

  static Uint8List? _eksekusiIsolateWarping(Map<String, dynamic> args) {
    final Uint8List bytes = args['bytes'];
    final List<dynamic>? rawCorners = args['corners'];
    List<Offset>? corners;
    if (rawCorners != null) {
      corners = rawCorners.map((e) => Offset((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();
    }
    return _deteksiDanWarping(bytes, manualCorners: corners);
  }

  static Uint8List? _deteksiDanWarping(Uint8List bytes, {List<Offset>? manualCorners}) {
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    // Downscale untuk mempercepat warping dan encoding JPEG
    const maxDimension = 1200;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: maxDimension);
      } else {
        image = img.copyResize(image, height: maxDimension);
      }
    }

    final currentWidth = image.width;
    final currentHeight = image.height;

    img.Point origTl;
    img.Point origTr;
    img.Point origBr;
    img.Point origBl;

    if (manualCorners != null && manualCorners.length == 4) {
      final bool isPortrait = currentHeight > currentWidth;
      if (isPortrait) {
        origTl = img.Point((manualCorners[0].dx * currentWidth).round().clamp(0, currentWidth - 1), (manualCorners[0].dy * currentHeight).round().clamp(0, currentHeight - 1));
        origTr = img.Point((manualCorners[1].dx * currentWidth).round().clamp(0, currentWidth - 1), (manualCorners[1].dy * currentHeight).round().clamp(0, currentHeight - 1));
        origBr = img.Point((manualCorners[2].dx * currentWidth).round().clamp(0, currentWidth - 1), (manualCorners[2].dy * currentHeight).round().clamp(0, currentHeight - 1));
        origBl = img.Point((manualCorners[3].dx * currentWidth).round().clamp(0, currentWidth - 1), (manualCorners[3].dy * currentHeight).round().clamp(0, currentHeight - 1));
      } else {
        // Landscape rotation (90 degrees clockwise rotation from landscape to portrait preview)
        // Screen TL (corners[0]) -> Landscape BL
        // Screen TR (corners[1]) -> Landscape TL
        // Screen BR (corners[2]) -> Landscape TR
        // Screen BL (corners[3]) -> Landscape BR
        
        Offset mapLandscape(Offset screenOffset) {
          // nx = 1.0 - (imgY / originalHeight) => imgY = (1.0 - nx) * originalHeight
          // ny = imgX / originalWidth => imgX = ny * originalWidth
          double imgX = screenOffset.dy * currentWidth;
          double imgY = (1.0 - screenOffset.dx) * currentHeight;
          return Offset(imgX, imgY);
        }

        final tlMapped = mapLandscape(manualCorners[1]); // Screen TR -> Landscape TL
        final trMapped = mapLandscape(manualCorners[2]); // Screen BR -> Landscape TR
        final brMapped = mapLandscape(manualCorners[3]); // Screen BL -> Landscape BR
        final blMapped = mapLandscape(manualCorners[0]); // Screen TL -> Landscape BL

        origTl = img.Point(tlMapped.dx.round().clamp(0, currentWidth - 1), tlMapped.dy.round().clamp(0, currentHeight - 1));
        origTr = img.Point(trMapped.dx.round().clamp(0, currentWidth - 1), trMapped.dy.round().clamp(0, currentHeight - 1));
        origBr = img.Point(brMapped.dx.round().clamp(0, currentWidth - 1), brMapped.dy.round().clamp(0, currentHeight - 1));
        origBl = img.Point(blMapped.dx.round().clamp(0, currentWidth - 1), blMapped.dy.round().clamp(0, currentHeight - 1));
      }
    } else {
      // Lakukan downscale untuk pemrosesan deteksi sudut yang cepat & responsif
      const maxDimensionAngle = 600;
      img.Image processingImage = image;
      double scale = 1.0;
      if (currentWidth > maxDimensionAngle || currentHeight > maxDimensionAngle) {
        if (currentWidth > currentHeight) {
          scale = currentWidth / maxDimensionAngle;
          processingImage = img.copyResize(image, width: maxDimensionAngle);
        } else {
          scale = currentHeight / maxDimensionAngle;
          processingImage = img.copyResize(image, height: maxDimensionAngle);
        }
      }

      final width = processingImage.width;
      final height = processingImage.height;

      // 1. Grayscale
      final grayImage = img.grayscale(processingImage.clone());

      // 2. Hitung Otsu Threshold
      int threshold = _hitungOtsuThreshold(grayImage);

      // 3. Grid-based Density Filtering untuk mengurangi noise/latar belakang pengganggu
      const int gridRows = 20;
      const int gridCols = 20;
      final cellWidth = width / gridCols;
      final cellHeight = height / gridRows;
      final cellArea = cellWidth * cellHeight;

      // Hitung kerapatan piksel terang (putih) di tiap sel
      final densities = List.generate(gridRows, (_) => List.filled(gridCols, 0));
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = grayImage.getPixel(x, y);
          if (pixel.r >= threshold) {
            int cellX = (x / cellWidth).floor().clamp(0, gridCols - 1);
            int cellY = (y / cellHeight).floor().clamp(0, gridRows - 1);
            densities[cellY][cellX]++;
          }
        }
      }

      // Sel dianggap valid/dense jika diisi minimal 20% piksel kertas putih
      final isDense = List.generate(gridRows, (_) => List.filled(gridCols, false));
      for (int r = 0; r < gridRows; r++) {
        for (int c = 0; c < gridCols; c++) {
          if (densities[r][c] > (cellArea * 0.20)) {
            isDense[r][c] = true;
          }
        }
      }

      // Cari komponen terhubung terbesar (Largest Connected Component)
      final visited = List.generate(gridRows, (_) => List.filled(gridCols, false));
      List<List<int>> largestComponent = [];

      for (int r = 0; r < gridRows; r++) {
        for (int c = 0; c < gridCols; c++) {
          if (isDense[r][c] && !visited[r][c]) {
            // BFS untuk mencari komponen
            final List<List<int>> component = [];
            final List<List<int>> queue = [[r, c]];
            visited[r][c] = true;

            while (queue.isNotEmpty) {
              final curr = queue.removeAt(0);
              component.add(curr);
              final currR = curr[0];
              final currC = curr[1];

              // Cek 4 tetangga
              final directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
              for (final dir in directions) {
                final newR = currR + dir[0];
                final newC = currC + dir[1];
                if (newR >= 0 && newR < gridRows && newC >= 0 && newC < gridCols) {
                  if (isDense[newR][newC] && !visited[newR][newC]) {
                    visited[newR][newC] = true;
                    queue.add([newR, newC]);
                  }
                }
              }
            }

            if (component.length > largestComponent.length) {
              largestComponent = component;
            }
          }
        }
      }

      // Kumpulkan piksel yang masuk dalam largest component untuk pencarian sudut ekstrem
      final List<img.Point> candidatePoints = [];
      if (largestComponent.isNotEmpty) {
        // Set representasi sel komponen
        final componentSet = <String>{};
        for (final cell in largestComponent) {
          componentSet.add('${cell[0]},${cell[1]}');
        }

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = grayImage.getPixel(x, y);
            if (pixel.r >= threshold) {
              int cellX = (x / cellWidth).floor().clamp(0, gridCols - 1);
              int cellY = (y / cellHeight).floor().clamp(0, gridRows - 1);
              if (componentSet.contains('$cellY,$cellX')) {
                candidatePoints.add(img.Point(x, y));
              }
            }
          }
        }
      }

      // Jika kandidat kosong, gunakan semua piksel di atas threshold
      if (candidatePoints.isEmpty) {
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = grayImage.getPixel(x, y);
            if (pixel.r >= threshold) {
              candidatePoints.add(img.Point(x, y));
            }
          }
        }
      }

      // Jika masih kosong, kembalikan gambar asli
      if (candidatePoints.isEmpty) {
        return null;
      }

      img.Point topLeft = candidatePoints.first;
      img.Point topRight = candidatePoints.first;
      img.Point bottomRight = candidatePoints.first;
      img.Point bottomLeft = candidatePoints.first;

      num minSum = topLeft.x + topLeft.y;
      num maxSum = topLeft.x + topLeft.y;
      num maxDiff = topLeft.x - topLeft.y;
      num minDiff = topLeft.x - topLeft.y;

      for (final p in candidatePoints) {
        final sum = p.x + p.y;
        final diff = p.x - p.y;

        if (sum < minSum) {
          minSum = sum;
          topLeft = p;
        }
        if (sum > maxSum) {
          maxSum = sum;
          bottomRight = p;
        }
        if (diff > maxDiff) {
          maxDiff = diff;
          topRight = p;
        }
        if (diff < minDiff) {
          minDiff = diff;
          bottomLeft = p;
        }
      }

      origTl = img.Point((topLeft.x * scale).round().clamp(0, currentWidth - 1), (topLeft.y * scale).round().clamp(0, currentHeight - 1));
      origTr = img.Point((topRight.x * scale).round().clamp(0, currentWidth - 1), (topRight.y * scale).round().clamp(0, currentHeight - 1));
      origBr = img.Point((bottomRight.x * scale).round().clamp(0, currentWidth - 1), (bottomRight.y * scale).round().clamp(0, currentHeight - 1));
      origBl = img.Point((bottomLeft.x * scale).round().clamp(0, currentWidth - 1), (bottomLeft.y * scale).round().clamp(0, currentHeight - 1));
    }

    // Validasi area sudut (harus membentuk luas daerah minimum)
    final widthTop = origTr.x - origTl.x;
    final widthBottom = origBr.x - origBl.x;
    final heightLeft = origBl.y - origTl.y;
    final heightRight = origBr.y - origTr.y;

    if (widthTop.abs() > 50 && widthBottom.abs() > 50 && heightLeft.abs() > 50 && heightRight.abs() > 50) {
      // Lakukan true warping pelurusan menggunakan copyRectify
      var warped = img.copyRectify(
        image,
        topLeft: origTl,
        topRight: origTr,
        bottomRight: origBr,
        bottomLeft: origBl,
        interpolation: img.Interpolation.linear,
      );
      
      // Jika output warped adalah landscape (lebar > tinggi), rotasikan 90 derajat searah jarum jam agar menjadi portrait upright
      if (warped.width > warped.height) {
        warped = img.copyRotate(warped, angle: 90);
      }
      
      return img.encodeJpg(warped, quality: 90);
    }

    return null;
  }

  static int _hitungOtsuThreshold(img.Image grayImage) {
    final List<int> histogram = List.filled(256, 0);
    final total = grayImage.width * grayImage.height;
    
    for (int y = 0; y < grayImage.height; y++) {
      for (int x = 0; x < grayImage.width; x++) {
        final pixel = grayImage.getPixel(x, y);
        histogram[pixel.r.toInt().clamp(0, 255)]++;
      }
    }

    double sum = 0;
    for (int t = 0; t < 256; t++) {
      sum += t * histogram[t];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double varMax = 0;
    int threshold = 127;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      wF = total - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;

      final varBetween = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);
      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t;
      }
    }
    return threshold;
  }
}