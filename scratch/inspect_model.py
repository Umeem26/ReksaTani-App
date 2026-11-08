import sys

try:
    import tensorflow as tf
    print("Using TensorFlow")
    interpreter = tf.lite.Interpreter(model_path="assets/models/grading_model.tflite")
    interpreter.allocate_tensors()
    print("Input details:")
    for detail in interpreter.get_input_details():
        print(detail)
    print("Output details:")
    for detail in interpreter.get_output_details():
        print(detail)
except ImportError:
    try:
        import tflite_runtime.interpreter as tflite
        print("Using tflite_runtime")
        interpreter = tflite.Interpreter(model_path="assets/models/grading_model.tflite")
        interpreter.allocate_tensors()
        print("Input details:")
        for detail in interpreter.get_input_details():
            print(detail)
        print("Output details:")
        for detail in interpreter.get_output_details():
            print(detail)
    except ImportError:
        print("Neither tensorflow nor tflite_runtime is installed.")
