import 'dart:math';
import '../models/models.dart';
import '../ml/enhanced_preprocessor.dart';
import '../ml/feature_engineer.dart';
import '../ml/deep_learning_analyzer.dart';
import '../ml/model_manager.dart';

/// AI分析服务 (深度学习增强版)
/// 集成TensorFlow Lite模型，支持端侧深度学习推理
class AIAnalysisService {
  static final AIAnalysisService _instance = AIAnalysisService._internal();
  factory AIAnalysisService() => _instance;
  AIAnalysisService._internal();

  // 深度学习组件
  final DeepLearningAnalyzer _dlAnalyzer = DeepLearningAnalyzer();
  final EnhancedPreprocessor _preprocessor = EnhancedPreprocessor();
  final FeatureEngineer _featureEngineer = FeatureEngineer();
  final ModelManager _modelManager = ModelManager();

  bool _isInitialized = false;
  AnalysisMode _analysisMode = AnalysisMode.hybrid;

  // 毒死蜱特征波长 (nm) - 用于规则引擎备选
  // UV特征峰: 228nm, 293nm; IR特征峰: 1260, 1040, 960, 680 cm-1; Raman: 680, 720 cm-1
  static const Map<String, List<double>> pesticideSignatures = {
    '毒死蜱': [228.0, 293.0],
  };

  // 毒死蜱最大残留限量 (mg/kg) - GB 2763标准
  static const Map<String, double> maxResidueLimits = {
    '毒死蜱': 0.1,
  };

  // 农药类型映射 - 毒死蜱属于有机磷类
  static const Map<String, PesticideType> pesticideTypes = {
    '毒死蜱': PesticideType.organophosphate,
  };

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _modelManager.initialize();
      await _dlAnalyzer.initialize();

