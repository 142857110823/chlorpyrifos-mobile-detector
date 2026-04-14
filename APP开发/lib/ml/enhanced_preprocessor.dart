import 'dart:math';
import 'dart:typed_data';

/// 增强版光谱数据预处理器
/// 实现标准化、基线校正、噪声滤波、数据增强等功能
class EnhancedPreprocessor {
  /// 配置参数
  final PreprocessorConfig config;

  EnhancedPreprocessor({PreprocessorConfig? config})
      : config = config ?? PreprocessorConfig.defaultConfig();

  /// 完整预处理流程
  ProcessedSpectralData process(
      List<double> wavelengths, List<double> intensities) {
    if (wavelengths.length != intensities.length) {
      throw ArgumentError('波长和强度数组长度不匹配');
    }

    var data = List<double>.from(intensities);

    // 1. 去除无效值
    data = _removeInvalidValues(data);

    // 2. 基线校正
    data = baselineCorrection(data, method: config.baselineMethod);

    // 3. 噪声滤波
    data = denoiseFilter(data,
        method: config.denoiseMethod, windowSize: config.filterWindowSize);

    // 4. 标准化
    data = normalize(data, method: config.normalizationMethod);

    // 5. 插值到标准波长
    if (config.standardWavelengths != null) {
      final interpolated = interpolateToStandard(
        wavelengths,
        data,
        config.standardWavelengths!,
      );
      return ProcessedSpectralData(
        wavelengths: config.standardWavelengths!,
        intensities: interpolated,
        originalLength: intensities.length,
        processingSteps: ['baseline', 'denoise', 'normalize', 'interpolate'],
      );
    }

    return ProcessedSpectralData(
      wavelengths: wavelengths,
      intensities: data,
      originalLength: intensities.length,
      processingSteps: ['baseline', 'denoise', 'normalize'],
    );
  }

  /// 去除无效值（NaN, Infinity）
  List<double> _removeInvalidValues(List<double> data) {
    return data.map((v) {
      if (v.isNaN || v.isInfinite) return 0.0;
      return v;
    }).toList();
  }

  /// 基线校正
  List<double> baselineCorrection(List<double> data,
      {BaselineMethod method = BaselineMethod.als}) {
    switch (method) {
      case BaselineMethod.als:
        return _alsBaselineCorrection(data);
      case BaselineMethod.polynomial:
        return _polynomialBaselineCorrection(data);
      case BaselineMethod.rubberband:
        return _rubberbandBaselineCorrection(data);
      case BaselineMethod.simple:
        return _simpleBaselineCorrection(data);
    }
  }

  /// 非对称最小二乘基线校正 (Asymmetric Least Squares)
  List<double> _alsBaselineCorrection(List<double> data,
      {double lam = 1e5, double p = 0.001, int maxIter = 10}) {
    final n = data.length;
    var w = List<double>.filled(n, 1.0);
    var z = List<double>.from(data);

    for (var iter = 0; iter < maxIter; iter++) {
      // 简化的ALS实现 - 使用加权移动平均近似
      final baseline = _weightedMovingAverage(data, w,
          windowSize: (n * 0.1).toInt().clamp(5, 50));

      // 更新权重
      for (var i = 0; i < n; i++) {
        final diff = data[i] - baseline[i];
        w[i] = diff < 0 ? p : 1 - p;
      }
      z = baseline;
    }

    // 返回校正后的数据
    return List.generate(n, (i) => data[i] - z[i]);
  }

  /// 加权移动平均
  List<double> _weightedMovingAverage(List<double> data, List<double> weights,
      {int windowSize = 10}) {
    final n = data.length;
    final result = List<double>.filled(n, 0);
    final halfWindow = windowSize ~/ 2;

    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      var weightSum = 0.0;

      for (var j = max(0, i - halfWindow);
          j < min(n, i + halfWindow + 1);
          j++) {
        sum += data[j] * weights[j];
        weightSum += weights[j];
      }

      result[i] = weightSum > 0 ? sum / weightSum : data[i];
    }

