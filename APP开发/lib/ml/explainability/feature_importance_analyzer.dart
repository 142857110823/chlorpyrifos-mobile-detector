import 'dart:math';
import 'dart:typed_data';
import 'explainability_result.dart';

/// 特征重要性分析器
/// 使用置换重要性(Permutation Importance)计算各特征对预测的贡献
class FeatureImportanceAnalyzer {
  /// 采样次数
  final int numSamples;
  
  /// 扰动强度
  final double perturbationScale;
  
  /// Top-K特征数量
  final int topK;
  
  /// 随机数生成器
  final Random _random = Random(42);

  /// 波长范围（对应256个点）
  static const double minWavelength = 200.0;
  static const double maxWavelength = 1100.0;

  /// 统计特征名称列表
  static const List<String> featureNames = [
    // 统计特征 (16个)
    '均值', '标准差', '方差', '最小值', '最大值', '极差', '中位数', 
    'Q1分位数', 'Q3分位数', '四分位距', '偏度', '峰度', '能量', '熵', 
    '均方根', '变异系数',
    // 导数特征 (7个)
    '一阶导数均值', '一阶导数标准差', '一阶导数最大值', '一阶导数最小值',
    '一阶导数过零次数', '二阶导数均值', '二阶导数标准差',
    // 峰值特征 (7个)
    '峰值数量', '谷值数量', '峰高均值', '峰高最大值',
    '峰间距均值', '主峰位置', '主峰高度',
    // 小波特征 (12个)
    '小波D1能量', '小波D1均值', '小波D1标准差',
    '小波D2能量', '小波D2均值', '小波D2标准差',
    '小波D3能量', '小波D3均值', '小波D3标准差',
    '小波近似能量', '小波近似均值', '小波近似标准差',
    // 频域特征 (5个)
    '总功率', '主频率', '频谱质心', '频谱带宽', '低高频比',
    // 纹理特征 (5个)
    '自相关滞后1', '自相关滞后5', '粗糙度', '平滑度', '均匀度',
    // 保留 (12个)
    '保留1', '保留2', '保留3', '保留4', '保留5', '保留6',
    '保留7', '保留8', '保留9', '保留10', '保留11', '保留12',
  ];

  /// 波段定义
  static const Map<String, List<int>> spectralBands = {
    'UV区 (200-380nm)': [0, 40],
    '可见光区 (380-700nm)': [40, 111],
    '近红外区 (700-1100nm)': [111, 256],
  };

  FeatureImportanceAnalyzer({
    this.numSamples = 50,
    this.perturbationScale = 0.1,
    this.topK = 20,
  });

  /// 计算特征重要性
  /// [spectralData] - 256维光谱数据
  /// [featureData] - 64维统计特征
  /// [predictionFunction] - 预测函数，接收320维输入返回预测概率
  Future<FeatureImportance> analyze({
    required List<double> spectralData,
    required List<double> featureData,
    required Future<double> Function(Float32List) predictionFunction,
  }) async {
    // 获取基准预测
    final baselineInput = _combineInput(spectralData, featureData);
    final baselinePrediction = await predictionFunction(baselineInput);

    // 计算光谱波段重要性
    final spectralBandImportance = await _computeSpectralBandImportance(
      spectralData,
      featureData,
      baselinePrediction,
      predictionFunction,
    );

    // 计算统计特征重要性
    final featureImportanceMap = await _computeFeatureImportance(
      spectralData,
      featureData,
      baselinePrediction,
      predictionFunction,
    );

    // 排序并取Top-K
    final sortedFeatures = featureImportanceMap.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final topFeatures = Map<String, double>.fromEntries(
      sortedFeatures.take(topK),
    );

    // 计算全局重要性得分
    final spectralScore = spectralBandImportance.values
        .map((v) => v.abs())
        .fold(0.0, (a, b) => a + b);
    final featureScore = featureImportanceMap.values
        .map((v) => v.abs())
        .fold(0.0, (a, b) => a + b);
    final globalScore = spectralScore + featureScore;

    return FeatureImportance(
      spectralBands: spectralBandImportance,
      topFeatures: topFeatures,
      globalImportanceScore: globalScore,
    );
  }

  /// 使用模拟预测函数进行分析（当没有真实模型时）
  FeatureImportance analyzeWithMock({
    required List<double> spectralData,
    required List<double> featureData,
  }) {
    // 基于光谱数据的统计特性生成模拟重要性
    final spectralBandImportance = <String, double>{};
    
    for (final entry in spectralBands.entries) {
      final bandData = spectralData.sublist(entry.value[0], entry.value[1]);
      final bandVariance = _computeVariance(bandData);
      final bandEnergy = bandData.map((v) => v * v).fold(0.0, (a, b) => a + b);
      spectralBandImportance[entry.key] = bandVariance * 0.3 + bandEnergy * 0.0001;
    }

    // 归一化
    final totalSpectral = spectralBandImportance.values.fold(0.0, (a, b) => a + b);
    if (totalSpectral > 0) {
      for (final key in spectralBandImportance.keys) {
        spectralBandImportance[key] = spectralBandImportance[key]! / totalSpectral;
      }
    }

    // 生成特征重要性
    final featureImportanceMap = <String, double>{};
    for (var i = 0; i < min(featureData.length, featureNames.length); i++) {
      // 基于特征值的绝对值和位置生成模拟重要性
      final importance = featureData[i].abs() * (1.0 - i * 0.01) * _random.nextDouble() * 0.5;
      featureImportanceMap[featureNames[i]] = importance * (_random.nextBool() ? 1 : -1);
    }

    // 排序并取Top-K
    final sortedFeatures = featureImportanceMap.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final topFeatures = Map<String, double>.fromEntries(
      sortedFeatures.take(topK),
    );

    return FeatureImportance(
      spectralBands: spectralBandImportance,
      topFeatures: topFeatures,
      globalImportanceScore: 1.0,
    );
  }

