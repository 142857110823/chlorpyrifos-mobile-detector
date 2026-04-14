import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';

/// 应用全局状态管理器
/// 管理应用级别的状态，实现页面间数据共享和流转
class AppStateManager extends ChangeNotifier {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  final StorageService _storageService = StorageService();
  final LoggingService _logger = LoggingService();

  // 全局状态
  AppState _currentState = AppState.idle;
  String? _currentError;
  bool _isInitialized = false;

  // 数据缓存
  final Map<String, dynamic> _dataCache = {};
  final StreamController<AppStateEvent> _eventController = StreamController<AppStateEvent>.broadcast();

  // 检测结果流
  final StreamController<DetectionResult> _detectionResultController = StreamController<DetectionResult>.broadcast();

  // Getters
  AppState get currentState => _currentState;
  String? get currentError => _currentError;
  bool get isInitialized => _isInitialized;
  Stream<AppStateEvent> get eventStream => _eventController.stream;
  Stream<DetectionResult> get detectionResultStream => _detectionResultController.stream;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger.info('初始化AppStateManager', tag: 'AppStateManager');
    
    try {
      await _storageService.init();
      _isInitialized = true;
      _setState(AppState.ready);
      _logger.info('AppStateManager初始化完成', tag: 'AppStateManager');
    } catch (e, stackTrace) {
      _logger.error('初始化失败: $e', stackTrace: stackTrace, tag: 'AppStateManager');
      _setError('初始化失败: $e');
    }
  }

  /// 设置状态
  void _setState(AppState state) {
    _currentState = state;
    _eventController.add(AppStateEvent(state: state, timestamp: DateTime.now()));
    notifyListeners();
  }

  /// 设置错误
  void _setError(String error) {
    _currentError = error;
    _currentState = AppState.error;
    _eventController.add(AppStateEvent(
      state: AppState.error,
      error: error,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _currentError = null;
    if (_currentState == AppState.error) {
      _currentState = AppState.ready;
    }
    notifyListeners();
  }

  /// 缓存数据
  void cacheData(String key, dynamic data) {
    _dataCache[key] = data;
    _logger.debug('数据已缓存: $key', tag: 'AppStateManager');
  }

  /// 获取缓存数据
  T? getCachedData<T>(String key) {
    final data = _dataCache[key];
    if (data is T) {
      return data;
    }
    return null;
  }

  /// 清除缓存
  void clearCache(String key) {
    _dataCache.remove(key);
  }

  /// 清除所有缓存
  void clearAllCache() {
    _dataCache.clear();
    notifyListeners();
  }

  /// 发布检测结果
  void publishDetectionResult(DetectionResult result) {
    _detectionResultController.add(result);
    _logger.info('检测结果已发布: ${result.sampleName}', tag: 'AppStateManager');
  }

  /// 显示全局加载状态
  void showLoading(String message) {
    _setState(AppState.loading);
    _eventController.add(AppStateEvent(
      state: AppState.loading,
      message: message,
      timestamp: DateTime.now(),
    ));
  }

  /// 隐藏加载状态
  void hideLoading() {
    _setState(AppState.ready);
  }

  /// 显示全局消息
  void showMessage(String message, {MessageType type = MessageType.info}) {
    _eventController.add(AppStateEvent(
      state: AppState.message,
      message: message,
      messageType: type,
      timestamp: DateTime.now(),
    ));
  }

  /// 处理错误
  void handleError(String error, {StackTrace? stackTrace}) {
    _logger.error(error, stackTrace: stackTrace, tag: 'AppStateManager');
    _setError(error);
  }

  /// 导航到指定页面
  void navigateTo(String route, {Map<String, dynamic>? arguments}) {
    _eventController.add(AppStateEvent(
      state: AppState.navigation,
      route: route,
      arguments: arguments,
      timestamp: DateTime.now(),
    ));
  }

  /// 刷新数据
  Future<void> refreshData() async {
    _setState(AppState.refreshing);
    try {
      // 触发数据刷新事件
      _eventController.add(AppStateEvent(
        state: AppState.refreshing,
        timestamp: DateTime.now(),
      ));
      _setState(AppState.ready);
    } catch (e) {
      _setError('刷新数据失败: $e');
    }
  }

  /// 释放资源
  @override
  void dispose() {
    _eventController.close();
    _detectionResultController.close();
    super.dispose();
  }
}

/// 应用状态枚举
enum AppState {
  idle,
  initializing,
  ready,
  loading,
  error,
  message,
  navigation,
  refreshing,
}

/// 消息类型
enum MessageType {
  info,
  success,
  warning,
  error,
}

/// 应用状态事件
class AppStateEvent {
  final AppState state;
  final String? message;
  final String? error;
  final MessageType? messageType;
  final String? route;
  final Map<String, dynamic>? arguments;
  final DateTime timestamp;

  AppStateEvent({
    required this.state,
    this.message,
    this.error,
    this.messageType,
    this.route,
    this.arguments,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AppStateEvent(state: $state, message: $message, error: $error, timestamp: $timestamp)';
  }
}
