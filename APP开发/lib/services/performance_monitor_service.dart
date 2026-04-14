import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 性能指标类型
enum PerformanceMetric {
  frameTime,
  memoryUsage,
  batteryLevel,
  startupTime,
  apiResponseTime,
  renderingTime,
}

/// 性能数据类
class PerformanceData {
  final PerformanceMetric metric;
  final double value;
  final DateTime timestamp;
  final String? context;

  PerformanceData({
    required this.metric,
    required this.value,
    this.context,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return '[${metric.name}] $value at $timestamp${context != null ? ' ($context)' : ''}';
  }
}

/// 性能监控服务
class PerformanceMonitorService {
  static final PerformanceMonitorService _instance =
      PerformanceMonitorService._internal();
  factory PerformanceMonitorService() => _instance;
  PerformanceMonitorService._internal();

  final _performanceDataController =
      StreamController<PerformanceData>.broadcast();
  final _performanceHistory = <PerformanceData>[];
  final _maxHistorySize = 100;

  Stream<PerformanceData> get performanceDataStream =>
      _performanceDataController.stream;
  List<PerformanceData> get performanceHistory =>
      List.unmodifiable(_performanceHistory);

  // 启动时间
  DateTime? _appStartTime;
  int _startupTime = 0;

  // 帧时间监控
  int _frameCount = 0;
  DateTime? _lastFrameTime;

  // 内存监控
  Timer? _memoryMonitorTimer;

  /// 初始化性能监控服务
  void initialize() {
    _appStartTime = DateTime.now();

    // 监控应用启动时间
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupTime = DateTime.now().difference(_appStartTime!).inMilliseconds;
      _recordMetric(
        PerformanceMetric.startupTime,
        _startupTime.toDouble(),
        'App startup',
      );
      print('App startup time: $_startupTime ms');
    });

    // 监控渲染性能
    _startFrameTimeMonitoring();

    // 监控内存使用
    _startMemoryMonitoring();

    print('PerformanceMonitorService initialized');
  }

  /// 开始帧时间监控
  void _startFrameTimeMonitoring() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCount++;
      final now = DateTime.now();

      if (_lastFrameTime != null) {
        final frameTime = now.difference(_lastFrameTime!).inMilliseconds;
        _recordMetric(
          PerformanceMetric.frameTime,
          frameTime.toDouble(),
          'Frame ${_frameCount}',
        );

        // 每100帧打印一次平均帧率
        if (_frameCount % 100 == 0) {
          final avgFrameTime = _calculateAverageFrameTime();
          final fps = 1000 / avgFrameTime;
          print(
              'Average frame time: ${avgFrameTime.toStringAsFixed(1)} ms ($fps fps)');
        }
      }

      _lastFrameTime = now;
      _startFrameTimeMonitoring();
    });
  }

  /// 开始内存监控
  void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _monitorMemoryUsage();
    });
  }

  /// 监控内存使用
  void _monitorMemoryUsage() {
    // 使用developer工具获取内存信息
    Timeline.startSync('Memory Monitoring');
    try {
      // 这里可以使用更具体的内存监控方法
      // 例如使用flutter_memory_monitor或类似库
      final memoryUsage = _estimateMemoryUsage();
      _recordMetric(
        PerformanceMetric.memoryUsage,
        memoryUsage,
        'Memory snapshot',
      );
      print('Memory usage: ${memoryUsage.toStringAsFixed(2)} MB');
    } catch (e) {
      print('Memory monitoring error: $e');
    } finally {
      Timeline.finishSync();
    }
  }

  /// 估算内存使用（模拟）
  double _estimateMemoryUsage() {
    // 实际应用中应该使用平台特定的API获取内存信息
    // 这里只是模拟一个值
    return 50.0 + DateTime.now().millisecond % 20;
  }

  /// 记录性能指标
  void recordMetric(PerformanceMetric metric, double value, [String? context]) {
    _recordMetric(metric, value, context);
  }

  /// 内部记录性能指标
  void _recordMetric(PerformanceMetric metric, double value,
      [String? context]) {
    final data = PerformanceData(
      metric: metric,
      value: value,
      context: context,
    );

    _performanceHistory.add(data);
    if (_performanceHistory.length > _maxHistorySize) {
      _performanceHistory.removeAt(0);
    }

    _performanceDataController.add(data);
  }

  /// 计算平均帧时间
  double _calculateAverageFrameTime() {
    final frameTimeData = _performanceHistory
        .where((data) => data.metric == PerformanceMetric.frameTime)
        .take(100)
        .toList();

    if (frameTimeData.isEmpty) return 0;

    final sum = frameTimeData.map((data) => data.value).reduce((a, b) => a + b);
    return sum / frameTimeData.length;
  }

  /// 监控API响应时间
  Future<T> monitorApiCall<T>(
    Future<T> Function() apiCall,
    String endpoint,
  ) async {
    final startTime = DateTime.now();
    try {
      final result = await apiCall();
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      _recordMetric(
        PerformanceMetric.apiResponseTime,
        responseTime.toDouble(),
        endpoint,
      );
      print('API call to $endpoint took $responseTime ms');
      return result;
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      _recordMetric(
        PerformanceMetric.apiResponseTime,
        responseTime.toDouble(),
        '$endpoint (error)',
      );
      print('API call to $endpoint failed after $responseTime ms: $e');
      rethrow;
    }
  }

  /// 获取性能统计
  Map<PerformanceMetric, double> getPerformanceStats() {
    final stats = <PerformanceMetric, double>{};

    for (final metric in PerformanceMetric.values) {
      final metricData =
          _performanceHistory.where((data) => data.metric == metric).toList();

      if (metricData.isNotEmpty) {
        final sum =
            metricData.map((data) => data.value).reduce((a, b) => a + b);
        stats[metric] = sum / metricData.length;
      }
    }

    return stats;
  }

  /// 清除性能历史
  void clearHistory() {
    _performanceHistory.clear();
  }

  /// 释放资源
  void dispose() {
    _performanceDataController.close();
    _memoryMonitorTimer?.cancel();
  }
}

/// 性能优化工具类
class PerformanceOptimizer {
  /// 防抖函数
  static Function() debounce(
    Function() func,
    Duration duration,
  ) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(duration, func);
    };
  }

  /// 节流函数
  static Function() throttle(
    Function() func,
    Duration duration,
  ) {
    bool isRunning = false;
    return () {
      if (!isRunning) {
        isRunning = true;
        func();
        Timer(duration, () => isRunning = false);
      }
    };
  }

  /// 计算函数执行时间
  static Future<T> measureExecutionTime<T>(
    Future<T> Function() func,
    String? label,
  ) async {
    final startTime = DateTime.now();
    final result = await func();
    final executionTime = DateTime.now().difference(startTime).inMilliseconds;
    print('$label execution time: $executionTime ms');
    return result;
  }

  /// 缓存计算结果
  static Map<dynamic, dynamic> _cache = {};
  static T cached<T>(
    dynamic key,
    T Function() compute,
  ) {
    if (!_cache.containsKey(key)) {
      _cache[key] = compute();
    }
    return _cache[key] as T;
  }

  /// 清除缓存
  static void clearCache() {
    _cache.clear();
  }
}
