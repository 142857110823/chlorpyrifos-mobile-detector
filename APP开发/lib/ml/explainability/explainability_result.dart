/// 可解释性分析结果数据结构
/// 包含SHAP值、特征重要性、关键波长等分析结果

/// SHAP值结果
class ShapValues {
  /// 256维光谱SHAP值
  final List<double> spectral;
  
  /// 64维统计特征SHAP值
  final Map<String, double> features;
  
  /// 基准预测值
  final double baseline;

  ShapValues({
    required this.spectral,
    required this.features,
    required this.baseline,
  });

  /// 获取光谱SHAP的最大绝对值
  double get maxSpectralAbsValue {
    if (spectral.isEmpty) return 0;
    return spectral.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
  }

  /// 获取特征SHAP的最大绝对值
  double get maxFeatureAbsValue {
    if (features.isEmpty) return 0;
    return features.values.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
  }

  /// 获取正贡献波长索引
  List<int> get positiveContributionIndices {
    return List.generate(spectral.length, (i) => i)
        .where((i) => spectral[i] > 0)
        .toList();
  }

  /// 获取负贡献波长索引
  List<int> get negativeContributionIndices {
    return List.generate(spectral.length, (i) => i)
        .where((i) => spectral[i] < 0)
        .toList();
  }
}

/// 特征重要性结果
class FeatureImportance {
  /// 光谱波段重要性
  final Map<String, double> spectralBands;
  
  /// Top-K统计特征
  final Map<String, double> topFeatures;
  
  /// 全局重要性得分
  final double globalImportanceScore;

  FeatureImportance({
    required this.spectralBands,
    required this.topFeatures,
    required this.globalImportanceScore,
  });

  /// 获取最重要的波段
  String get mostImportantBand {
    if (spectralBands.isEmpty) return '';
    return spectralBands.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// 获取最重要的特征
  String get mostImportantFeature {
    if (topFeatures.isEmpty) return '';
    return topFeatures.entries
        .reduce((a, b) => a.value.abs() > b.value.abs() ? a : b)
        .key;
  }

  /// 获取正贡献特征
  Map<String, double> get positiveFeatures {
    return Map.fromEntries(
      topFeatures.entries.where((e) => e.value > 0),
    );
  }

  /// 获取负贡献特征
  Map<String, double> get negativeFeatures {
    return Map.fromEntries(
      topFeatures.entries.where((e) => e.value < 0),
    );
  }
}

/// 关键波长
class CriticalWavelength {
  /// 波长值 (nm)
  final double wavelength;
  
  /// SHAP贡献值
  final double contribution;
  
  /// 重要性得分
  final double importance;
  
  /// 化学意义解释
  final String reason;
  
  /// 波长在光谱数组中的索引
  final int index;

  CriticalWavelength({
    required this.wavelength,
    required this.contribution,
    required this.importance,
    required this.reason,
    required this.index,
  });

  /// 是否为正贡献
  bool get isPositive => contribution > 0;

  /// 贡献百分比（需要外部提供总贡献）
  double contributionPercentage(double totalContribution) {
    if (totalContribution == 0) return 0;
    return (contribution.abs() / totalContribution) * 100;
  }
}

/// 置信区间
class ConfidenceInterval {
  /// 95% CI下界
  final double lower;
  
  /// 95% CI上界
  final double upper;
  
  /// 均值
  final double mean;
  
  /// 标准差
  final double std;

  ConfidenceInterval({
    required this.lower,
    required this.upper,
    required this.mean,
    required this.std,
  });

  /// 区间宽度
  double get width => upper - lower;

  /// 是否高置信度（区间宽度小于0.2）
  bool get isHighConfidence => width < 0.2;

  /// 置信度等级描述
  String get confidenceLevel {
    if (width < 0.1) return '非常高';
    if (width < 0.2) return '高';
    if (width < 0.3) return '中等';
    return '低';
  }
}

/// 可视化数据
class VisualizationData {
  /// 光谱贡献图数据点
  final List<SpectralPoint> spectralContribution;
  
  /// 特征重要性条形图数据
  final List<FeatureBar> featureBarChart;
  
  /// 波段饼图数据
  final List<BandSegment> bandPieChart;

  VisualizationData({
    required this.spectralContribution,
    required this.featureBarChart,
    required this.bandPieChart,
  });
}

/// 光谱数据点
class SpectralPoint {
  /// 波长 (nm)
  final double wavelength;
  
