import 'spectrum_peak.dart';

/// 光谱特征集实体
class SpectrumFeatureSet {
  /// 主峰列表
  final List<SpectrumPeak> mainPeaks;
  
  /// 次峰列表
  final List<SpectrumPeak> secondaryPeaks;
  
  /// 谷值列表
  final List<SpectrumPeak> valleys;
  
  /// 波段能量
  final Map<String, double> bandEnergies;
  
  /// 形状描述符
  final Map<String, double> shapeDescriptors;

  SpectrumFeatureSet({
    required this.mainPeaks,
    required this.secondaryPeaks,
    required this.valleys,
    required this.bandEnergies,
    required this.shapeDescriptors,
  });

  @override
  String toString() => 'SpectrumFeatureSet(mainPeaks: ${mainPeaks.length}, secondaryPeaks: ${secondaryPeaks.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpectrumFeatureSet;
  }

  @override
  int get hashCode => mainPeaks.length.hashCode ^ secondaryPeaks.length.hashCode;

  SpectrumFeatureSet copyWith({
    List<SpectrumPeak>? mainPeaks,
    List<SpectrumPeak>? secondaryPeaks,
    List<SpectrumPeak>? valleys,
    Map<String, double>? bandEnergies,
    Map<String, double>? shapeDescriptors,
  }) {
    return SpectrumFeatureSet(
      mainPeaks: mainPeaks ?? this.mainPeaks,
      secondaryPeaks: secondaryPeaks ?? this.secondaryPeaks,
      valleys: valleys ?? this.valleys,
      bandEnergies: bandEnergies ?? this.bandEnergies,
      shapeDescriptors: shapeDescriptors ?? this.shapeDescriptors,
    );
  }
}