    return result;
  }

  /// 多项式基线校正
  List<double> _polynomialBaselineCorrection(List<double> data,
      {int degree = 3}) {
    final n = data.length;

    // 找到局部最小值点
    final minPoints = <int>[];
    for (var i = 1; i < n - 1; i++) {
      if (data[i] < data[i - 1] && data[i] < data[i + 1]) {
        minPoints.add(i);
      }
    }

    if (minPoints.length < degree + 1) {
      return _simpleBaselineCorrection(data);
    }

    // 使用最小值点拟合多项式（简化版本）
    final baseline = _fitPolynomial(data, minPoints, degree);

    return List.generate(n, (i) => data[i] - baseline[i]);
  }

  /// 拟合多项式
  List<double> _fitPolynomial(List<double> data, List<int> points, int degree) {
    final n = data.length;
    final result = List<double>.filled(n, 0);

    // 简化实现：线性插值最小值点
    if (points.isEmpty) return result;

    for (var i = 0; i < n; i++) {
      // 找到最近的两个控制点
      var left = 0;
      var right = points.length - 1;

      for (var j = 0; j < points.length; j++) {
        if (points[j] <= i) left = j;
        if (points[j] >= i) {
          right = j;
          break;
        }
      }

      if (left == right) {
        result[i] = data[points[left]];
      } else {
        // 线性插值
        final t = (i - points[left]) / (points[right] - points[left]);
        result[i] = data[points[left]] * (1 - t) + data[points[right]] * t;
      }
    }

    return result;
  }

  /// 橡皮筋基线校正
  List<double> _rubberbandBaselineCorrection(List<double> data) {
    final n = data.length;
    final baseline = List<double>.from(data);

    // 凸包算法简化版本
    for (var iter = 0; iter < 3; iter++) {
      for (var i = 1; i < n - 1; i++) {
        final avg = (baseline[i - 1] + baseline[i + 1]) / 2;
        if (baseline[i] > avg) {
          baseline[i] = avg;
        }
      }
    }

    return List.generate(n, (i) => data[i] - baseline[i]);
  }

  /// 简单基线校正（减去最小值）
  List<double> _simpleBaselineCorrection(List<double> data) {
    final minVal = data.reduce(min);
    return data.map((v) => v - minVal).toList();
  }

  /// 噪声滤波
  List<double> denoiseFilter(List<double> data,
      {DenoiseMethod method = DenoiseMethod.savitzkyGolay,
      int windowSize = 5}) {
    switch (method) {
      case DenoiseMethod.movingAverage:
        return _movingAverageFilter(data, windowSize);
      case DenoiseMethod.gaussian:
        return _gaussianFilter(data, windowSize);
      case DenoiseMethod.median:
        return _medianFilter(data, windowSize);
      case DenoiseMethod.savitzkyGolay:
        return _savitzkyGolayFilter(data, windowSize);
    }
  }

  /// 移动平均滤波
  List<double> _movingAverageFilter(List<double> data, int windowSize) {
    final n = data.length;
    final result = List<double>.filled(n, 0);
    final halfWindow = windowSize ~/ 2;

    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      var count = 0;

      for (var j = max(0, i - halfWindow);
          j < min(n, i + halfWindow + 1);
          j++) {
        sum += data[j];
        count++;
      }

      result[i] = sum / count;
    }

    return result;
  }

  /// 高斯滤波
  List<double> _gaussianFilter(List<double> data, int windowSize) {
    final n = data.length;
    final result = List<double>.filled(n, 0);
    final halfWindow = windowSize ~/ 2;
    final sigma = windowSize / 6.0;

    // 生成高斯核
    final kernel = List<double>.generate(windowSize, (i) {
      final x = i - halfWindow;
      return exp(-x * x / (2 * sigma * sigma));
    });

    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      var weightSum = 0.0;

      for (var k = 0; k < windowSize; k++) {
        final j = i - halfWindow + k;
        if (j >= 0 && j < n) {
          sum += data[j] * kernel[k];
          weightSum += kernel[k];
        }
      }

      result[i] = sum / weightSum;
    }

    return result;
  }

  /// 中值滤波
  List<double> _medianFilter(List<double> data, int windowSize) {
    final n = data.length;
    final result = List<double>.filled(n, 0);
    final halfWindow = windowSize ~/ 2;

    for (var i = 0; i < n; i++) {
      final window = <double>[];

      for (var j = max(0, i - halfWindow);
          j < min(n, i + halfWindow + 1);
          j++) {
        window.add(data[j]);
      }

      window.sort();
      result[i] = window[window.length ~/ 2];
    }

    return result;
  }

  /// Savitzky-Golay滤波
  List<double> _savitzkyGolayFilter(List<double> data, int windowSize,
      {int polyOrder = 2}) {
    final n = data.length;
    if (windowSize > n) return List.from(data);

    // 简化的SG滤波：使用预计算的5点2阶系数
    const coeffs = [-3.0, 12.0, 17.0, 12.0, -3.0];
    const normFactor = 35.0;

    final result = List<double>.filled(n, 0);
    final halfWindow = 2;

    for (var i = 0; i < n; i++) {
      if (i < halfWindow || i >= n - halfWindow) {
        result[i] = data[i];
      } else {
        var sum = 0.0;
        for (var j = 0; j < 5; j++) {
          sum += coeffs[j] * data[i - halfWindow + j];
        }
        result[i] = sum / normFactor;
      }
    }

    return result;
  }

  /// 标准化
  List<double> normalize(List<double> data,
      {NormalizationMethod method = NormalizationMethod.minMax}) {
    switch (method) {
      case NormalizationMethod.minMax:
        return _minMaxNormalize(data);
      case NormalizationMethod.zScore:
        return _zScoreNormalize(data);
      case NormalizationMethod.l1:
        return _l1Normalize(data);
      case NormalizationMethod.l2:
        return _l2Normalize(data);
      case NormalizationMethod.snv:
        return _snvNormalize(data);
    }
  }

  /// Min-Max标准化
  List<double> _minMaxNormalize(List<double> data) {
    final minVal = data.reduce(min);
    final maxVal = data.reduce(max);
    final range = maxVal - minVal;

    if (range == 0) return List.filled(data.length, 0);

    return data.map((v) => (v - minVal) / range).toList();
  }

  /// Z-Score标准化
  List<double> _zScoreNormalize(List<double> data) {
    final mean = data.reduce((a, b) => a + b) / data.length;
    final variance =
        data.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / data.length;
    final std = sqrt(variance);

    if (std == 0) return List.filled(data.length, 0);

    return data.map((v) => (v - mean) / std).toList();
  }

  /// L1标准化
  List<double> _l1Normalize(List<double> data) {
    final sum = data.map((v) => v.abs()).reduce((a, b) => a + b);
    if (sum == 0) return List.filled(data.length, 0);
    return data.map((v) => v / sum).toList();
  }

  /// L2标准化
  List<double> _l2Normalize(List<double> data) {
    final sumSquares = data.map((v) => v * v).reduce((a, b) => a + b);
    final norm = sqrt(sumSquares);
    if (norm == 0) return List.filled(data.length, 0);
    return data.map((v) => v / norm).toList();
  }

  /// SNV标准化 (Standard Normal Variate)
  List<double> _snvNormalize(List<double> data) {
    return _zScoreNormalize(data);
  }

  /// 插值到标准波长
  List<double> interpolateToStandard(
    List<double> wavelengths,
    List<double> intensities,
    List<double> targetWavelengths,
  ) {
    final result = <double>[];

    for (final targetWl in targetWavelengths) {
      // 找到最近的两个点
      var leftIdx = 0;
      var rightIdx = wavelengths.length - 1;

      for (var i = 0; i < wavelengths.length - 1; i++) {
        if (wavelengths[i] <= targetWl && wavelengths[i + 1] >= targetWl) {
          leftIdx = i;
          rightIdx = i + 1;
          break;
        }
      }

      // 边界处理
      if (targetWl <= wavelengths.first) {
        result.add(intensities.first);
      } else if (targetWl >= wavelengths.last) {
        result.add(intensities.last);
      } else {
        // 线性插值
        final t = (targetWl - wavelengths[leftIdx]) /
            (wavelengths[rightIdx] - wavelengths[leftIdx]);
        result.add(intensities[leftIdx] * (1 - t) + intensities[rightIdx] * t);
      }
    }

    return result;
  }

  /// 计算一阶导数
  List<double> firstDerivative(List<double> data) {
    final n = data.length;
    if (n < 2) return [];

    final result = <double>[];
    for (var i = 0; i < n - 1; i++) {
      result.add(data[i + 1] - data[i]);
    }
    result.add(result.last); // 补齐最后一个点

    return result;
  }

  /// 计算二阶导数
  List<double> secondDerivative(List<double> data) {
    final first = firstDerivative(data);
    return firstDerivative(first);
  }

  /// 转换为Float32List (用于TFLite输入)
  Float32List toFloat32List(List<double> data) {
    return Float32List.fromList(data.map((e) => e.toDouble()).toList());
  }
}

