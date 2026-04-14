import 'dart:math';
import 'dart:typed_data';

/// 特征工程模块
/// 实现小波变换、PCA、光谱导数计算等特征提取方法
class FeatureEngineer {
  /// 配置参数
  final FeatureConfig config;

  FeatureEngineer({FeatureConfig? config})
      : config = config ?? FeatureConfig.defaultConfig();

  /// 完整特征提取流程
  SpectralFeatures extractFeatures(List<double> data) {
    final features = <String, dynamic>{};

    // 1. 统计特征
    final stats = extractStatisticalFeatures(data);
    features['statistical'] = stats;

    // 2. 光谱导数特征
    final derivatives = extractDerivativeFeatures(data);
    features['derivatives'] = derivatives;

    // 3. 峰值特征
    final peaks = extractPeakFeatures(data);
    features['peaks'] = peaks;

    // 4. 小波特征
    if (config.useWaveletFeatures) {
      final wavelet = extractWaveletFeatures(data);
      features['wavelet'] = wavelet;
    }

    // 5. 频域特征
    if (config.useFrequencyFeatures) {
      final frequency = extractFrequencyFeatures(data);
      features['frequency'] = frequency;
    }

    // 6. 纹理特征
    final texture = extractTextureFeatures(data);
    features['texture'] = texture;

    // 合并所有特征为向量
    final featureVector = _buildFeatureVector(features);

    return SpectralFeatures(
      rawFeatures: features,
      featureVector: featureVector,
      featureNames: _getFeatureNames(features),
    );
  }

  /// 提取统计特征
  Map<String, double> extractStatisticalFeatures(List<double> data) {
    if (data.isEmpty) return {};

    final n = data.length;
    final sorted = List<double>.from(data)..sort();

    // 基础统计量
    final mean = data.reduce((a, b) => a + b) / n;
    final variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / n;
    final std = sqrt(variance);
    final minVal = sorted.first;
    final maxVal = sorted.last;
    final range = maxVal - minVal;
    final median = n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;

    // 分位数
    final q1 = sorted[(n * 0.25).floor()];
    final q3 = sorted[(n * 0.75).floor()];
    final iqr = q3 - q1;

    // 高阶统计量
    final skewness = std > 0
        ? data.map((x) => pow((x - mean) / std, 3)).reduce((a, b) => a + b) / n
        : 0.0;
    final kurtosis = std > 0
        ? data.map((x) => pow((x - mean) / std, 4)).reduce((a, b) => a + b) / n - 3
        : 0.0;

    // 能量和熵
    final energy = data.map((x) => x * x).reduce((a, b) => a + b);
    final entropy = _calculateEntropy(data);

    // 均方根
    final rms = sqrt(energy / n);

    // 变异系数
    final cv = mean != 0 ? std / mean.abs() : 0.0;

    return {
      'mean': mean,
      'std': std,
      'variance': variance,
      'min': minVal,
      'max': maxVal,
      'range': range,
      'median': median,
      'q1': q1,
      'q3': q3,
      'iqr': iqr,
      'skewness': skewness,
      'kurtosis': kurtosis,
      'energy': energy,
      'entropy': entropy,
      'rms': rms,
      'cv': cv,
    };
  }

  /// 计算信息熵
  double _calculateEntropy(List<double> data, {int bins = 20}) {
    if (data.isEmpty) return 0;

    final minVal = data.reduce(min);
    final maxVal = data.reduce(max);
    final range = maxVal - minVal;
    
    if (range == 0) return 0;

    // 构建直方图
    final histogram = List<int>.filled(bins, 0);
    for (final v in data) {
      final binIdx = ((v - minVal) / range * (bins - 1)).floor().clamp(0, bins - 1);
      histogram[binIdx]++;
    }

    // 计算熵
    var entropy = 0.0;
    final n = data.length;
    for (final count in histogram) {
      if (count > 0) {
        final p = count / n;
        entropy -= p * log(p);
      }
    }

    return entropy;
  }

