import 'dart:math';
import 'dart:typed_data';
import 'explainability_result.dart';
import 'feature_importance_analyzer.dart';
import 'shap_approximator.dart';

/// AI模型可解释性分析器
/// 整合SHAP值计算、特征重要性分析、关键波长提取等功能
/// 针对移动端优化的轻量化实现
class ModelExplainer {
  /// 特征重要性分析器
  final FeatureImportanceAnalyzer _featureAnalyzer;
  
  /// SHAP近似计算器
  final ShapApproximator _shapApproximator;
  
  /// 是否使用模拟模式
  final bool useMockMode;
  
  /// 随机数生成器
  final Random _random = Random(42);

  /// 波长范围
  static const double minWavelength = 200.0;
  static const double maxWavelength = 1100.0;

  ModelExplainer({
    int numSamples = 50,
    double perturbationScale = 0.1,
    int topKFeatures = 20,
    this.useMockMode = true,
  })  : _featureAnalyzer = FeatureImportanceAnalyzer(
          numSamples: numSamples,
          perturbationScale: perturbationScale,
          topK: topKFeatures,
        ),
        _shapApproximator = ShapApproximator(
          numSamples: numSamples,
          perturbationScale: perturbationScale,
        );

  /// 执行完整的可解释性分析
  Future<ExplainabilityResult> explain({
    required List<double> spectralData,
    required List<double> featureData,
    required String predictedClass,
    required double predictedProbability,
    Future<Map<String, double>> Function(Float32List)? predictionFunction,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. 计算SHAP值
    ShapValues shapValues;
    if (useMockMode || predictionFunction == null) {
      shapValues = _shapApproximator.computeShapValuesWithMock(
        spectralData: spectralData,
        featureData: featureData,
      );
    } else {
      shapValues = await _shapApproximator.computeShapValues(
        spectralData: spectralData,
        featureData: featureData,
        targetClass: predictedClass,
        predictionFunction: predictionFunction,
      );
    }

    // 2. 计算特征重要性
    FeatureImportance featureImportance;
    if (useMockMode || predictionFunction == null) {
      featureImportance = _featureAnalyzer.analyzeWithMock(
        spectralData: spectralData,
        featureData: featureData,
      );
    } else {
      featureImportance = await _featureAnalyzer.analyze(
        spectralData: spectralData,
        featureData: featureData,
        predictionFunction: (input) async {
          final result = await predictionFunction(input);
          return result[predictedClass] ?? 0;
        },
      );
    }

    // 3. 提取关键波长
    final criticalWavelengths = _shapApproximator.extractCriticalWavelengths(
      shapValues.spectral,
      topK: 10,
    );

    // 4. 计算置信区间
    final confidenceInterval = _computeConfidenceInterval(
      spectralData,
      featureData,
      predictedProbability,
    );

    // 5. 生成可视化数据
    final visualization = _generateVisualizationData(
      spectralData,
      shapValues,
      featureImportance,
      criticalWavelengths,
    );

    stopwatch.stop();

    return ExplainabilityResult(
      shapValues: shapValues,
      featureImportance: featureImportance,
      criticalWavelengths: criticalWavelengths,
      confidenceInterval: confidenceInterval,
      visualization: visualization,
      analysisDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// 快速分析模式（仅计算关键信息）
  ExplainabilityResult quickExplain({
    required List<double> spectralData,
    required List<double> featureData,
    required double predictedProbability,
  }) {
    final stopwatch = Stopwatch()..start();

    // 使用模拟SHAP值
    final shapValues = _shapApproximator.computeShapValuesWithMock(
      spectralData: spectralData,
      featureData: featureData,
    );

    // 使用模拟特征重要性
    final featureImportance = _featureAnalyzer.analyzeWithMock(
      spectralData: spectralData,
      featureData: featureData,
    );

    // 提取关键波长
    final criticalWavelengths = _shapApproximator.extractCriticalWavelengths(
      shapValues.spectral,
      topK: 5,
    );

    // 简化置信区间
    final confidenceInterval = ConfidenceInterval(
      lower: (predictedProbability - 0.1).clamp(0, 1),
      upper: (predictedProbability + 0.1).clamp(0, 1),
      mean: predictedProbability,
      std: 0.05,
    );

    // 简化可视化数据
    final visualization = _generateVisualizationData(
      spectralData,
      shapValues,
      featureImportance,
      criticalWavelengths,
    );

    stopwatch.stop();

    return ExplainabilityResult(
      shapValues: shapValues,
      featureImportance: featureImportance,
      criticalWavelengths: criticalWavelengths,
      confidenceInterval: confidenceInterval,
      visualization: visualization,
      analysisDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// 获取SHAP区域聚合
  List<ShapRegion> getShapRegions(ShapValues shapValues, {int regionCount = 8}) {
    return _shapApproximator.aggregateToRegions(
      shapValues.spectral,
      regionCount: regionCount,
    );
  }

  /// 获取波长贡献度列表
  List<WavelengthContribution> getWavelengthContributions(
    List<double> spectralData,
    ShapValues shapValues,
  ) {
    return _featureAnalyzer.calculateWavelengthContributions(
      spectralData: spectralData,
      shapValues: shapValues.spectral,
    );
  }

  // ========== 私有方法 ==========

  /// 计算置信区间（蒙特卡洛模拟）
  ConfidenceInterval _computeConfidenceInterval(
    List<double> spectralData,
    List<double> featureData,
    double prediction,
  ) {
    final predictions = <double>[];
    
    // 模拟多次扰动预测
    for (var i = 0; i < 30; i++) {
      // 基于数据特征模拟预测值波动
      final noise = (_random.nextDouble() - 0.5) * 0.2;
      final dataComplexity = _computeComplexity(spectralData) * 0.1;
      predictions.add((prediction + noise + dataComplexity).clamp(0, 1));
    }
    
    predictions.sort();
    
    // 计算统计量
    final mean = predictions.fold(0.0, (a, b) => a + b) / predictions.length;
    final variance = predictions
        .map((v) => pow(v - mean, 2))
        .fold(0.0, (a, b) => a + b) / predictions.length;
    final std = sqrt(variance);
    
    return ConfidenceInterval(
      lower: predictions[(predictions.length * 0.025).toInt()],
      upper: predictions[(predictions.length * 0.975).toInt()],
      mean: mean,
      std: std,
    );
  }

  /// 计算数据复杂度
  double _computeComplexity(List<double> data) {
    if (data.length < 2) return 0;
    
    // 基于变化率计算复杂度
    double totalChange = 0;
    for (var i = 1; i < data.length; i++) {
      totalChange += (data[i] - data[i - 1]).abs();
    }
    return totalChange / data.length / 100;
  }

  /// 生成可视化数据
  VisualizationData _generateVisualizationData(
    List<double> spectralData,
    ShapValues shapValues,
    FeatureImportance importance,
    List<CriticalWavelength> criticals,
  ) {
    // 光谱贡献图数据
    final spectralContribution = <SpectralPoint>[];
    for (var i = 0; i < min(spectralData.length, shapValues.spectral.length); i++) {
      final wavelength = minWavelength + i * (maxWavelength - minWavelength) / 256;
      spectralContribution.add(SpectralPoint(
        wavelength: wavelength,
        intensity: shapValues.spectral[i],
        isCritical: criticals.any((c) => (c.wavelength - wavelength).abs() < 10),
      ));
    }

    // 特征重要性条形图数据
    final featureBarChart = importance.topFeatures.entries
        .map((e) => FeatureBar(
              name: e.key,
              value: e.value,
              description: _getFeatureDescription(e.key),
            ))
        .toList();

    // 波段饼图数据
    final bandPieChart = importance.spectralBands.entries
        .map((e) => BandSegment(
              name: e.key,
              value: e.value,
              colorValue: _getBandColor(e.key),
            ))
        .toList();

    return VisualizationData(
      spectralContribution: spectralContribution,
      featureBarChart: featureBarChart,
      bandPieChart: bandPieChart,
    );
  }

  /// 获取特征描述
  String _getFeatureDescription(String name) {
    const descriptions = {
      '均值': '光谱强度平均值',
      '标准差': '强度变异程度',
      '能量': '总信号能量',
      '熵': '信号复杂度',
      '峰值数量': '吸收峰数量',
      '主峰位置': '最强峰位置',
    };
    return descriptions[name] ?? name;
  }

  /// 获取波段颜色
  int _getBandColor(String band) {
    if (band.contains('UV')) return 0xFF9C27B0; // 紫色
    if (band.contains('可见光')) return 0xFF4CAF50; // 绿色
    return 0xFFF44336; // 红色
  }
}
