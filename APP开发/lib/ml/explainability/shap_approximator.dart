import 'dart:math';
import 'dart:typed_data';
import 'explainability_result.dart';

/// SHAP值近似计算器
/// 使用轻量化的分段扰动+局部线性近似算法
/// 针对移动端性能优化
class ShapApproximator {
  /// 采样次数
  final int numSamples;
  
  /// 扰动强度
  final double perturbationScale;
  
  /// 光谱分段大小
  final int segmentSize;
  
  /// 随机数生成器
  final Random _random;

  /// 波长范围
  static const double minWavelength = 200.0;
  static const double maxWavelength = 1100.0;

  ShapApproximator({
    this.numSamples = 50,
    this.perturbationScale = 0.1,
    this.segmentSize = 16,
    int? seed,
  }) : _random = Random(seed ?? 42);

  /// 计算SHAP值
  /// [spectralData] - 256维光谱数据
  /// [featureData] - 64维统计特征
  /// [targetClass] - 目标类别
  /// [predictionFunction] - 预测函数
  Future<ShapValues> computeShapValues({
    required List<double> spectralData,
    required List<double> featureData,
    required String targetClass,
    required Future<Map<String, double>> Function(Float32List) predictionFunction,
  }) async {
    // 获取基准预测
    final baselineInput = _combineInput(spectralData, featureData);
    final baselinePrediction = await predictionFunction(baselineInput);
    final baselineProb = baselinePrediction[targetClass] ?? 0;

    // 计算光谱SHAP值
    final spectralShap = await _computeSpectralShap(
      spectralData,
      featureData,
      baselineProb,
      targetClass,
      predictionFunction,
    );

    // 计算特征SHAP值
    final featureShap = await _computeFeatureShap(
      spectralData,
      featureData,
      baselineProb,
      targetClass,
      predictionFunction,
    );

    return ShapValues(
      spectral: spectralShap,
      features: featureShap,
      baseline: baselineProb,
    );
  }

  /// 使用模拟方法计算SHAP值（当没有真实模型时）
  ShapValues computeShapValuesWithMock({
    required List<double> spectralData,
    required List<double> featureData,
  }) {
    // 基于光谱数据的导数和变化生成模拟SHAP值
    final spectralShap = <double>[];
    
    for (var i = 0; i < spectralData.length; i++) {
      // 计算局部变化
      double localChange = 0;
      if (i > 0) {
        localChange += (spectralData[i] - spectralData[i - 1]).abs();
      }
      if (i < spectralData.length - 1) {
        localChange += (spectralData[i + 1] - spectralData[i]).abs();
      }
      
      // 计算相对强度
      final relativeIntensity = spectralData[i] / 
          (spectralData.map((v) => v.abs()).reduce((a, b) => a > b ? a : b) + 1);
      
      // 组合生成SHAP值
      final shapValue = localChange * 0.01 * relativeIntensity * 
          (_random.nextDouble() - 0.5) * 2;
      spectralShap.add(shapValue);
    }

    // 特征SHAP值
    final featureShap = <String, double>{};
    final featureNames = [
      '均值', '标准差', '方差', '最小值', '最大值', '极差', '中位数',
      'Q1分位数', 'Q3分位数', '四分位距', '偏度', '峰度', '能量', '熵',
      '均方根', '变异系数', '一阶导数均值', '一阶导数标准差',
    ];
    
    for (var i = 0; i < min(featureData.length, featureNames.length); i++) {
      featureShap[featureNames[i]] = featureData[i] * 0.001 * 
          (_random.nextDouble() - 0.5) * 2;
    }

    // 计算基准值
    final baseline = spectralData.fold(0.0, (a, b) => a + b) / spectralData.length / 1000;

    return ShapValues(
      spectral: spectralShap,
      features: featureShap,
      baseline: baseline.clamp(0.0, 1.0),
    );
  }

