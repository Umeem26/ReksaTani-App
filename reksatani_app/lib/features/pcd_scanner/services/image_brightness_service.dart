import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageBrightnessService {
  static const int darkThreshold = 80;
  static const int brightThreshold = 200;

  Future<File> adjustBrightness(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final processedBytes = await compute(_processImage, bytes);

    if (processedBytes != null) {
      final tempDir = imageFile.parent;
      final newFile = File('${tempDir.path}/adjusted_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(processedBytes);
      return newFile;
    }

    return imageFile;
  }

  static Uint8List? _processImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    int totalLuminance = 0;
    final int width = image.width;
    final int height = image.height;

    // Menghitung luminance menggunakan sample pixel untuk mempercepat performa (terutama foto resolusi besar)
    int sampleStep = 4; // Mengambil sampel setiap 4 pixel
    int sampleCount = 0;

    for (int y = 0; y < height; y += sampleStep) {
      for (int x = 0; x < width; x += sampleStep) {
        final pixel = image.getPixel(x, y);
        // luminance = 0.299*R + 0.587*G + 0.114*B
        num luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        totalLuminance += luminance.toInt();
        sampleCount++;
      }
    }

    int avgLuminance = sampleCount > 0 ? totalLuminance ~/ sampleCount : 0;

    bool needsAdjustment = false;
    img.Image? adjustedImage;

    if (avgLuminance < darkThreshold) {
      // Jika terlalu gelap, naikkan brightness (additive) dan kontras (multiplier)
      // Catatan: Parameter di package image v4 terkadang menggunakan add/mul atau argumen spesifik. 
      // adjustColor biasanya memiliki parameter brightness dan contrast
      adjustedImage = img.adjustColor(image, brightness: 1.5, contrast: 1.2); 
      needsAdjustment = true;
    } else if (avgLuminance > brightThreshold) {
      // Jika terlalu terang
      adjustedImage = img.adjustColor(image, brightness: 0.8, contrast: 1.1); 
      needsAdjustment = true;
    }

    if (needsAdjustment && adjustedImage != null) {
      return img.encodeJpg(adjustedImage, quality: 85) as Uint8List;
    }

    return null;
  }
}
