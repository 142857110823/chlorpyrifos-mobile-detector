import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/helpers.dart';

/// 异常类型枚举
enum AppErrorType {
  network,
  bluetooth,
  storage,
  ai_model,
  device,
  general,
}

/// 应用错误类
class AppError {
  final AppErrorType type;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppError({
    required this.type,
    required this.message,
    this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return '[${type.name}] $message';
  }
}

/// 错误处理服务
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  final _errorController = StreamController<AppError>.broadcast();
  final _errorHistory = <AppError>[];
  final _maxErrorHistory = 50;

  Stream<AppError> get errorStream => _errorController.stream;
  List<AppError> get errorHistory => List.unmodifiable(_errorHistory);

  /// 初始化错误处理服务
  void initialize() {
    // 设置全局异常捕获
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // 设置异步错误捕获
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _handleAsyncError(error, stackTrace);
      return true;
    };

    print('ErrorHandlingService initialized');
  }

  /// 处理Flutter框架错误
  void _handleFlutterError(FlutterErrorDetails details) {
    final error = AppError(
      type: AppErrorType.general,
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );

    _recordError(error);

    // 在开发模式下打印错误
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// 处理异步错误
  void _handleAsyncError(dynamic error, StackTrace stackTrace) {
    final appError = AppError(
      type: _determineErrorType(error),
      message: error.toString(),
      error: error,
      stackTrace: stackTrace,
    );

    _recordError(appError);

    // 在开发模式下打印错误
    if (kDebugMode) {
      print('Async error: $error');
      print(stackTrace);
    }
  }

  /// 手动报告错误
  void reportError({
    required AppErrorType type,
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final appError = AppError(
      type: type,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _recordError(appError);
  }

  /// 记录错误
  void _recordError(AppError error) {
    _errorHistory.add(error);
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
    _errorController.add(error);
    print('Error reported: ${error.toString()}');
  }

  /// 确定错误类型
  AppErrorType _determineErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('http') || errorString.contains('socket') || errorString.contains('dio')) {
      return AppErrorType.network;
    } else if (errorString.contains('bluetooth') || errorString.contains('ble')) {
      return AppErrorType.bluetooth;
    } else if (errorString.contains('hive') || errorString.contains('storage') || errorString.contains('path')) {
      return AppErrorType.storage;
    } else if (errorString.contains('model') || errorString.contains('tflite') || errorString.contains('analyzer') || errorString.contains('inference')) {
      return AppErrorType.ai_model;
    } else if (errorString.contains('device') || errorString.contains('sensor')) {
      return AppErrorType.device;
    } else {
      return AppErrorType.general;
    }
  }

  /// 获取用户友好的错误消息
  String getFriendlyErrorMessage(AppError error) {
    switch (error.type) {
      case AppErrorType.network:
        return '网络连接失败，请检查网络设置后重试';
      case AppErrorType.bluetooth:
        return '蓝牙设备连接失败，请确保设备已开启并在范围内';
      case AppErrorType.storage:
        return '数据存储失败，请检查存储空间是否充足';
      case AppErrorType.ai_model:
        return 'AI模型加载失败，请确保模型文件存在且完整';
      case AppErrorType.device:
        return '设备连接失败，请检查设备状态';
      case AppErrorType.general:
        return '操作失败，请稍后重试';
    }
  }

  /// 获取错误处理建议
  String getErrorHandlingAdvice(AppError error) {
    switch (error.type) {
      case AppErrorType.network:
        return '请检查Wi-Fi或移动数据连接，确保网络稳定';
      case AppErrorType.bluetooth:
        return '请确保蓝牙已开启，设备电量充足，并在有效范围内';
      case AppErrorType.storage:
        return '请清理设备存储空间，确保有足够的空间存储数据';
      case AppErrorType.ai_model:
        return '请重新安装应用或联系技术支持';
      case AppErrorType.device:
        return '请重启设备或检查设备驱动是否正常';
      case AppErrorType.general:
        return '请尝试重启应用或联系技术支持';
    }
  }

  /// 显示用户友好的错误提示
  void showUserFriendlyError(BuildContext context, AppError error) {
    final friendlyMessage = getFriendlyErrorMessage(error);
    final advice = getErrorHandlingAdvice(error);

    Helpers.showErrorSnackBar(
      context,
      friendlyMessage,
      actionLabel: '查看详情',
      onAction: () {
        showErrorDetailsDialog(context, error, advice);
      },
    );
  }

  /// 显示错误详情对话框
  void showErrorDetailsDialog(BuildContext context, AppError error, String advice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('错误类型: ${error.type.name}'),
            const SizedBox(height: 8),
            Text('错误信息: ${error.message}'),
            const SizedBox(height: 16),
            Text('建议: $advice'),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              Text('详细信息: ${error.error.toString()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  /// 获取错误统计
  Map<AppErrorType, int> getErrorStats() {
    final stats = <AppErrorType, int>{};
    for (final error in _errorHistory) {
      stats[error.type] = (stats[error.type] ?? 0) + 1;
    }
    return stats;
  }

  /// 清除错误历史
  void clearErrorHistory() {
    _errorHistory.clear();
  }

  /// 释放资源
  void dispose() {
    _errorController.close();
  }
}

/// 错误处理扩展
extension ErrorHandlingExtension on Object {
  /// 安全执行可能抛出异常的操作
  static Future<T?> safeExecute<T>({
    required Future<T> Function() operation,
    required AppErrorType errorType,
    String? errorMessage,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      ErrorHandlingService().reportError(
        type: errorType,
        message: errorMessage ?? e.toString(),
        error: e,
        stackTrace: stack,
      );
      return fallbackValue;
    }
  }

  /// 同步安全执行
  static T? safeExecuteSync<T>({
    required T Function() operation,
    required AppErrorType errorType,
    String? errorMessage,
    T? fallbackValue,
  }) {
    try {
      return operation();
    } catch (e, stack) {
      ErrorHandlingService().reportError(
        type: errorType,
        message: errorMessage ?? e.toString(),
        error: e,
        stackTrace: stack,
      );
      return fallbackValue;
    }
  }
}
