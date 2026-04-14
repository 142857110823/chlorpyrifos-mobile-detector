/// TFLite Flutter stub for web platform compatibility
/// On native platforms, replace this with: import 'package:tflite_flutter/tflite_flutter.dart';
/// This stub allows the app to compile on web while gracefully degrading
/// to rule-based analysis when TFLite models are not available.

class InterpreterOptions {
  int threads = 1;
  bool useNNAPI = false;
  bool useGpuDelegate = false;
}

class Interpreter {
  List<int> get inputTensorCount => [];
  List<int> get outputTensorCount => [];

  Interpreter.fromBuffer(List<int> buffer, {InterpreterOptions? options}) {
    // Web平台不支持TFLite，静默处理
  }

  Interpreter.fromFile(String path, {InterpreterOptions? options}) {
    // Web平台不支持TFLite，静默处理
  }

  void run(Object input, Object output) {
    // Web平台不支持TFLite，静默处理
  }

  void runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs) {
    // Web平台不支持TFLite，静默处理
  }

  void allocateTensors() {}

  void close() {}
}
