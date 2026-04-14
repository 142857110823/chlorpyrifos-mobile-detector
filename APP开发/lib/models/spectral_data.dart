import 'package:hive/hive.dart';

part 'spectral_data.g.dart';

/// 光谱数据模型
/// 用于存储多光谱检测设备采集的原始数据
@HiveType(typeId: 0)
class SpectralData extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final List<double> wavelengths;

  @HiveField(3)
  final List<double> intensities;

  @HiveField(4)
  final String deviceId;

  @HiveField(5)
  final Map<String, dynamic>? metadata;

  SpectralData({
    required this.id,
    required this.timestamp,
    required this.wavelengths,
    required this.intensities,
    required this.deviceId,
    this.metadata,
  });

  factory SpectralData.fromJson(Map<String, dynamic> json) {
    return SpectralData(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      wavelengths: (json['wavelengths'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      intensities: (json['intensities'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      deviceId: json['deviceId'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'wavelengths': wavelengths,
      'intensities': intensities,
      'deviceId': deviceId,
      'metadata': metadata,
    };
  }

  /// 获取光谱数据点数量
  int get dataPointCount => wavelengths.length;

  /// 获取波长范围
  (double, double) get wavelengthRange {
    if (wavelengths.isEmpty) return (0, 0);
    return (wavelengths.first, wavelengths.last);
  }

  /// 获取最大强度值
  double get maxIntensity {
    if (intensities.isEmpty) return 0;
    return intensities.reduce((a, b) => a > b ? a : b);
  }

  /// 获取最小强度值
  double get minIntensity {
    if (intensities.isEmpty) return 0;
    return intensities.reduce((a, b) => a < b ? a : b);
  }

  /// 归一化强度数据
  List<double> get normalizedIntensities {
    final max = maxIntensity;
    final min = minIntensity;
    if (max == min) return List.filled(intensities.length, 0);
    return intensities.map((i) => (i - min) / (max - min)).toList();
  }

  /// 强度值列表（与intensities相同，用于兼容）
  List<double> get intensityValues => intensities;

  @override
  String toString() {
    return 'SpectralData(id: $id, timestamp: $timestamp, points: $dataPointCount)';
  }
}
