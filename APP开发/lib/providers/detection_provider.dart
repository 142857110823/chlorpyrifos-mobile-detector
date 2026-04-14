import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/spectral_analysis_service.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';

/// 检测状态管理
class DetectionProvider extends ChangeNotifier {
  final SpectralAnalysisService _analysisService = SpectralAnalysisService();
  final StorageService _storageService = StorageService();
  final LoggingService _logger = LoggingService();

  // 检测状态
  DetectionStatus _status = DetectionStatus.idle;
  DetectionResult? _currentResult;
  String? _errorMessage;
  double _progress = 0.0;
  bool _isProcessing = false;
  String? _currentSampleName;
  String? _currentSampleCategory;
  String? _currentImagePath;

  // 历史记录（内存缓存）
  final List<DetectionResult> _recentResults = [];

  /// 获取当前状态
  DetectionStatus get status => _status;

  /// 获取当前结果
  DetectionResult? get currentResult => _currentResult;

  /// 获取错误信息
  String? get errorMessage => _errorMessage;

  /// 获取处理进度
  double get progress => _progress;

  /// 是否正在处理
  bool get isProcessing => _isProcessing;

  /// 获取最近的检测结果
  List<DetectionResult> get recentResults => _recentResults;

  /// 获取当前样品名称
  String? get currentSampleName => _currentSampleName;

  /// 获取当前样品类别
  String? get currentSampleCategory => _currentSampleCategory;

  /// 初始化
  Future<void> initialize() async {
    await _analysisService.initialize();
    await _loadRecentResults();
  }

  /// 加载最近的检测结果
  Future<void> _loadRecentResults() async {
    try {
      final results = await _storageService.getAllDetectionResults();
      _recentResults.clear();
      _recentResults.addAll(results.take(10));
      notifyListeners();
    } catch (e) {
      _logger.error('加载历史记录失败: $e', tag: 'DetectionProvider');
    }
  }

  /// 设置样品信息
  void setSampleInfo({
    required String sampleName,
    String? sampleCategory,
    String? imagePath,
  }) {
    _currentSampleName = sampleName;
    _currentSampleCategory = sampleCategory;
    _currentImagePath = imagePath;
    notifyListeners();
  }