  /// 提取导数特征
  Map<String, double> extractDerivativeFeatures(List<double> data) {
    if (data.length < 3) return {};

    // 一阶导数
    final d1 = <double>[];
    for (var i = 1; i < data.length; i++) {
      d1.add(data[i] - data[i - 1]);
    }

    // 二阶导数
    final d2 = <double>[];
    for (var i = 1; i < d1.length; i++) {
      d2.add(d1[i] - d1[i - 1]);
    }

    // 一阶导数统计
    final d1Mean = d1.reduce((a, b) => a + b) / d1.length;
    final d1Std = sqrt(d1.map((x) => pow(x - d1Mean, 2)).reduce((a, b) => a + b) / d1.length);
    final d1Max = d1.reduce(max);
    final d1Min = d1.reduce(min);

    // 二阶导数统计
    final d2Mean = d2.isNotEmpty ? d2.reduce((a, b) => a + b) / d2.length : 0.0;
    final d2Std = d2.isNotEmpty 
        ? sqrt(d2.map((x) => pow(x - d2Mean, 2)).reduce((a, b) => a + b) / d2.length)
        : 0.0;

    // 零交叉计数
    var d1ZeroCrossings = 0;
    for (var i = 1; i < d1.length; i++) {
      if (d1[i] * d1[i - 1] < 0) d1ZeroCrossings++;
    }

    return {
      'd1_mean': d1Mean,
      'd1_std': d1Std,
      'd1_max': d1Max,
      'd1_min': d1Min,
      'd1_zero_crossings': d1ZeroCrossings.toDouble(),
      'd2_mean': d2Mean,
      'd2_std': d2Std,
    };
  }

  /// 提取峰值特征
  Map<String, double> extractPeakFeatures(List<double> data, {double threshold = 0.1}) {
    if (data.length < 3) return {};

    final peaks = <int>[];
    final valleys = <int>[];

    // 查找峰值和谷值
    for (var i = 1; i < data.length - 1; i++) {
      if (data[i] > data[i - 1] && data[i] > data[i + 1] && data[i] > threshold) {
        peaks.add(i);
      }
      if (data[i] < data[i - 1] && data[i] < data[i + 1]) {
        valleys.add(i);
      }
    }

    // 峰值统计
    final peakCount = peaks.length.toDouble();
    final valleyCount = valleys.length.toDouble();

    // 峰值高度统计
    var peakHeightMean = 0.0;
    var peakHeightMax = 0.0;
    if (peaks.isNotEmpty) {
      final peakHeights = peaks.map((i) => data[i]).toList();
      peakHeightMean = peakHeights.reduce((a, b) => a + b) / peakHeights.length;
      peakHeightMax = peakHeights.reduce(max);
    }

    // 峰间距统计
    var peakDistanceMean = 0.0;
    if (peaks.length > 1) {
      final distances = <double>[];
      for (var i = 1; i < peaks.length; i++) {
        distances.add((peaks[i] - peaks[i - 1]).toDouble());
      }
      peakDistanceMean = distances.reduce((a, b) => a + b) / distances.length;
    }

    // 主峰位置和高度
    var mainPeakIdx = 0;
    var mainPeakHeight = 0.0;
    if (peaks.isNotEmpty) {
      mainPeakIdx = peaks.reduce((a, b) => data[a] > data[b] ? a : b);
      mainPeakHeight = data[mainPeakIdx];
    }

    return {
      'peak_count': peakCount,
      'valley_count': valleyCount,
      'peak_height_mean': peakHeightMean,
      'peak_height_max': peakHeightMax,
      'peak_distance_mean': peakDistanceMean,
      'main_peak_position': mainPeakIdx / data.length,
      'main_peak_height': mainPeakHeight,
    };
  }

  /// 提取小波特征 (Haar小波简化版)
  Map<String, double> extractWaveletFeatures(List<double> data, {int levels = 3}) {
    final features = <String, double>{};
    var current = List<double>.from(data);

    for (var level = 0; level < levels && current.length >= 2; level++) {
      final approx = <double>[];
      final detail = <double>[];

      for (var i = 0; i < current.length - 1; i += 2) {
        approx.add((current[i] + current[i + 1]) / sqrt(2));
        detail.add((current[i] - current[i + 1]) / sqrt(2));
      }

      // 细节系数统计
      if (detail.isNotEmpty) {
        final detailEnergy = detail.map((x) => x * x).reduce((a, b) => a + b);
        final detailMean = detail.reduce((a, b) => a + b) / detail.length;
        final detailStd = sqrt(detail.map((x) => pow(x - detailMean, 2)).reduce((a, b) => a + b) / detail.length);

        features['wavelet_d${level}_energy'] = detailEnergy;
        features['wavelet_d${level}_mean'] = detailMean;
        features['wavelet_d${level}_std'] = detailStd;
      }

      current = approx;
    }

    // 最终近似系数统计
    if (current.isNotEmpty) {
      final approxEnergy = current.map((x) => x * x).reduce((a, b) => a + b);
      features['wavelet_approx_energy'] = approxEnergy;
    }

    return features;
  }

