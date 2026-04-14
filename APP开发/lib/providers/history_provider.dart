import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';

/// 筛选条件类
class FilterCriteria {
  final RiskLevel? riskLevel;
  final DateTimeRange? dateRange;
  final String? searchQuery;

  const FilterCriteria({
    this.riskLevel,
    this.dateRange,
    this.searchQuery,
  });

  FilterCriteria copyWith({
    RiskLevel? riskLevel,
    DateTimeRange? dateRange,
    String? searchQuery,
    bool clearRiskLevel = false,
    bool clearDateRange = false,
    bool clearSearchQuery = false,
  }) {
    return FilterCriteria(
      riskLevel: clearRiskLevel ? null : (riskLevel ?? this.riskLevel),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCriteria &&
        other.riskLevel == riskLevel &&
        other.dateRange?.start == dateRange?.start &&
        other.dateRange?.end == dateRange?.end &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(
        riskLevel,
        dateRange?.start,
        dateRange?.end,
        searchQuery,
      );

  bool get isEmpty =>
      riskLevel == null &&
      dateRange == null &&
      (searchQuery == null || searchQuery!.isEmpty);
}

/// 历史记录管理
class HistoryProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final LoggingService _logger = LoggingService();

  // P0修复: 分页相关变量
  static const int pageSize = 20;
  final List<DetectionResult> _history = [];
  int _totalCount = 0;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // P0修复: 筛选缓存
  FilterCriteria _currentFilter = const FilterCriteria();
  List<DetectionResult>? _filteredCache;
  FilterCriteria? _cachedFilterCriteria;

  // P1修复: 统计缓存
  HistoryStatistics? _cachedStatistics;
  int _statisticsCacheCount = -1;

  /// 获取历史记录（当前已加载的）
  List<DetectionResult> get history => _history;

  /// 获取筛选后的历史记录
  List<DetectionResult> get filteredHistory {
    if (_currentFilter.isEmpty) {
      return _history;
    }
    return _getFilteredResults();
  }

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 是否正在加载更多
  bool get isLoadingMore => _isLoadingMore;

  /// 是否有更多数据
  bool get hasMore => _hasMore;

  /// 获取错误信息
  String? get errorMessage => _errorMessage;

  /// 获取当前筛选条件
  FilterCriteria get currentFilter => _currentFilter;

  /// 获取总数
  int get totalCount => _totalCount;

  /// 获取已加载数量
  int get loadedCount => _history.length;

  /// 初始化
  Future<void> initialize() async {
    if (_history.isNotEmpty || _isLoading) return;
    await loadHistory();
  }

  /// P0修复: 加载历史记录（首页）
  Future<void> loadHistory() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    _currentPage = 0;
    _hasMore = true;

    notifyListeners();

    try {
      _logger.info('加载历史记录（分页）', tag: 'HistoryProvider');

      // 获取总数
      _totalCount = await _storageService.getDetectionResultsCount();

      // 加载首页数据
      final results = await _storageService.getDetectionResultsPaged(
        offset: 0,
        limit: pageSize,
      );

      _history.clear();
      _history.addAll(results);
      _currentPage = 1;
      _hasMore = _history.length < _totalCount;

      // 清除缓存
      _clearCaches();

      _logger.info(
        '历史记录加载完成: ${_history.length}/$_totalCount 条',
        tag: 'HistoryProvider',
      );
    } catch (e, stackTrace) {
      _logger.error(
        '加载历史记录失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '加载历史记录失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// P0修复: 加载更多历史记录
  Future<void> loadMoreHistory() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _logger.info('加载更多历史记录: 第${_currentPage + 1}页', tag: 'HistoryProvider');

      final offset = _currentPage * pageSize;
      final results = await _storageService.getDetectionResultsPaged(
        offset: offset,
        limit: pageSize,
      );

      if (results.isNotEmpty) {
        _history.addAll(results);
        _currentPage++;
        _hasMore = _history.length < _totalCount;
        _clearCaches();
      } else {
        _hasMore = false;
      }

      _logger.info(
        '加载更多完成: ${_history.length}/$_totalCount 条',
        tag: 'HistoryProvider',
      );
    } catch (e, stackTrace) {
      _logger.error(
        '加载更多失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '加载更多失败';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 刷新历史记录
  Future<void> refreshHistory() async {
    _currentPage = 0;
    _hasMore = true;
    await loadHistory();
  }

  /// 设置筛选条件
  void setFilter(FilterCriteria filter) {
    if (_currentFilter == filter) return;

    _currentFilter = filter;
    _filteredCache = null; // 清除筛选缓存
    notifyListeners();
  }

  /// 清除筛选条件
  void clearFilter() {
    _currentFilter = const FilterCriteria();
    _filteredCache = null;
    notifyListeners();
  }

  /// P0修复: 获取筛选后的结果（带缓存）
  List<DetectionResult> _getFilteredResults() {
    // 检查缓存
    if (_filteredCache != null && _cachedFilterCriteria == _currentFilter) {
      return _filteredCache!;
    }

    // 执行筛选
    var results = _history.where((r) {
      // 风险等级筛选
      if (_currentFilter.riskLevel != null &&
          r.riskLevel != _currentFilter.riskLevel) {
        return false;
      }

      // 日期范围筛选
      if (_currentFilter.dateRange != null) {
        final range = _currentFilter.dateRange!;
        if (!r.timestamp.isAfter(range.start) ||
            !r.timestamp.isBefore(range.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // 搜索筛选
      if (_currentFilter.searchQuery != null &&
          _currentFilter.searchQuery!.isNotEmpty) {
        final query = _currentFilter.searchQuery!.toLowerCase();
        final matchName = r.sampleName.toLowerCase().contains(query);
        final matchCategory =
            r.sampleCategory?.toLowerCase().contains(query) ?? false;
        if (!matchName && !matchCategory) {
          return false;
        }
      }

      return true;
    }).toList();

    // 缓存结果
    _filteredCache = results;
    _cachedFilterCriteria = _currentFilter;

    return results;
  }

  /// 添加检测结果
  Future<void> addResult(DetectionResult result) async {
    try {
      _logger.info('添加检测结果: ${result.sampleName}', tag: 'HistoryProvider');

      // 添加到内存开头
      _history.insert(0, result);
      _totalCount++;

      // 保存到存储
      await _storageService.saveDetectionResult(result);

      // 清除缓存
      _clearCaches();

      _logger.info('检测结果已保存', tag: 'HistoryProvider');
    } catch (e, stackTrace) {
      _logger.error(
        '保存检测结果失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '保存检测结果失败';
    } finally {
      notifyListeners();
    }
  }

  /// 删除检测结果
  Future<void> deleteResult(String resultId) async {
    try {
      _logger.info('删除检测结果: $resultId', tag: 'HistoryProvider');

      // 从内存中删除
      final initialLength = _history.length;
      _history.removeWhere((result) => result.id == resultId);

      if (_history.length < initialLength) {
        _totalCount--;
      }

      // 从存储中删除
      await _storageService.deleteDetectionResult(resultId);

      // 清除缓存
      _clearCaches();

      _logger.info('检测结果已删除', tag: 'HistoryProvider');
    } catch (e, stackTrace) {
      _logger.error(
        '删除检测结果失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '删除检测结果失败';
    } finally {
      notifyListeners();
    }
  }

  /// 清空历史记录
  Future<void> clearHistory() async {
    try {
      _logger.info('清空历史记录', tag: 'HistoryProvider');

      // 清空内存
      _history.clear();
      _totalCount = 0;
      _currentPage = 0;
      _hasMore = false;

      // 清空存储（仅清空检测结果）
      final box = await _storageService.getDetectionResultsCount();
      if (box > 0) {
        await _storageService.clearDetectionResults();
      }

      // 清除缓存
      _clearCaches();

      _logger.info('历史记录已清空', tag: 'HistoryProvider');
    } catch (e, stackTrace) {
      _logger.error(
        '清空历史记录失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '清空历史记录失败';
    } finally {
      notifyListeners();
    }
  }

  /// 获取最近的检测结果（用于首页展示）
  List<DetectionResult> getRecentResults(int limit) {
    if (_currentFilter.isEmpty) {
      return _history.take(limit).toList();
    }
    return _getFilteredResults().take(limit).toList();
  }

  /// P1修复: 获取统计信息（带缓存）
  HistoryStatistics getStatistics() {
    // 检查缓存
    if (_cachedStatistics != null && _statisticsCacheCount == _history.length) {
      return _cachedStatistics!;
    }

    // 计算统计（单次遍历优化）
    int safe = 0, low = 0, medium = 0, high = 0, critical = 0;
    double totalConfidence = 0;
    int withPesticides = 0;

    for (final r in _history) {
      switch (r.riskLevel) {
        case RiskLevel.safe:
          safe++;
          break;
        case RiskLevel.low:
          low++;
          break;
        case RiskLevel.medium:
          medium++;
          break;
        case RiskLevel.high:
          high++;
          break;
        case RiskLevel.critical:
          critical++;
          break;
      }
      totalConfidence += r.confidence;
      if (r.detectedPesticides.isNotEmpty) {
        withPesticides++;
      }
    }

    final total = _history.length;
    final avgConfidence = total > 0 ? totalConfidence / total : 0.0;
    final pesticideRate = total > 0 ? withPesticides / total : 0.0;

    _cachedStatistics = HistoryStatistics(
      total: total,
      safe: safe,
      low: low,
      medium: medium,
      high: high,
      critical: critical,
      averageConfidence: avgConfidence,
      pesticideDetectionRate: pesticideRate,
    );
    _statisticsCacheCount = total;

    return _cachedStatistics!;
  }

  /// 清除所有缓存
  void _clearCaches() {
    _filteredCache = null;
    _cachedFilterCriteria = null;
    _cachedStatistics = null;
    _statisticsCacheCount = -1;
  }

  /// 导出历史记录
  Future<List<DetectionResult>> exportHistory() async {
    try {
      _logger.info('导出历史记录: ${_history.length} 条', tag: 'HistoryProvider');
      return List.from(_history);
    } catch (e, stackTrace) {
      _logger.error(
        '导出历史记录失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '导出历史记录失败';
      return [];
    }
  }

  /// 导入历史记录
  Future<void> importHistory(List<DetectionResult> results) async {
    try {
      _logger.info('导入历史记录: ${results.length} 条', tag: 'HistoryProvider');

      // 添加新记录
      for (final result in results) {
        if (!_history.any((h) => h.id == result.id)) {
          _history.add(result);
          await _storageService.saveDetectionResult(result);
          _totalCount++;
        }
      }

      // 排序
      _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // 清除缓存
      _clearCaches();

      _logger.info('历史记录导入完成', tag: 'HistoryProvider');
    } catch (e, stackTrace) {
      _logger.error(
        '导入历史记录失败: $e',
        stackTrace: stackTrace,
        tag: 'HistoryProvider',
      );
      _errorMessage = '导入历史记录失败';
    } finally {
      notifyListeners();
    }
  }

  /// 重置错误信息
  void resetError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// 历史统计信息
class HistoryStatistics {
  final int total;
  final int safe;
  final int low;
  final int medium;
  final int high;
  final int critical;
  final double averageConfidence;
  final double pesticideDetectionRate;

  const HistoryStatistics({
    required this.total,
    required this.safe,
    required this.low,
    required this.medium,
    required this.high,
    required this.critical,
    required this.averageConfidence,
    required this.pesticideDetectionRate,
  });

  /// 获取风险等级分布
  Map<RiskLevel, int> get riskDistribution {
    return {
      RiskLevel.safe: safe,
      RiskLevel.low: low,
      RiskLevel.medium: medium,
      RiskLevel.high: high,
      RiskLevel.critical: critical,
    };
  }

  /// 获取风险等级百分比
  Map<RiskLevel, double> get riskPercentage {
    if (total == 0) return {};
    return {
      RiskLevel.safe: safe / total,
      RiskLevel.low: low / total,
      RiskLevel.medium: medium / total,
      RiskLevel.high: high / total,
      RiskLevel.critical: critical / total,
    };
  }

  @override
  String toString() {
    return 'HistoryStatistics(total: $total, safe: $safe, low: $low, medium: $medium, high: $high, critical: $critical, avgConfidence: ${(averageConfidence * 100).toStringAsFixed(1)}%, pesticideRate: ${(pesticideDetectionRate * 100).toStringAsFixed(1)}%)';
  }
}