/// 预处理配置
class PreprocessorConfig {
  final BaselineMethod baselineMethod;
  final DenoiseMethod denoiseMethod;
  final NormalizationMethod normalizationMethod;
  final int filterWindowSize;
  final List<double>? standardWavelengths;

  PreprocessorConfig({
    this.baselineMethod = BaselineMethod.als,
    this.denoiseMethod = DenoiseMethod.savitzkyGolay,
    this.normalizationMethod = NormalizationMethod.minMax,
    this.filterWindowSize = 5,
    this.standardWavelengths,
  });

  factory PreprocessorConfig.defaultConfig() {
    return PreprocessorConfig(
      baselineMethod: BaselineMethod.als,
      denoiseMethod: DenoiseMethod.savitzkyGolay,
      normalizationMethod: NormalizationMethod.minMax,
      filterWindowSize: 5,
      standardWavelengths: _generateStandardWavelengths(200, 800, 256),
    );
  }

  static List<double> _generateStandardWavelengths(
      double start, double end, int count) {
    final step = (end - start) / (count - 1);
    return List.generate(count, (i) => start + i * step);
  }
}

/// 处理后的光谱数据
class ProcessedSpectralData {
  final List<double> wavelengths;
  final List<double> intensities;
  final int originalLength;
  final List<String> processingSteps;

  ProcessedSpectralData({
    required this.wavelengths,
    required this.intensities,
    required this.originalLength,
    required this.processingSteps,
  });

  /// 转换为模型输入格式
  Float32List toModelInput() {
    return Float32List.fromList(intensities);
  }

  /// 获取数据长度
  int get length => intensities.length;
}

/// 基线校正方法
enum BaselineMethod {
  als, // 非对称最小二乘
  polynomial, // 多项式拟合
  rubberband, // 橡皮筋算法
  simple, // 简单减最小值
}

/// 去噪方法
enum DenoiseMethod {
  movingAverage, // 移动平均
  gaussian, // 高斯滤波
  median, // 中值滤波
  savitzkyGolay, // Savitzky-Golay滤波
}

/// 标准化方法
enum NormalizationMethod {
  minMax, // Min-Max标准化
  zScore, // Z-Score标准化
  l1, // L1归一化
  l2, // L2归一化
  snv, // 标准正态变量变换
}