  /// 提取频域特征 (使用DFT)
  Map<String, double> extractFrequencyFeatures(List<double> data) {
    if (data.length < 4) return {};

    // 简化的DFT实现
    final n = data.length;
    final magnitudes = <double>[];

    for (var k = 0; k < n ~/ 2; k++) {
      var real = 0.0;
      var imag = 0.0;
      
      for (var t = 0; t < n; t++) {
        final angle = 2 * pi * k * t / n;
        real += data[t] * cos(angle);
        imag -= data[t] * sin(angle);
      }
      
      magnitudes.add(sqrt(real * real + imag * imag));
    }

    if (magnitudes.isEmpty) return {};

    // 频域统计特征
    final totalPower = magnitudes.map((x) => x * x).reduce((a, b) => a + b);
    
    // 主频率
    var maxMagIdx = 0;
    for (var i = 1; i < magnitudes.length; i++) {
      if (magnitudes[i] > magnitudes[maxMagIdx]) maxMagIdx = i;
    }
    final dominantFreq = maxMagIdx / magnitudes.length;

    // 频谱质心
    var centroidNum = 0.0;
    var centroidDen = 0.0;
    for (var i = 0; i < magnitudes.length; i++) {
      centroidNum += i * magnitudes[i];
      centroidDen += magnitudes[i];
    }
    final spectralCentroid = centroidDen > 0 ? centroidNum / centroidDen / magnitudes.length : 0.0;

    // 频谱带宽
    var bandwidthNum = 0.0;
    for (var i = 0; i < magnitudes.length; i++) {
      bandwidthNum += pow(i / magnitudes.length - spectralCentroid, 2) * magnitudes[i];
    }
    final spectralBandwidth = centroidDen > 0 ? sqrt(bandwidthNum / centroidDen) : 0.0;

    // 低频/高频能量比
    final midPoint = magnitudes.length ~/ 2;
    final lowFreqEnergy = magnitudes.sublist(0, midPoint).map((x) => x * x).reduce((a, b) => a + b);
    final highFreqEnergy = magnitudes.sublist(midPoint).map((x) => x * x).reduce((a, b) => a + b);
    final freqRatio = highFreqEnergy > 0 ? lowFreqEnergy / highFreqEnergy : 0.0;

    return {
      'total_power': totalPower,
      'dominant_freq': dominantFreq,
      'spectral_centroid': spectralCentroid,
      'spectral_bandwidth': spectralBandwidth,
      'low_high_freq_ratio': freqRatio,
    };
  }

  /// 提取纹理特征
  Map<String, double> extractTextureFeatures(List<double> data) {
    if (data.length < 2) return {};

    // 自相关特征
    final autocorr = _autocorrelation(data, maxLag: min(10, data.length ~/ 2));

    // 粗糙度 (相邻点差值的绝对值之和)
    var roughness = 0.0;
    for (var i = 1; i < data.length; i++) {
      roughness += (data[i] - data[i - 1]).abs();
    }
    roughness /= data.length - 1;

    // 平滑度
    final mean = data.reduce((a, b) => a + b) / data.length;
    final variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
    final smoothness = variance > 0 ? 1 - 1 / (1 + variance) : 1.0;

    // 均匀度
    final uniformity = data.map((x) => x * x).reduce((a, b) => a + b) / data.length;

    return {
      'autocorr_lag1': autocorr.isNotEmpty ? autocorr[0] : 0.0,
      'autocorr_lag5': autocorr.length > 4 ? autocorr[4] : 0.0,
      'roughness': roughness,
      'smoothness': smoothness,
      'uniformity': uniformity,
    };
  }

  /// 计算自相关
  List<double> _autocorrelation(List<double> data, {int maxLag = 10}) {
    final n = data.length;
    final mean = data.reduce((a, b) => a + b) / n;
    final variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b);
    
    if (variance == 0) return List.filled(maxLag, 0);

