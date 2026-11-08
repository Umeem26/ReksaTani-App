import 'package:image/image.dart' as img;

void main() {
  try {
    final pt = img.Point(10, 20);
    print("Point created successfully: x=${pt.x}, y=${pt.y}");
  } catch (e) {
    print("Error: $e");
  }
}
