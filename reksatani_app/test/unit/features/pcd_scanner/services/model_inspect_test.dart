import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect TFLite model details', () async {
    try {
      final interpreter = await Interpreter.fromAsset('assets/models/grading_model.tflite');
      print('=== MODEL INPUTS ===');
      for (final tensor in interpreter.getInputTensors()) {
        print('Name: ${tensor.name}');
        print('Shape: ${tensor.shape}');
        print('Type: ${tensor.type}');
      }
      print('=== MODEL OUTPUTS ===');
      for (final tensor in interpreter.getOutputTensors()) {
        print('Name: ${tensor.name}');
        print('Shape: ${tensor.shape}');
        print('Type: ${tensor.type}');
      }
      interpreter.close();
    } catch (e) {
      print('Failed to load/inspect model: $e');
    }
  });
}
