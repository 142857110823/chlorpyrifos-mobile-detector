import 'spectrum_point.dart';

/// 原始光谱数据实体
class SpectrumData {
  /// 源图像路径
  final String sourceImagePath;
  
  /// 光谱点列表
  final List<SpectrumPoint> points;
  
  /// 波长起始值 (nm)
  final double wavelengthStart;
  
  /// 波长结束值 (nm)
  final double wavelengthEnd;
  
  /// 波长间隔 (nm)
  final double interval;
  
  /// 数据源类型
  final String sourceType;
  
  /// 质量评分
  final double qualityScore;

  SpectrumData({
    required this.sourceImagePath,
    required this.points,
    required this.wavelengthStart,
    required this.wavelengthEnd,
    required this.interval,
    required this.sourceType,
    required this.qualityScore,
  });

  @override
  String toString() => 'SpectrumData(sourceImagePath: $sourceImagePath, points: ${points.length} points, wavelengthStart: $wavelengthStart, wavelengthEnd: $wavelengthEnd, qualityScore: $qualityScore)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpectrumData &&
        other.sourceImagePath == sourceImagePath &&
        other.wavelengthStart == wavelengthStart &&
        other.wavelengthEnd == wavelengthEnd &&
        other.interval == interval &&
        other.sourceType == sourceType &&
        other.qualityScore == qualityScore;
  }

  @override
  int get hashCode => sourceImagePath.hashCode ^ wavelengthStart.hashCode ^ wavelengthEnd.hashCode ^ interval.hashCode ^ sourceType.hashCode ^ qualityScore.hashCode;

  SpectrumData copyWith({
    String? sourceImagePath,
    List<SpectrumPoint>? points,
    double? wavelengthStart,
    double? wavelengthEnd,
    double? interval,
    String? sourceType,
    double? qualityScore,
  }) {
    return SpectrumData(
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      points: points ?? this.points,
      wavelengthStart: wavelengthStart ?? this.wavelengthStart,
      wavelengthEnd: wavelengthEnd ?? this.wavelengthEnd,
      interval: interval ?? this.interval,
      sourceType: sourceType ?? this.sourceType,
      qualityScore: qualityScore ?? this.qualityScore,
    );
  }
}
