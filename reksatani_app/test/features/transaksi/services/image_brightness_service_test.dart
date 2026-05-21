import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reksatani_app/features/transaksi/services/image_brightness_service.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  late ImageBrightnessService service;
  late Directory tempDir;

  setUp(() async {
    service = ImageBrightnessService();
    tempDir = await Directory.systemTemp.createTemp('image_brightness_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File createTestImage(String name, int colorValue) {
    // Create a 100x100 solid color image
    final image = img.Image(width: 100, height: 100);
    // Fill image with specific rgb value (grayscale)
    img.fill(image, color: img.ColorRgb8(colorValue, colorValue, colorValue));
    
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(img.encodeJpg(image));
    return file;
  }

  test('Test dark image adjustment', () async {
    // luminance threshold is 80, create image with value 50 (dark)
    final darkFile = createTestImage('dark.jpg', 50);
    
    final stopwatch = Stopwatch()..start();
    final result = await service.adjustBrightness(darkFile);
    stopwatch.stop();
    
    expect(result.path, isNot(equals(darkFile.path)), reason: 'A new file should be generated for adjusted image');
    
    // Check if it's brighter
    final resultImage = img.decodeImage(result.readAsBytesSync())!;
    final pixel = resultImage.getPixel(50, 50);
    expect(pixel.r, greaterThan(50), reason: 'Image should be brighter');
    
    expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Processing time should be less than 500ms');
  });

  test('Test bright image adjustment', () async {
    // luminance threshold is 200, create image with value 220 (bright)
    final brightFile = createTestImage('bright.jpg', 220);
    
    final stopwatch = Stopwatch()..start();
    final result = await service.adjustBrightness(brightFile);
    stopwatch.stop();
    
    expect(result.path, isNot(equals(brightFile.path)), reason: 'A new file should be generated for adjusted image');
    
    // Check if it's darker
    final resultImage = img.decodeImage(result.readAsBytesSync())!;
    final pixel = resultImage.getPixel(50, 50);
    expect(pixel.r, lessThan(220), reason: 'Image should be darker');
    
    expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Processing time should be less than 500ms');
  });

  test('Test normal image no change', () async {
    // luminance is between 80 and 200
    final normalFile = createTestImage('normal.jpg', 150);
    
    final stopwatch = Stopwatch()..start();
    final result = await service.adjustBrightness(normalFile);
    stopwatch.stop();
    
    expect(result.path, equals(normalFile.path), reason: 'Normal image should not be adjusted');
    expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Processing time should be less than 500ms');
  });
}