  /// 聚合SHAP值到波长区间
  List<ShapRegion> aggregateToRegions(
    List<double> shapValues, {
    int regionCount = 8,
  }) {
    final regions = <ShapRegion>[];
    final regionSize = shapValues.length ~/ regionCount;
    
    for (var r = 0; r < regionCount; r++) {
      final start = r * regionSize;
      final end = (r == regionCount - 1) ? shapValues.length : (r + 1) * regionSize;
      
      final regionValues = shapValues.sublist(start, end);
      final totalShap = regionValues.fold(0.0, (a, b) => a + b);
      final absShap = regionValues.map((v) => v.abs()).fold(0.0, (a, b) => a + b);
      
      final startWavelength = minWavelength + start * (maxWavelength - minWavelength) / 256;
      final endWavelength = minWavelength + end * (maxWavelength - minWavelength) / 256;
      
      regions.add(ShapRegion(
        startIndex: start,
        endIndex: end,
        startWavelength: startWavelength,
        endWavelength: endWavelength,
        totalShap: totalShap,
        absoluteShap: absShap,
        meanShap: totalShap / regionValues.length,
      ));
    }
    
    return regions;
  }

  /// 提取关键波长
  List<CriticalWavelength> extractCriticalWavelengths(
    List<double> shapValues, {
    int topK = 10,
    double threshold = 0.01,
  }) {
    final criticals = <CriticalWavelength>[];
    final wavelengths = List.generate(
      256, 
      (i) => minWavelength + i * (maxWavelength - minWavelength) / 256,
    );
    
    // 寻找局部峰值
    for (var i = 5; i < shapValues.length - 5; i++) {
      final current = shapValues[i].abs();
      final neighbors = [
        ...shapValues.sublist(i - 5, i),
        ...shapValues.sublist(i + 1, i + 6),
      ];
      final maxNeighbor = neighbors.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
      
      // 峰值判断
      if (current > maxNeighbor * 1.2 && current > threshold) {
        criticals.add(CriticalWavelength(
          wavelength: wavelengths[i],
          contribution: shapValues[i],
          importance: current,
          reason: _interpretWavelength(wavelengths[i]),
          index: i,
        ));
      }
    }
    
    // 按重要性排序，取Top-K
    criticals.sort((a, b) => b.importance.compareTo(a.importance));
    return criticals.take(topK).toList();
  }

  // ========== 私有方法 ==========

  /// 计算光谱SHAP值（分段扰动法）
  Future<List<double>> _computeSpectralShap(
    List<double> spectralData,
    List<double> featureData,
    double baseline,
    String targetClass,
    Future<Map<String, double>> Function(Float32List) predictionFunction,
  ) async {
    final numSegments = 256 ~/ segmentSize;
    final shapValues = List<double>.filled(256, 0.0);
    
    // 1. 段级SHAP计算（粗粒度）
    final segmentContributions = <double>[];
    for (var seg = 0; seg < numSegments; seg++) {
      var contribution = 0.0;
      
      for (var sample = 0; sample < numSamples ~/ 4; sample++) {
        final perturbed = _perturbSegment(spectralData, seg);
        final input = _combineInput(perturbed, featureData);
        final pred = await predictionFunction(input);
        contribution += (pred[targetClass] ?? 0) - baseline;
      }
      
      segmentContributions.add(contribution / (numSamples ~/ 4));
    }
    
    // 2. 段内细粒度分配（基于局部梯度）
    for (var seg = 0; seg < numSegments; seg++) {
      final segmentStart = seg * segmentSize;
      final gradient = _computeLocalGradient(spectralData, segmentStart, segmentSize);
      
      // 按梯度比例分配段贡献
      final totalGradient = gradient.map((g) => g.abs()).fold(0.0, (a, b) => a + b);
      if (totalGradient > 0) {
        for (var i = 0; i < segmentSize && segmentStart + i < 256; i++) {
          shapValues[segmentStart + i] = 
              segmentContributions[seg] * gradient[i].abs() / totalGradient;
        }
      }
    }
    
    return shapValues;
  }