    final result = <double>[];
    for (var lag = 1; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var i = 0; i < n - lag; i++) {
        sum += (data[i] - mean) * (data[i + lag] - mean);
      }
      result.add(sum / variance);
    }

    return result;
  }

  /// 构建特征向量
  List<double> _buildFeatureVector(Map<String, dynamic> features) {
    final vector = <double>[];

    void addFeatures(dynamic value) {
      if (value is Map<String, double>) {
        vector.addAll(value.values);
      } else if (value is Map<String, dynamic>) {
        for (final v in value.values) {
          addFeatures(v);
        }
      }
    }

    for (final value in features.values) {
      addFeatures(value);
    }

    // 特征选择：移除低方差特征
    final selectedVector = _selectFeatures(vector);
    
    // 特征标准化
    final normalizedVector = _normalizeFeatures(selectedVector);

    return normalizedVector;
  }

  /// 特征选择（基于方差）
  List<double> _selectFeatures(List<double> features) {
    if (features.length <= 10) return features; // 特征数量较少时不进行选择

    // 计算方差
    final mean = features.reduce((a, b) => a + b) / features.length;
    final variances = features.map((x) => pow(x - mean, 2)).toList();
    final varianceThreshold = variances.reduce((a, b) => a > b ? a : b) * 0.1;

    // 保留方差大于阈值的特征
    final selected = <double>[];
    for (var i = 0; i < features.length; i++) {
      if (variances[i] > varianceThreshold) {
        selected.add(features[i]);
      }
    }

    return selected.isNotEmpty ? selected : features;
  }

  /// 特征标准化（Z-score）
  List<double> _normalizeFeatures(List<double> features) {
    if (features.isEmpty) return features;

    // 计算均值和标准差
    final mean = features.reduce((a, b) => a + b) / features.length;
    final variance = features.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / features.length;
    final std = sqrt(variance);

    if (std < 1e-6) return features; // 避免除以零

    // 标准化
    return features.map((x) => (x - mean) / std).toList();
  }

  /// 获取特征名称列表
  List<String> _getFeatureNames(Map<String, dynamic> features) {
    final names = <String>[];

    void addNames(String prefix, dynamic value) {
      if (value is Map<String, double>) {
        for (final key in value.keys) {
          names.add('${prefix}_$key');
        }
      } else if (value is Map<String, dynamic>) {
        for (final entry in value.entries) {
          addNames('${prefix}_${entry.key}', entry.value);
        }
      }
    }

    for (final entry in features.entries) {
      addNames(entry.key, entry.value);
    }

    return names;
  }

  /// PCA降维 (简化版本)
  List<double> applyPCA(List<double> data, {int numComponents = 10}) {
    // 简化实现：选取等间隔采样点作为主成分
    if (data.length <= numComponents) return List.from(data);

    final step = data.length / numComponents;
    return List.generate(numComponents, (i) => data[(i * step).floor()]);
  }

  /// 转换为模型输入
  Float32List toModelInput(SpectralFeatures features, {int? targetLength}) {
    var vector = features.featureVector;

    // 如果需要固定长度，进行填充或截断
    if (targetLength != null) {
      if (vector.length < targetLength) {
        vector = [...vector, ...List.filled(targetLength - vector.length, 0.0)];
      } else if (vector.length > targetLength) {
        vector = vector.sublist(0, targetLength);
      }
    }

    return Float32List.fromList(vector);
  }
}

/// 特征配置
class FeatureConfig {
  final bool useWaveletFeatures;
  final bool useFrequencyFeatures;
  final int waveletLevels;
  final double peakThreshold;

  FeatureConfig({
    this.useWaveletFeatures = true,
    this.useFrequencyFeatures = true,
    this.waveletLevels = 3,
    this.peakThreshold = 0.1,
  });

  factory FeatureConfig.defaultConfig() {
    return FeatureConfig(
      useWaveletFeatures: true,
      useFrequencyFeatures: true,
      waveletLevels: 3,
      peakThreshold: 0.1,
    );
  }

  factory FeatureConfig.minimal() {
    return FeatureConfig(
      useWaveletFeatures: false,
      useFrequencyFeatures: false,
    );
  }
}

/// 光谱特征
class SpectralFeatures {
  final Map<String, dynamic> rawFeatures;
  final List<double> featureVector;
  final List<String> featureNames;

  SpectralFeatures({
    required this.rawFeatures,
    required this.featureVector,
    required this.featureNames,
  });

  /// 获取特征维度
  int get dimension => featureVector.length;

  /// 获取特定特征值
  double? getFeature(String name) {
    final idx = featureNames.indexOf(name);
    if (idx >= 0 && idx < featureVector.length) {
      return featureVector[idx];
    }
    return null;
  }

  /// 转换为Float32List
  Float32List toFloat32List() {
    return Float32List.fromList(featureVector);
  }

  @override
  String toString() {
    return 'SpectralFeatures(dimension: $dimension, features: ${featureNames.take(5).join(", ")}...)';
  }
}
