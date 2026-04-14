/// TFLite Flutter implementation with platform-specific imports
/// On native platforms, uses the real tflite_flutter library
/// On web platform, uses the stub implementation

import 'package:flutter/foundation.dart' show kIsWeb;

export 'tflite_stub.dart' if (dart.library.io) 'tflite_native.dart';
