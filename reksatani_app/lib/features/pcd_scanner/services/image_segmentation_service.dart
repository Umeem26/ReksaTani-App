import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageSegmentationService {
  Future<File> segmenLatarKomoditas(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final processedBytes = await compute(_prosesSegmentasiUniversal, bytes);

    if (processedBytes != null) {
      final tempDir = imageFile.parent;
      final newFile = File('${tempDir.path}/segmented_barang_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(processedBytes);
      return newFile;
    }

    return imageFile;
  }

  static Uint8List? _prosesSegmentasiUniversal(Uint8List bytes) {
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    // Downscale untuk mempercepat pemrosesan piksel
    const maxDimension = 600;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: maxDimension);
      } else {
        image = img.copyResize(image, height: maxDimension);
      }
    }

    final int width = image.width;
    final int height = image.height;
    final resultImage = image.clone();

    // 1. HITUNG RATA-RATA WARNA DI BORDER (ADAPTIVE BACKGROUND COLOR SENSING)
    int borderR = 0;
    int borderG = 0;
    int borderB = 0;
    int borderCount = 0;

    // Sample top and bottom borders
    for (int x = 0; x < width; x += 8) {
      final pTop = image.getPixel(x, 0);
      borderR += pTop.r.toInt();
      borderG += pTop.g.toInt();
      borderB += pTop.b.toInt();
      borderCount++;

      final pBottom = image.getPixel(x, height - 1);
      borderR += pBottom.r.toInt();
      borderG += pBottom.g.toInt();
      borderB += pBottom.b.toInt();
      borderCount++;
    }

    // Sample left and right borders
    for (int y = 8; y < height - 8; y += 8) {
      final pLeft = image.getPixel(0, y);
      borderR += pLeft.r.toInt();
      borderG += pLeft.g.toInt();
      borderB += pLeft.b.toInt();
      borderCount++;

      final pRight = image.getPixel(width - 1, y);
      borderR += pRight.r.toInt();
      borderG += pRight.g.toInt();
      borderB += pRight.b.toInt();
      borderCount++;
    }

    final double avgR = borderR / borderCount;
    final double avgG = borderG / borderCount;
    final double avgB = borderB / borderCount;
    final double avgLuma = 0.299 * avgR + 0.587 * avgG + 0.114 * avgB;

    // 2. ITERASI UNTUK MEMISAHKAN FOREGROUND DAN BACKGROUND
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        
        // Hitung nilai kecerahan piksel saat ini
        double pixelLuminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;

        // Hitung juga tingkat kejenuhan warna (Saturation)
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        double max = r > g ? (r > b ? r : b) : (g > b ? g : b);
        double min = r < g ? (r < b ? r : b) : (g < b ? g : b);
        double delta = max - min;
        double saturation = max == 0 ? 0 : delta / max;

        // Hitung jarak Euclidean ke warna border rata-rata
        double rDiff = pixel.r - avgR;
        double gDiff = pixel.g - avgG;
        double bDiff = pixel.b - avgB;
        double distance = math.sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);

        bool isBackground = false;
        
        // Piksel dianggap background jika warnanya sangat dekat dengan warna border rata-rata
        if (distance < 55.0) {
          isBackground = true;
        } else if (saturation < 0.08) {
          // Piksel netral (low saturation seperti putih/abu-abu/hitam)
          if (avgLuma > 130 && pixelLuminance > 140) {
            // Latar belakang terang, piksel netral terang dianggap background
            isBackground = true;
          } else if (avgLuma <= 130 && pixelLuminance < 90) {
            // Latar belakang gelap, piksel netral gelap dianggap background
            isBackground = true;
          }
        }

        if (isBackground) {
          // Ubah latar belakang menjadi warna PUTIH BERSIH
          resultImage.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }

    return img.encodeJpg(resultImage, quality: 85) as Uint8List;
  }
}