      _isInitialized = true;
      print('AIAnalysisService initialized with deep learning support');
    } catch (e) {
      print('AIAnalysisService initialization failed: $e');
      _analysisMode = AnalysisMode.ruleEngine;
      _isInitialized = true;
    }
  }

  /// 设置分析模式
  void setAnalysisMode(AnalysisMode mode) {
    _analysisMode = mode;
    print('Analysis mode set to: ${mode.name}');
  }

  /// 检查设备是否支持深度学习模式
  Future<bool> isDeepLearningSupported() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return _dlAnalyzer.modelsLoaded;
    } catch (e) {
      print('Deep learning support check failed: $e');
      return false;
    }
  }

  /// 获取推荐的分析模式
  Future<AnalysisMode> getRecommendedAnalysisMode() async {
    final isSupported = await isDeepLearningSupported();
    if (isSupported) {
      return AnalysisMode.hybrid;
    } else {
      return AnalysisMode.ruleEngine;
    }
  }

  /// 获取当前分析模式
  AnalysisMode get analysisMode => _analysisMode;

  /// 使用深度学习模型分析 (公开接口)
  Future<DetectionResult> analyzeWithDeepLearning({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    _validateInput(spectralData, sampleName);
    if (!_isInitialized) await initialize();
    return _analyzeWithDeepLearning(
      spectralData: spectralData,
      sampleName: sampleName,
      sampleCategory: sampleCategory,
    );
  }

  /// 使用混合模式分析 (公开接口)
  Future<DetectionResult> analyzeWithHybridMode({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    _validateInput(spectralData, sampleName);
    if (!_isInitialized) await initialize();
    return _analyzeWithHybrid(
      spectralData: spectralData,
      sampleName: sampleName,
      sampleCategory: sampleCategory,
    );
  }

  /// 使用深度学习模型分析光谱数据
  Future<DetectionResult> analyzeSpectralData({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    _validateInput(spectralData, sampleName);
    if (!_isInitialized) await initialize();

    switch (_analysisMode) {
      case AnalysisMode.deepLearning:
        return _analyzeWithDeepLearning(
          spectralData: spectralData,
          sampleName: sampleName,
          sampleCategory: sampleCategory,
        );
      case AnalysisMode.ruleEngine:
        return _analyzeWithRuleEngine(
          spectralData: spectralData,
          sampleName: sampleName,
          sampleCategory: sampleCategory,
        );
      case AnalysisMode.hybrid:
      case AnalysisMode.import:
      case AnalysisMode.mock:
        return _analyzeWithHybrid(
          spectralData: spectralData,
          sampleName: sampleName,
          sampleCategory: sampleCategory,
        );
    }
  }

  /// 统一输入验证
  void _validateInput(SpectralData spectralData, String sampleName) {
    if (spectralData.wavelengths.isEmpty || spectralData.intensities.isEmpty) {
      throw ArgumentError(
        'spectralData must contain valid wavelength and intensity data',
      );
    }
    if (sampleName.trim().isEmpty) {
      throw ArgumentError('sampleName cannot be empty');
    }
  }

  /// 深度学习分析
  Future<DetectionResult> _analyzeWithDeepLearning({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    try {
      final result = await _dlAnalyzer.analyze(spectralData);
      return result.toDetectionResult(
        sampleName: sampleName,
        sampleCategory: sampleCategory,
        spectralDataId: spectralData.id,
      );
    } catch (e) {
      print('Deep learning analysis failed: $e, falling back to rule engine');
      return _analyzeWithRuleEngine(
        spectralData: spectralData,
        sampleName: sampleName,
        sampleCategory: sampleCategory,
      );
    }
  }

  /// 规则引擎分析
  Future<DetectionResult> _analyzeWithRuleEngine({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final processed = _preprocessor.process(
      spectralData.wavelengths,
      spectralData.intensities,
    );

    final features = _featureEngineer.extractFeatures(processed.intensities);

    final detectedPesticides =
        _detectPesticidesWithRules(spectralData, features);
    final confidence = _calculateConfidence(features, detectedPesticides);
    final riskLevel = _determineRiskLevel(detectedPesticides);

    return DetectionResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      sampleName: sampleName,
      sampleCategory: sampleCategory,
      riskLevel: riskLevel,
      confidence: confidence,
      detectedPesticides: detectedPesticides,
      spectralDataId: spectralData.id,
    );
  }

  /// 混合分析 (深度学习 + 规则引擎)
  Future<DetectionResult> _analyzeWithHybrid({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    final results = await Future.wait([
      _analyzeWithDeepLearning(
        spectralData: spectralData,
        sampleName: sampleName,
        sampleCategory: sampleCategory,
      ),
      _analyzeWithRuleEngine(
        spectralData: spectralData,
        sampleName: sampleName,
        sampleCategory: sampleCategory,
      ),
    ]);

    return _fuseResults(
      results[0],
      results[1],
      sampleName,
      sampleCategory,
      spectralData.id,
    );
  }

  /// 融合深度学习和规则引擎的结果
  DetectionResult _fuseResults(
    DetectionResult dlResult,
    DetectionResult ruleResult,
    String sampleName,
    String? sampleCategory,
    String spectralDataId,
  ) {
    final mergedPesticides = <String, DetectedPesticide>{};

    for (final p in dlResult.detectedPesticides) {
      mergedPesticides[p.name] = p;
    }

    for (final p in ruleResult.detectedPesticides) {
      if (mergedPesticides.containsKey(p.name)) {
        final existing = mergedPesticides[p.name]!;
        final fusedConcentration =
            (existing.concentration * dlResult.confidence +
                    p.concentration * ruleResult.confidence) /
                (dlResult.confidence + ruleResult.confidence);

        mergedPesticides[p.name] = DetectedPesticide(
          name: p.name,
          type: p.type,
          concentration: fusedConcentration,
          maxResidueLimit: p.maxResidueLimit,
        );
      } else {
        mergedPesticides[p.name] = DetectedPesticide(
          name: p.name,
          type: p.type,
          concentration: p.concentration * 0.8,
          maxResidueLimit: p.maxResidueLimit,
        );
      }
    }

    final fusedConfidence =
        (dlResult.confidence * 0.7 + ruleResult.confidence * 0.3)
            .clamp(0.0, 1.0);

    final fusedPesticides = mergedPesticides.values.toList();
    final riskLevel = _determineRiskLevel(fusedPesticides);

    return DetectionResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      sampleName: sampleName,
      sampleCategory: sampleCategory,
      riskLevel: riskLevel,
      confidence: fusedConfidence,
      detectedPesticides: fusedPesticides,
      spectralDataId: spectralDataId,
    );
  }

  /// 基于规则检测农药
  List<DetectedPesticide> _detectPesticidesWithRules(
    SpectralData spectralData,
    SpectralFeatures features,
  ) {
    final detectedPesticides = <DetectedPesticide>[];
    final wavelengths = spectralData.wavelengths;
    final intensities = spectralData.normalizedIntensities;

    for (final entry in pesticideSignatures.entries) {
      final pesticide = entry.key;
      final signatureWavelengths = entry.value;

      double matchScore = 0;
      int matchCount = 0;

      for (final sigWl in signatureWavelengths) {
        var minDiff = double.infinity;
        var closestIdx = -1;

        for (var i = 0; i < wavelengths.length; i++) {
          final diff = (wavelengths[i] - sigWl).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestIdx = i;
          }
        }

        if (closestIdx >= 0 && minDiff < 10 && intensities[closestIdx] > 0.3) {
          matchScore += intensities[closestIdx];
          matchCount++;
        }
      }

      if (matchCount >= signatureWavelengths.length * 0.5) {
        final avgScore = matchScore / matchCount;
        final estimatedConcentration =
            avgScore * maxResidueLimits[pesticide]! * 2;

        detectedPesticides.add(DetectedPesticide(
          name: pesticide,
          type: pesticideTypes[pesticide] ?? PesticideType.unknown,
          concentration: estimatedConcentration,
          maxResidueLimit: maxResidueLimits[pesticide]!,
        ));
      }
    }

    return detectedPesticides;
  }

  /// 计算置信度
  double _calculateConfidence(
    SpectralFeatures features,
    List<DetectedPesticide> detectedPesticides,
  ) {
    double confidence = 0.7;

    final std = features.getFeature('statistical_std') ?? 0.0;
    final peakCount = features.getFeature('peaks_peak_count') ?? 0.0;

    if (std > 0.1 && std < 0.5) confidence += 0.1;
    if (peakCount >= 3 && peakCount <= 10) confidence += 0.1;

    if (detectedPesticides.isEmpty) {
      confidence += 0.05;
    } else if (detectedPesticides.length <= 3) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 确定风险等级
  RiskLevel _determineRiskLevel(List<DetectedPesticide> detectedPesticides) {
    if (detectedPesticides.isEmpty) {
      return RiskLevel.safe;
    }

    final hasOverLimit = detectedPesticides.any((p) => p.isOverLimit);
    if (!hasOverLimit) {
      return RiskLevel.low;
    }

    final maxOverRatio =
        detectedPesticides.map((p) => p.overLimitRatio).reduce(max);

    if (maxOverRatio > 5) {
      return RiskLevel.critical;
    } else if (maxOverRatio > 2) {
      return RiskLevel.high;
    } else if (maxOverRatio > 1) {
      return RiskLevel.medium;
    } else {
      return RiskLevel.low;
    }
  }

  /// 生成分析报告
  String generateReport(DetectionResult result) {
    final buffer = StringBuffer();

    buffer.writeln('===== 农药残留检测报告 (深度学习增强版) =====');
    buffer.writeln('');
    buffer.writeln('检测时间: ${result.timestamp}');
    buffer.writeln('样品名称: ${result.sampleName}');
    if (result.sampleCategory != null) {
      buffer.writeln('样品类别: ${result.sampleCategory}');
    }
    buffer.writeln('分析模式: ${_analysisMode.name}');
    buffer.writeln('');
    buffer.writeln('【检测结果】');
    buffer.writeln('风险等级: ${result.riskLevelDescription}');
    buffer.writeln('置信度: ${(result.confidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    if (result.hasPesticides) {
      buffer.writeln('【检出农药】');
      for (final pesticide in result.detectedPesticides) {
        final status = pesticide.isOverLimit ? '(超标!)' : '(合格)';
        buffer.writeln(
          '- ${pesticide.name}: ${pesticide.concentration.toStringAsFixed(4)} ${pesticide.unit} '
          '(限量: ${pesticide.maxResidueLimit} ${pesticide.unit}) $status',
        );
      }
    } else {
      buffer.writeln('未检出农药残留');
    }

    buffer.writeln('');
    buffer.writeln('【模型信息】');
    final modelInfo = getModelInfo();
    for (final entry in modelInfo.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    buffer.writeln('');
    buffer.writeln('===== 报告结束 =====');

    return buffer.toString();
  }

  /// 模拟检测 (用于演示)
  Future<DetectionResult> simulateDetection({
    required String sampleName,
    String? sampleCategory,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    final random = Random();
    final hasPesticide = random.nextDouble() > 0.3;

    final detectedPesticides = <DetectedPesticide>[];

    if (hasPesticide) {
      final mrl = maxResidueLimits['毒死蜱']!;
      final concentration = mrl * (random.nextDouble() * 3);

      detectedPesticides.add(DetectedPesticide(
        name: '毒死蜱',
        type: PesticideType.organophosphate,
        concentration: concentration,
        maxResidueLimit: mrl,
      ));
    }

    final riskLevel = _determineRiskLevel(detectedPesticides);
    final confidence = 0.75 + random.nextDouble() * 0.2;

    return DetectionResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      sampleName: sampleName,
      sampleCategory: sampleCategory,
      riskLevel: riskLevel,
      confidence: confidence,
      detectedPesticides: detectedPesticides,
    );
  }

  Map<String, String> getModelInfo() {
    final hasRealModels = _dlAnalyzer.modelsLoaded;
    final version = hasRealModels
        ? (_dlAnalyzer.modelVersion ?? _modelManager.currentVersion)
        : 'unavailable';

    return {
      'framework':
          hasRealModels ? 'TensorFlow Lite' : 'Enhanced Hybrid Fallback',
      'model_type': hasRealModels
          ? 'CNN-Spectroscopic-Classifier'
          : 'Rule-enhanced analytical pipeline',
      'version': version,
      'analysis_mode': _analysisMode.name,
      'runtime_status': hasRealModels ? 'ready' : 'degraded',
      'input_shape': '[1, 320]',
      'output_classes': '2',
      'preprocessing': 'ALS + SG Filter + MinMax',
      'feature_extraction': 'Statistical + Wavelet + Frequency',
      if (!hasRealModels)
        'fallback_reason': _dlAnalyzer.lastModelLoadError ?? '真实TFLite模型不可用',
    };
  }

  Future<ModelUpdateInfo?> checkModelUpdate() async {
    return await _modelManager.checkForUpdate();
  }

  /// 下载模型更新
  Future<bool> downloadModelUpdate(ModelUpdateInfo updateInfo) async {
    return await _modelManager.downloadUpdate(updateInfo);
  }

  /// 获取模型版本
  String get modelVersion => _modelManager.currentVersion;

  /// 释放资源
  void dispose() {
    _dlAnalyzer.dispose();
    _modelManager.dispose();
  }
}