  /// 计算特征SHAP值（独立扰动法）
  Future<Map<String, double>> _computeFeatureShap(
    List<double> spectralData,
    List<double> featureData,
    double baseline,
    String targetClass,
    Future<Map<String, double>> Function(Float32List) predictionFunction,
  ) async {
    final featureNames = [
      '均值', '标准差', '方差', '最小值', '最大值', '极差', '中位数',
      'Q1分位数', 'Q3分位数', '四分位距', '偏度', '峰度', '能量', '熵',
      '均方根', '变异系数', '一阶导数均值', '一阶导数标准差', '一阶导数最大值',
      '一阶导数最小值', '一阶导数过零次数', '二阶导数均值', '二阶导数标准差',
      '峰值数量', '谷值数量', '峰高均值', '峰高最大值', '峰间距均值',
      '主峰位置', '主峰高度',
    ];
    
    final shapMap = <String, double>{};
    
    for (var i = 0; i < min(featureData.length, featureNames.length); i++) {
      var contribution = 0.0;
      
      for (var sample = 0; sample < numSamples ~/ 8; sample++) {
        final perturbed = List<double>.from(featureData);
        perturbed[i] += _randomPerturbation() * (featureData[i].abs() + 1);
        
        final input = _combineInput(spectralData, perturbed);
        final pred = await predictionFunction(input);
        contribution += (pred[targetClass] ?? 0) - baseline;
      }
      
      shapMap[featureNames[i]] = contribution / (numSamples ~/ 8);
    }
    
    return shapMap;
  }

  /// 扰动指定段
  List<double> _perturbSegment(List<double> spectral, int segment) {
    final result = List<double>.from(spectral);
    final start = segment * segmentSize;
    final end = min(start + segmentSize, spectral.length);
    
    for (var i = start; i < end; i++) {
      result[i] += _randomPerturbation();
    }
    return result;
  }

  /// 计算局部梯度
  List<double> _computeLocalGradient(List<double> spectral, int start, int length) {
    final gradient = <double>[];
    
    for (var i = 0; i < length && start + i < spectral.length; i++) {
      final idx = start + i;
      double grad = 0;
      
      if (idx > 0 && idx < spectral.length - 1) {
        grad = (spectral[idx + 1] - spectral[idx - 1]) / 2;
      } else if (idx > 0) {
        grad = spectral[idx] - spectral[idx - 1];
      } else if (idx < spectral.length - 1) {
        grad = spectral[idx + 1] - spectral[idx];
      }
      
      gradient.add(grad);
    }
    
    return gradient;
  }

  /// 合并光谱和特征为320维输入
  Float32List _combineInput(List<double> spectral, List<double> features) {
    final input = Float32List(320);
    for (var i = 0; i < min(spectral.length, 256); i++) {
      input[i] = spectral[i];
    }
    for (var i = 0; i < min(features.length, 64); i++) {
      input[256 + i] = features[i];
    }
    return input;
  }

  /// 随机扰动值
  double _randomPerturbation() {
    return (_random.nextDouble() - 0.5) * 2 * perturbationScale;
  }

  /// 波长化学意义解释
  String _interpretWavelength(double wl) {
    if (wl < 300) return '芳香族化合物吸收区';
    if (wl < 400) return '共轭体系跃迁区';
    if (wl < 500) return '紫外-可见过渡区';
    if (wl < 600) return '可见光吸收区';
    if (wl < 700) return '叶绿素吸收带';
    if (wl < 800) return '近红外过渡区';
    if (wl < 950) return 'O-H/N-H伸缩泛频';
    return 'C-H伸缩泛频区';
  }
}

/// SHAP区域
class ShapRegion {
  final int startIndex;
  final int endIndex;
  final double startWavelength;
  final double endWavelength;
  final double totalShap;
  final double absoluteShap;
  final double meanShap;

  ShapRegion({
    required this.startIndex,
    required this.endIndex,
    required this.startWavelength,
    required this.endWavelength,
    required this.totalShap,
    required this.absoluteShap,
    required this.meanShap,
  });

  /// 区域名称
  String get regionName => 
      '${startWavelength.toInt()}-${endWavelength.toInt()}nm';

  /// 是否为正贡献区域
  bool get isPositive => totalShap > 0;
}
