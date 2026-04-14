import 'spectrum_point.dart';
import 'spectrum_feature_set.dart';

/// 标准农药光谱实体
class ReferencePesticideSpectrum {
  /// 农药ID
  final String pesticideId;
  
  /// 农药名称
  final String pesticideName;
  
  /// 版本号
  final String version;
  
  /// 归一化光谱
  final List<SpectrumPoint> normalizedSpectrum;
  
  /// 导数光谱
  final List<SpectrumPoint> derivativeSpectrum;
  
  /// 特征集
  final SpectrumFeatureSet featureSet;
  
  /// 阈值参数
  final Map<String, double> thresholds;

  ReferencePesticideSpectrum({
    required this.pesticideId,
    required this.pesticideName,
    required this.version,
    required this.normalizedSpectrum,
    required this.derivativeSpectrum,
    required this.featureSet,
    required this.thresholds,
  });

  @override
  String toString() => 'ReferencePesticideSpectrum(pesticideId: $pesticideId, pesticideName: $pesticideName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReferencePesticideSpectrum &&
        other.pesticideId == pesticideId &&
        other.version == version;
  }

  @override
  int get hashCode => pesticideId.hashCode ^ version.hashCode;

  ReferencePesticideSpectrum copyWith({
    String? pesticideId,
    String? pesticideName,
    String? version,
    List<SpectrumPoint>? normalizedSpectrum,
    List<SpectrumPoint>? derivativeSpectrum,
    SpectrumFeatureSet? featureSet,
    Map<String, double>? thresholds,
  }) {
    return ReferencePesticideSpectrum(
      pesticideId: pesticideId ?? this.pesticideId,
      pesticideName: pesticideName ?? this.pesticideName,
      version: version ?? this.version,
      normalizedSpectrum: normalizedSpectrum ?? this.normalizedSpectrum,
      derivativeSpectrum: derivativeSpectrum ?? this.derivativeSpectrum,
      featureSet: featureSet ?? this.featureSet,
      thresholds: thresholds ?? this.thresholds,
    );
  }
}
