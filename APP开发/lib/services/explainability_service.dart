import 'dart:math';
import '../models/spectral_data.dart';
import '../models/detection_result.dart';
import '../ml/explainability/explainability.dart';

/// AI可解释性分析服务
/// 提供模型预测的可解释性分析功能
class ExplainabilityService {
  static final ExplainabilityService _instance = ExplainabilityService._internal();
  factory ExplainabilityService() => _instance;
  ExplainabilityService._internal();

  /// 模型解释器
  late final ModelExplainer _explainer;
  
  bool _isInitialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _explainer = ModelExplainer(
      numSamples: 50,
      perturbationScale: 0.1,
      topKFeatures: 20,
      useMockMode: true,
    );
    
    _isInitialized = true;
  }

  /// 执行完整的可解释性分析
  Future<ExplainabilityResult> analyzeExplainability({
    required SpectralData spectralData,
    required DetectionResult result,
  }) async {
    await initialize();
    
    final normalizedSpectral = _normalizeSpectral(spectralData.intensities);
    final features = _extractFeatures(normalizedSpectral);
    
    final predictedClass = result.detectedPesticides.isNotEmpty
        ? result.detectedPesticides.first.name
        : '无农药';
    
    return await _explainer.explain(
      spectralData: normalizedSpectral,
      featureData: features,
      predictedClass: predictedClass,
      predictedProbability: result.confidence,
    );
  }

  /// 快速可解释性分析
  ExplainabilityResult quickAnalyze({
    required SpectralData spectralData,
    required double confidence,
  }) {
    if (!_isInitialized) {
      _explainer = ModelExplainer(useMockMode: true);
      _isInitialized = true;
    }
    
    final normalizedSpectral = _normalizeSpectral(spectralData.intensities);
    final features = _extractFeatures(normalizedSpectral);
    
    return _explainer.quickExplain(
      spectralData: normalizedSpectral,
      featureData: features,
      predictedProbability: confidence,
    );
  }

  /// 获取SHAP区域聚合
  List<ShapRegion> getShapRegions(ExplainabilityResult result) {
    return _explainer.getShapRegions(result.shapValues);
  }

  /// 生成可解释性报告文本
  String generateExplainabilityReport(ExplainabilityResult result) {
    final buffer = StringBuffer();
    
    buffer.writeln('===== AI可解释性分析报告 =====');
    buffer.writeln('');
    buffer.writeln('【预测置信度】');
    buffer.writeln('置信度等级: ${result.confidenceInterval.confidenceLevel}');
    buffer.writeln('95%置信区间: [${(result.confidenceInterval.lower * 100).toStringAsFixed(1)}%, ${(result.confidenceInterval.upper * 100).toStringAsFixed(1)}%]');
    buffer.writeln('');
    
    buffer.writeln('【光谱波段重要性】');
    for (final entry in result.featureImportance.spectralBands.entries) {
      buffer.writeln('  ${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%');
    }
    buffer.writeln('');
    
    buffer.writeln('【关键波长分析】');
    for (final cw in result.criticalWavelengths.take(5)) {
      final sign = cw.isPositive ? '+' : '-';
      buffer.writeln('  $sign ${cw.wavelength.toStringAsFixed(1)}nm');
      buffer.writeln('    贡献度: ${cw.contribution.toStringAsFixed(4)}');
      buffer.writeln('    化学意义: ${cw.reason}');
    }
    buffer.writeln('');
    
    buffer.writeln('【重要统计特征】');
    final topFeatures = result.featureImportance.topFeatures.entries.take(5);
    for (final entry in topFeatures) {
      final sign = entry.value > 0 ? '+' : '-';
      buffer.writeln('  $sign ${entry.key}: ${entry.value.toStringAsFixed(4)}');
    }
    buffer.writeln('');
    
    buffer.writeln('分析耗时: ${result.analysisDurationMs}ms');
    buffer.writeln('===== 报告结束 =====');
    
    return buffer.toString();
  }

  List<double> _normalizeSpectral(List<double> data) {
    if (data.length == 256) return List.from(data);
    
    final result = <double>[];
    final step = (data.length - 1) / 255;
    
    for (var i = 0; i < 256; i++) {
      final pos = i * step;
      final lower = pos.floor();
      final upper = (pos.ceil()).clamp(0, data.length - 1);
      final frac = pos - lower;
      
      if (lower >= data.length) {
        result.add(data.last);
      } else if (upper >= data.length || lower == upper) {
        result.add(data[lower]);
      } else {
        result.add(data[lower] * (1 - frac) + data[upper] * frac);
      }
    }
    
    return result;
  }

  List<double> _extractFeatures(List<double> spectral) {
    final features = <double>[];
    
    final mean = spectral.fold(0.0, (a, b) => a + b) / spectral.length;
    final variance = spectral.map((v) => pow(v - mean, 2)).fold(0.0, (a, b) => a + b) / spectral.length;
    final std = sqrt(variance);
    final minVal = spectral.reduce((a, b) => a < b ? a : b);
    final maxVal = spectral.reduce((a, b) => a > b ? a : b);
    
    features.add(mean);
    features.add(std);
    features.add(variance);
    features.add(minVal);
    features.add(maxVal);
    features.add(maxVal - minVal);
    
    final sorted = List<double>.from(spectral)..sort();
    features.add(sorted[sorted.length ~/ 2]);
    features.add(sorted[sorted.length ~/ 4]);
    features.add(sorted[(sorted.length * 3) ~/ 4]);
    features.add(features[8] - features[7]);
    
    final skewness = std > 0 
        ? spectral.map((v) => pow((v - mean) / std, 3)).fold(0.0, (a, b) => a + b) / spectral.length
        : 0.0;
    final kurtosis = std > 0
        ? spectral.map((v) => pow((v - mean) / std, 4)).fold(0.0, (a, b) => a + b) / spectral.length - 3
        : 0.0;
    features.add(skewness);
    features.add(kurtosis);
    
    final energy = spectral.map((v) => v * v).fold(0.0, (a, b) => a + b);
    final normalizedSpectral = spectral.map((v) => v.abs() / (energy + 1)).toList();
    final entropy = -normalizedSpectral
        .where((v) => v > 0)
        .map((v) => v * log(v))
        .fold(0.0, (a, b) => a + b);
    features.add(energy);
    features.add(entropy);
    
    final rms = sqrt(energy / spectral.length);
    final cv = mean != 0 ? std / mean.abs() : 0.0;
    features.add(rms);
    features.add(cv.toDouble());
    
    while (features.length < 64) {
      features.add(0.0);
    }
    
    return features.take(64).toList();
  }
}
