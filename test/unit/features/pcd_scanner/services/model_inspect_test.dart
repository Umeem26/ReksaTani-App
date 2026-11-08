import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect TFLite model details', () async {
    try {
      final interpreter = await Interpreter.fromAsset('assets/models/grading_model.tflite');
      debugPrint('=== MODEL INPUTS ===');
      for (final tensor in interpreter.getInputTensors()) {
        debugPrint('Name: ${tensor.name}');
        debugPrint('Shape: ${tensor.shape}');
        debugPrint('Type: ${tensor.type}');
      }
      debugPrint('=== MODEL OUTPUTS ===');
      for (final tensor in interpreter.getOutputTensors()) {
        debugPrint('Name: ${tensor.name}');
        debugPrint('Shape: ${tensor.shape}');
        debugPrint('Type: ${tensor.type}');
      }
      interpreter.close();
    } catch (e) {
      debugPrint('Failed to load/inspect model: $e');
    }
  });
}