  /// 开始检测
  Future<DetectionResult?> startDetection() async {
    if (_currentImagePath == null || _currentSampleName == null) {
      _setError('请先选择图片并输入样品名称');
      return null;
    }

    _setStatus(DetectionStatus.processing);
    _setError(null);
    _setProgress(0.0);
    _isProcessing = true;
    _currentResult = null;

    try {
      _logger.info('开始检测: $_currentSampleName', tag: 'DetectionProvider');

      // 1. 初始化分析服务
      await _analysisService.initialize();
      _setProgress(0.2);

      // 2. 执行光谱分析
      _setProgress(0.5);
      final result = await _analysisService.analyzeSpectralImage(
        imagePath: _currentImagePath!,
        sampleName: _currentSampleName!,
        sampleCategory: _currentSampleCategory,
      );
      _setProgress(0.8);

      // 3. 保存结果到本地存储
      await _storageService.saveDetectionResult(result);
      _setProgress(0.9);

      // 4. 更新状态
      _currentResult = result;
      _addRecentResult(result);

      _logger.info('检测完成: ${result.riskLevelDescription}', tag: 'DetectionProvider');
      _setStatus(DetectionStatus.completed);
      _setProgress(1.0);

      return result;
    } catch (e, stackTrace) {
      _logger.error('检测失败: $e', stackTrace: stackTrace, tag: 'DetectionProvider');
      _setStatus(DetectionStatus.error);
      _setError('检测失败: ${e.toString()}');
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 从光谱数据开始检测（用于蓝牙设备）
  Future<DetectionResult> startDetectionFromSpectralData({
    required SpectralData spectralData,
    required String sampleName,
    String? sampleCategory,
  }) async {
    _setStatus(DetectionStatus.processing);
    _setError(null);
    _setProgress(0.0);
    _isProcessing = true;

    try {
      _logger.info('开始光谱检测: $sampleName', tag: 'DetectionProvider');

      // 初始化分析服务
      await _analysisService.initialize();
      _setProgress(0.3);

      // 分析光谱数据
      _setProgress(0.6);

      // 创建检测结果（基于光谱数据分析）
      final detectedPesticides = <DetectedPesticide>[];

      // 分析光谱特征
      final meanValue = spectralData.intensityValues.reduce((a, b) => a + b) / spectralData.intensityValues.length;
      final maxValue = spectralData.intensityValues.reduce((a, b) => a > b ? a : b);
      final stdDev = _calculateStandardDeviation(spectralData.intensityValues, meanValue);

      // 基于光谱特征判断是否有农药残留
      if (maxValue > meanValue + 2 * stdDev) {
        // 检测到异常峰值，可能存在农药残留
        final concentration = ((maxValue - meanValue) / 100).clamp(0.0, 1.0);
        
        // 基于峰值位置和强度识别具体农药
        final peaks = _detectPeaks(spectralData.intensityValues);
        final detectedPesticide = _identifyPesticideBySpectralFeatures(peaks, spectralData.intensityValues);
        
        if (detectedPesticide != null) {
          detectedPesticides.add(DetectedPesticide(
            name: detectedPesticide.name,
            type: detectedPesticide.type,
            concentration: detectedPesticide.concentration,
            maxResidueLimit: detectedPesticide.maxResidueLimit,
            unit: detectedPesticide.unit,
          ));
        }
      }

      _setProgress(0.8);

      // 确定风险等级
      final riskLevel = _determineRiskLevel(detectedPesticides);

      // 创建结果
      final result = DetectionResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        sampleName: sampleName,
        sampleCategory: sampleCategory ?? '未分类',
        riskLevel: riskLevel,
        confidence: detectedPesticides.isEmpty ? 0.0 : 0.75,
        detectedPesticides: detectedPesticides,
        spectralDataId: spectralData.id,
        isSynced: false,
      );

      // 保存结果
      await _storageService.saveDetectionResult(result);

      _currentResult = result;
      _addRecentResult(result);

      _logger.info('光谱检测完成: ${result.riskLevelDescription}', tag: 'DetectionProvider');
      _setStatus(DetectionStatus.completed);
      _setProgress(1.0);

      return result;
    } catch (e, stackTrace) {
      _logger.error('光谱检测失败: $e', stackTrace: stackTrace, tag: 'DetectionProvider');
      _setStatus(DetectionStatus.error);
      _setError('检测失败: ${e.toString()}');

      // 返回错误结果
      return DetectionResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        sampleName: sampleName,
        sampleCategory: sampleCategory ?? '未分类',
        riskLevel: RiskLevel.safe,
        confidence: 0.0,
        detectedPesticides: [],
      );
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 批量检测
  Future<List<DetectionResult>> batchDetection({
    required List<Map<String, dynamic>> samples,
    required Function(double) onProgress,
  }) async {
    final results = <DetectionResult>[];

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final progress = (i + 1) / samples.length;

      try {
        final spectralData = sample['spectralData'] as SpectralData?;
        final imagePath = sample['imagePath'] as String?;
        final sampleName = sample['name'] as String;
        final sampleCategory = sample['category'] as String?;

        DetectionResult? result;

        if (imagePath != null) {
          // 从图片检测
          setSampleInfo(
            sampleName: sampleName,
            sampleCategory: sampleCategory,
            imagePath: imagePath,
          );
          result = await startDetection();
        } else if (spectralData != null) {
          // 从光谱数据检测
          result = await startDetectionFromSpectralData(
            spectralData: spectralData,
            sampleName: sampleName,
            sampleCategory: sampleCategory,
          );
        }

        if (result != null) {
          results.add(result);
        }
      } catch (e) {
        _logger.error('批量检测失败: $e', tag: 'DetectionProvider');
      }

      onProgress(progress);
    }

    return results;
  }

  /// 取消检测
  void cancelDetection() {
    _setStatus(DetectionStatus.cancelled);
    _setProgress(0.0);
    _isProcessing = false;
    _logger.info('检测已取消', tag: 'DetectionProvider');
  }

  /// 重置状态
  void reset() {
    _status = DetectionStatus.idle;
    _currentResult = null;
    _errorMessage = null;
    _progress = 0.0;
    _isProcessing = false;
    _currentSampleName = null;
    _currentSampleCategory = null;
    _currentImagePath = null;
    notifyListeners();
  }

  /// 清理历史结果
  void clearRecentResults() {
    _recentResults.clear();
    notifyListeners();
  }

  /// 获取模型状态
  Future<ModelStatus> getModelStatus() async {
    await _analysisService.initialize();
    return ModelStatus(
      loaded: _analysisService.isModelLoaded,
      version: _analysisService.isModelLoaded ? '1.0.0' : 'algorithm-mode',
      error: _analysisService.isModelLoaded ? null : '使用算法分析模式',
    );
  }

  /// 确定风险等级
  RiskLevel _determineRiskLevel(List<DetectedPesticide> pesticides) {
    if (pesticides.isEmpty) {
      return RiskLevel.safe;
    }

    double maxRatio = 0.0;
    for (final pesticide in pesticides) {
      if (pesticide.maxResidueLimit > 0) {
        final ratio = pesticide.concentration / pesticide.maxResidueLimit;
        if (ratio > maxRatio) {
          maxRatio = ratio;
        }
      }
    }

    if (maxRatio < 0.1) return RiskLevel.safe;
    if (maxRatio < 0.5) return RiskLevel.low;
    if (maxRatio < 1.0) return RiskLevel.medium;
    if (maxRatio < 2.0) return RiskLevel.high;
    return RiskLevel.critical;
  }

  /// 添加最近的检测结果
  void _addRecentResult(DetectionResult result) {
    _recentResults.insert(0, result);
    // 只保留最近10个结果
    if (_recentResults.length > 10) {
      _recentResults.removeLast();
    }
    notifyListeners();
  }

  /// 设置状态
  void _setStatus(DetectionStatus status) {
    _status = status;
    notifyListeners();
  }

  /// 设置错误信息
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// 设置进度
  void _setProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  /// 计算标准差
  double _calculateStandardDeviation(List<double> values, double mean) {
    double sumSquaredDiff = 0.0;
    for (final value in values) {
      final diff = value - mean;
      sumSquaredDiff += diff * diff;
    }
    return sqrt(sumSquaredDiff / values.length);
  }
  
  /// 检测光谱峰值
  List<Map<String, dynamic>> _detectPeaks(List<double> data) {
    final peaks = <Map<String, dynamic>>[];
    const windowSize = 5;

    for (int i = windowSize; i < data.length - windowSize; i++) {
      final window = data.sublist(i - windowSize, i + windowSize + 1);
      final centerValue = data[i];

      // 检查是否为局部最大值
      bool isPeak = true;
      for (int j = 0; j < window.length; j++) {
        if (j != windowSize && window[j] >= centerValue) {
          isPeak = false;
          break;
        }
      }

      // 峰值阈值
      if (isPeak && centerValue > 0.3) {
        peaks.add({
          'index': i,
          'intensity': centerValue,
          'wavelength': _indexToWavelength(i, data.length),
        });
      }
    }

    return peaks;
  }

  /// 将索引转换为波长
  double _indexToWavelength(int index, int totalLength) {
    // 假设光谱范围是230-370nm（适合吸收光谱分析）
    const startWavelength = 230.0;
    const endWavelength = 370.0;
    return startWavelength + (index / totalLength) * (endWavelength - startWavelength);
  }

  /// 基于光谱特征识别农药
  DetectedPesticide? _identifyPesticideBySpectralFeatures(List<Map<String, dynamic>> peaks, List<double> spectralData) {
    // 定义用户光谱文件夹中的四种农药的光谱特征（波长范围、吸收峰特征）
    final pesticideSpectralFeatures = {
      '吡虫啉 (Imidacloprid)': {
        'type': PesticideType.neonicotinoid,
        'mrl': 0.5,
        'peaks': [
          {'wavelengthRange': [240, 280], 'minIntensity': 0.6},
          {'wavelengthRange': [310, 350], 'minIntensity': 0.4}
        ]
      },
      '扑虱灵 (Buprofezin)': {
        'type': PesticideType.other,
        'mrl': 0.1,
        'peaks': [
          {'wavelengthRange': [250, 290], 'minIntensity': 0.55},
          {'wavelengthRange': [320, 360], 'minIntensity': 0.35}
        ]
      },
      '种衣剂 (Seed Coating)': {
        'type': PesticideType.other,
        'mrl': 0.2,
        'peaks': [
          {'wavelengthRange': [230, 270], 'minIntensity': 0.7},
          {'wavelengthRange': [330, 370], 'minIntensity': 0.5}
        ]
      },
      '苄·二氣 (Benzyl Dioxide)': {
        'type': PesticideType.other,
        'mrl': 0.15,
        'peaks': [
          {'wavelengthRange': [245, 285], 'minIntensity': 0.5},
          {'wavelengthRange': [315, 355], 'minIntensity': 0.4}
        ]
      }
    };

    // 计算峰值特征
    final peakIntensities = peaks.map((p) => p['intensity'] as double).toList();
    final peakWavelengths = peaks.map((p) => p['wavelength'] as double).toList();
    if (peakIntensities.isEmpty || peakWavelengths.isEmpty) {
      return null;
    }

    final totalPeakIntensity = peakIntensities.reduce((a, b) => a + b);
    final averagePeakIntensity = totalPeakIntensity / peaks.length;

    // 匹配农药光谱特征
    double maxMatchScore = 0.0;
    Map<String, dynamic>? bestMatch;
    String? bestMatchName;

    for (final entry in pesticideSpectralFeatures.entries) {
      final pesticideName = entry.key;
      final features = entry.value;
      final requiredPeaks = features['peaks'] as List<Map<String, dynamic>>;
      
      int matchedPeaks = 0;
      double intensityScore = 0.0;

      for (final requiredPeak in requiredPeaks) {
        final wavelengthRange = requiredPeak['wavelengthRange'] as List<int>;
        final minIntensity = requiredPeak['minIntensity'] as double;
        
        // 检查是否有峰值在指定波长范围内且强度足够
        for (int i = 0; i < peakWavelengths.length; i++) {
          final wavelength = peakWavelengths[i];
          final intensity = peakIntensities[i];
          
          if (wavelength >= wavelengthRange[0] && wavelength <= wavelengthRange[1] && intensity >= minIntensity) {
            matchedPeaks++;
            intensityScore += intensity;
            break;
          }
        }
      }

      // 计算匹配分数
      final matchScore = (matchedPeaks / requiredPeaks.length) * (1.0 + intensityScore / requiredPeaks.length);
      
      if (matchScore > maxMatchScore && matchedPeaks >= 1) {
        maxMatchScore = matchScore;
        bestMatch = features;
        bestMatchName = pesticideName;
      }
    }

    // 如果找到匹配的农药且置信度足够高
    if (bestMatch != null && bestMatchName != null && maxMatchScore > 0.5) {
      // 基于峰值强度和匹配分数估算浓度
      final concentration = (averagePeakIntensity * 0.3 + maxMatchScore * 0.7).clamp(0.0, 1.0);
      
      return DetectedPesticide(
        name: bestMatchName,
        type: bestMatch['type'] as PesticideType,
        concentration: concentration,
        maxResidueLimit: bestMatch['mrl'] as double,
        unit: 'mg/kg',
      );
    }

    return null;
  }
}

/// 检测状态枚举
enum DetectionStatus {
  idle, // 空闲
  processing, // 处理中
  completed, // 完成
  error, // 错误
  cancelled, // 已取消
}

/// 模型状态
class ModelStatus {
  final bool loaded;
  final String version;
  final String? error;

  ModelStatus({
    required this.loaded,
    required this.version,
    this.error,
  });

  /// 是否可用
  bool get isAvailable => loaded || error == '使用算法分析模式';

  @override
  String toString() {
    return 'ModelStatus(loaded: $loaded, version: $version, error: $error)';
  }
}