  /// SHAP强度
  final double intensity;
  
  /// 是否为关键波长
  final bool isCritical;

  SpectralPoint({
    required this.wavelength,
    required this.intensity,
    required this.isCritical,
  });
}

/// 特征条形图数据
class FeatureBar {
  /// 特征名称
  final String name;
  
  /// 贡献值
  final double value;
  
  /// 中文描述
  final String? description;

  FeatureBar({
    required this.name,
    required this.value,
    this.description,
  });

  /// 是否为正贡献
  bool get isPositive => value > 0;
}

/// 波段饼图段
class BandSegment {
  /// 波段名称
  final String name;
  
  /// 重要性值
  final double value;
  
  /// 颜色代码（可选）
  final int? colorValue;

  BandSegment({
    required this.name,
    required this.value,
    this.colorValue,
  });

  /// 百分比（需要外部提供总值）
  double percentage(double total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }
}

/// 完整可解释性结果
class ExplainabilityResult {
  /// SHAP值
  final ShapValues shapValues;
  
  /// 特征重要性
  final FeatureImportance featureImportance;
  
  /// 关键波长列表
  final List<CriticalWavelength> criticalWavelengths;
  
  /// 置信区间
  final ConfidenceInterval confidenceInterval;
  
  /// 可视化数据
  final VisualizationData visualization;
  
  /// 分析时间戳
  final DateTime timestamp;
  
  /// 分析耗时（毫秒）
  final int analysisDurationMs;

  ExplainabilityResult({
    required this.shapValues,
    required this.featureImportance,
    required this.criticalWavelengths,
    required this.confidenceInterval,
    required this.visualization,
    DateTime? timestamp,
    this.analysisDurationMs = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 获取Top-N关键波长
  List<CriticalWavelength> getTopCriticalWavelengths(int n) {
    final sorted = List<CriticalWavelength>.from(criticalWavelengths)
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return sorted.take(n).toList();
  }

  /// 获取正贡献关键波长
  List<CriticalWavelength> get positiveCriticalWavelengths {
    return criticalWavelengths.where((cw) => cw.isPositive).toList();
  }

  /// 获取负贡献关键波长
  List<CriticalWavelength> get negativeCriticalWavelengths {
    return criticalWavelengths.where((cw) => !cw.isPositive).toList();
  }

  /// 生成文字摘要
  String generateSummary() {
    final buffer = StringBuffer();
    
    // 置信度
    buffer.writeln('预测置信度：${confidenceInterval.confidenceLevel}');
    buffer.writeln('置信区间：[${confidenceInterval.lower.toStringAsFixed(3)}, ${confidenceInterval.upper.toStringAsFixed(3)}]');
    buffer.writeln();
    
    // 最重要波段
    buffer.writeln('最重要光谱区域：${featureImportance.mostImportantBand}');
    buffer.writeln();
    
    // 关键波长
    buffer.writeln('关键波长：');
    for (final cw in getTopCriticalWavelengths(5)) {
      final sign = cw.isPositive ? '+' : '-';
      buffer.writeln('  $sign ${cw.wavelength.toStringAsFixed(1)}nm: ${cw.reason}');
    }
    buffer.writeln();
    
    // 重要特征
    buffer.writeln('重要统计特征：');
    final topFeatures = featureImportance.topFeatures.entries.take(5);
    for (final entry in topFeatures) {
      final sign = entry.value > 0 ? '+' : '-';
      buffer.writeln('  $sign ${entry.key}: ${entry.value.toStringAsFixed(4)}');
    }
    
    return buffer.toString();
  }

  /// 转换为Map（用于JSON序列化）
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'analysisDurationMs': analysisDurationMs,
      'confidenceInterval': {
        'lower': confidenceInterval.lower,
        'upper': confidenceInterval.upper,
        'mean': confidenceInterval.mean,
        'std': confidenceInterval.std,
      },
      'criticalWavelengths': criticalWavelengths.map((cw) => {
        'wavelength': cw.wavelength,
        'contribution': cw.contribution,
        'importance': cw.importance,
        'reason': cw.reason,
      }).toList(),
      'featureImportance': {
        'spectralBands': featureImportance.spectralBands,
        'topFeatures': featureImportance.topFeatures,
        'globalScore': featureImportance.globalImportanceScore,
      },
    };
  }
}