  /// 计算波长贡献度
  List<WavelengthContribution> calculateWavelengthContributions({
    required List<double> spectralData,
    required List<double> shapValues,
  }) {
    final contributions = <WavelengthContribution>[];
    
    for (var i = 0; i < spectralData.length; i++) {
      final wavelength = minWavelength + i * (maxWavelength - minWavelength) / 256;
      contributions.add(WavelengthContribution(
        index: i,
        wavelength: wavelength,
        intensity: spectralData[i],
        contribution: shapValues.isNotEmpty && i < shapValues.length ? shapValues[i] : 0,
        band: _getBandForIndex(i),
      ));
    }
    
    return contributions;
  }

  /// 获取Top-K重要特征
  List<ImportantFeature> getTopFeatures(
    Map<String, double> featureImportance,
    int k,
  ) {
    final sorted = featureImportance.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    
    return sorted.take(k).map((e) => ImportantFeature(
      name: e.key,
      importance: e.value,
      isPositive: e.value > 0,
      description: _getFeatureDescription(e.key),
    )).toList();
  }

  // ========== 私有方法 ==========

  /// 计算光谱波段重要性
  Future<Map<String, double>> _computeSpectralBandImportance(
    List<double> spectralData,
    List<double> featureData,
    double baselinePrediction,
    Future<double> Function(Float32List) predictionFunction,
  ) async {
    final importance = <String, double>{};
    
    for (final entry in spectralBands.entries) {
      var totalDiff = 0.0;
      
      for (var sample = 0; sample < numSamples ~/ 3; sample++) {
        // 扰动当前波段
        final perturbed = List<double>.from(spectralData);
        for (var i = entry.value[0]; i < entry.value[1]; i++) {
          perturbed[i] += _randomPerturbation();
        }
        
        final input = _combineInput(perturbed, featureData);
        final prediction = await predictionFunction(input);
        totalDiff += (prediction - baselinePrediction).abs();
      }
      
      importance[entry.key] = totalDiff / (numSamples ~/ 3);
    }
    
    return importance;
  }

  /// 计算统计特征重要性
  Future<Map<String, double>> _computeFeatureImportance(
    List<double> spectralData,
    List<double> featureData,
    double baselinePrediction,
    Future<double> Function(Float32List) predictionFunction,
  ) async {
    final importance = <String, double>{};
    
    for (var i = 0; i < min(featureData.length, featureNames.length); i++) {
      var totalDiff = 0.0;
      
      for (var sample = 0; sample < numSamples ~/ 8; sample++) {
        // 扰动当前特征
        final perturbed = List<double>.from(featureData);
        perturbed[i] += _randomPerturbation() * featureData[i].abs();
        
        final input = _combineInput(spectralData, perturbed);
        final prediction = await predictionFunction(input);
        totalDiff += prediction - baselinePrediction;
      }
      
      importance[featureNames[i]] = totalDiff / (numSamples ~/ 8);
    }
    
    return importance;
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

  /// 计算方差
  double _computeVariance(List<double> data) {
    if (data.isEmpty) return 0;
    final mean = data.fold(0.0, (a, b) => a + b) / data.length;
    return data.map((v) => pow(v - mean, 2)).fold(0.0, (a, b) => a + b) / data.length;
  }

  /// 获取索引对应的波段
  String _getBandForIndex(int index) {
    for (final entry in spectralBands.entries) {
      if (index >= entry.value[0] && index < entry.value[1]) {
        return entry.key;
      }
    }
    return '未知波段';
  }

  /// 获取特征描述
  String _getFeatureDescription(String name) {
    const descriptions = {
      '均值': '光谱强度的平均水平',
      '标准差': '光谱强度的变异程度',
      '方差': '光谱强度的离散程度',
      '偏度': '光谱分布的对称性',
      '峰度': '光谱分布的尖锐程度',
      '能量': '光谱总能量',
      '熵': '光谱复杂度',
      '峰值数量': '特征吸收峰的数量',
      '主峰位置': '最强吸收峰的波长位置',
      '频谱质心': '频谱能量的中心位置',
    };
    return descriptions[name] ?? '统计特征';
  }
}

/// 波长贡献度
class WavelengthContribution {
  final int index;
  final double wavelength;
  final double intensity;
  final double contribution;
  final String band;

  WavelengthContribution({
    required this.index,
    required this.wavelength,
    required this.intensity,
    required this.contribution,
    required this.band,
  });
}

/// 重要特征
class ImportantFeature {
  final String name;
  final double importance;
  final bool isPositive;
  final String description;

  ImportantFeature({
    required this.name,
    required this.importance,
    required this.isPositive,
    required this.description,
  });
}
