import 'dart:io';
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
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final int width = image.width;
    final int height = image.height;
    final resultImage = image.clone();

    // 1. HITUNG RATA-RATA LUMINANCE UNTUK MENENTUKAN AMBANG BATAS (OTSU SIMPLIFIED)
    int totalLuminance = 0;
    for (int y = 0; y < height; y += 4) { // Sampling cepat
      for (int x = 0; x < width; x += 4) {
        final pixel = image.getPixel(x, y);
        totalLuminance += (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
      }
    }
    int dynamicThreshold = totalLuminance ~/ ((width / 4) * (height / 4));

    // Beri batas toleransi bawah dan atas agar tidak terlalu ekstrem
    dynamicThreshold = dynamicThreshold.clamp(70, 160);

    // 2. ITERASI UNTUK MEMISAHKAN FOREGROUND DAN BACKGROUND BERDASARKAN KONTRAS
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        
        // Hitung nilai kecerahan piksel saat ini
        double pixelLuminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;

        // Hitung juga tingkat kejenuhan warna (Saturation) untuk membedakan tanah/semen abu-abu
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        double max = r > g ? (r > b ? r : b) : (g > b ? g : b);
        double min = r < g ? (r < b ? r : b) : (g < b ? g : b);
        double delta = max - min;
        double saturation = max == 0 ? 0 : delta / max;

        // Logika Pintar: Jika warnanya sangat pucat/abu-abu (seperti semen/tanah kering) 
        // ATAU tingkat kecerahannya terlalu jauh dari objek komoditas utama, maka itu adalah latar belakang
        bool isBackground = (saturation < 0.08) || (pixelLuminance < (dynamicThreshold - 25));

        if (isBackground) {
          // Ubah latar belakang menjadi warna PUTIH BERSIH, apapun warna komoditas di depannya
          resultImage.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }

    return img.encodeJpg(resultImage, quality: 85) as Uint8List;
  }
}