import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 100, height: 50);
  final rotated = img.copyRotate(image, angle: 90);
  print("Rotated size: ${rotated.width}x${rotated.height}");
}
