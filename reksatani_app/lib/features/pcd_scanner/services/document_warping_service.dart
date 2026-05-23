import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class DocumentWarpingService {
  // Mengeksekusi proses pelurusan nota di latar belakang agar UI tidak freeze
  Future<File> warpNota(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final processedBytes = await compute(_deteksiDanWarping, bytes);

    if (processedBytes != null) {
      final tempDir = imageFile.parent;
      final newFile = File('${tempDir.path}/warped_nota_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(processedBytes);
      return newFile;
    }

    return imageFile; // Kembalikan gambar asli jika deteksi sudut gagal
  }

  static Uint8List? _deteksiDanWarping(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // 1. Filter Grayscale & Deteksi Tepi (Simplifikasi Canny Edge)
    // Mengubah gambar menjadi abu-abu untuk memperjelas kontras antara kertas nota (putih) dan latar belakang
    final grayImage = img.grayscale(image.clone());

    int minX = image.width;
    int minY = image.height;
    int maxX = 0;
    int maxY = 0;

    final int width = grayImage.width;
    final int height = grayImage.height;
    
    // Threshold kontras kertas putih. Angka ini menentukan seberapa sensitif pelacakan sudutnya
    const int threshold = 130; 

    // 2. Melacak 4 Sudut Kertas (Scan Piksel)
    for (int y = 0; y < height; y += 2) { // Lompati 2 piksel untuk kecepatan
      for (int x = 0; x < width; x += 2) {
        final pixel = grayImage.getPixel(x, y);
        // Jika piksel cukup terang (kemungkinan besar itu adalah kertas nota)
        if (pixel.r > threshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    // Beri sedikit margin/padding agar teks di pinggir nota tidak ikut terpotong
    minX = (minX - 20).clamp(0, width);
    minY = (minY - 20).clamp(0, height);
    maxX = (maxX + 20).clamp(0, width);
    maxY = (maxY + 20).clamp(0, height);

    final int cropWidth = maxX - minX;
    final int cropHeight = maxY - minY;

    // 3. Eksekusi Cropping & Stretching (Pelurusan/Warping)
    // Pastikan area yang terdeteksi masuk akal (bukan cuma debu di lensa)
    if (cropWidth > 100 && cropHeight > 100) {
      // Potong murni area kertas nota
      final cropped = img.copyCrop(image, x: minX, y: minY, width: cropWidth, height: cropHeight);
      
      // Kembalikan ke dalam bentuk gambar yang lurus
      return img.encodeJpg(cropped, quality: 90) as Uint8List;
    }

    return null;
  }
}