import 'spectrum_point.dart';

/// 预处理后的光谱数据实体
class ProcessedSpectrum {
  /// 原始光谱点
  final List<SpectrumPoint> rawPoints;
  
  /// 重采样后的光谱点
  final List<SpectrumPoint> resampledPoints;
  
  /// 平滑后的光谱点
  final List<SpectrumPoint> smoothedPoints;
  
  /// 基线校正后的光谱点
  final List<SpectrumPoint> baselineCorrectedPoints;
  
  /// 归一化后的光谱点
  final List<SpectrumPoint> normalizedPoints;
  
  /// 一阶导数谱
  final List<SpectrumPoint> firstDerivative;
  
  /// 二阶导数谱
  final List<SpectrumPoint> secondDerivative;
  
  /// 预处理日志
  final List<String> preprocessLogs;

  ProcessedSpectrum({
    required this.rawPoints,
    required this.resampledPoints,
    required this.smoothedPoints,
    required this.baselineCorrectedPoints,
    required this.normalizedPoints,
    required this.firstDerivative,
    required this.secondDerivative,
    required this.preprocessLogs,
  });

  @override
  String toString() => 'ProcessedSpectrum(rawPoints: ${rawPoints.length}, resampledPoints: ${resampledPoints.length}, normalizedPoints: ${normalizedPoints.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcessedSpectrum;
  }

  @override
  int get hashCode => rawPoints.length.hashCode ^ resampledPoints.length.hashCode ^ normalizedPoints.length.hashCode;

  ProcessedSpectrum copyWith({
    List<SpectrumPoint>? rawPoints,
    List<SpectrumPoint>? resampledPoints,
    List<SpectrumPoint>? smoothedPoints,
    List<SpectrumPoint>? baselineCorrectedPoints,
    List<SpectrumPoint>? normalizedPoints,
    List<SpectrumPoint>? firstDerivative,
    List<SpectrumPoint>? secondDerivative,
    List<String>? preprocessLogs,
  }) {
    return ProcessedSpectrum(
      rawPoints: rawPoints ?? this.rawPoints,
      resampledPoints: resampledPoints ?? this.resampledPoints,
      smoothedPoints: smoothedPoints ?? this.smoothedPoints,
      baselineCorrectedPoints: baselineCorrectedPoints ?? this.baselineCorrectedPoints,
      normalizedPoints: normalizedPoints ?? this.normalizedPoints,
      firstDerivative: firstDerivative ?? this.firstDerivative,
      secondDerivative: secondDerivative ?? this.secondDerivative,
      preprocessLogs: preprocessLogs ?? this.preprocessLogs,
    );
  }
}
