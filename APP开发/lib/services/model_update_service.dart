import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/helpers.dart';
import '../services/error_handling_service.dart';
import '../services/logging_service.dart';

/// 模型更新状态
enum ModelUpdateStatus {
  checking, // 检查更新
  downloading, // 下载中
  verifying, // 验证中
  updating, // 更新中
  completed, // 完成
  error, // 错误
  noUpdate, // 无更新
}

/// 模型信息
class ModelInfo {
  final String version;
  final String url;
  final String md5Hash;
  final double size;

  ModelInfo({
    required this.version,
    required this.url,
    required this.md5Hash,
    required this.size,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      version: json['version'],
      url: json['url'],
      md5Hash: json['md5'],
      size: json['size'],
    );
  }
}

/// 模型更新服务
class ModelUpdateService {
  static final ModelUpdateService _instance = ModelUpdateService._internal();
  factory ModelUpdateService() => _instance;
  ModelUpdateService._internal();

  final _dio = Dio();
  final _errorService = ErrorHandlingService();
  final _loggingService = LoggingService();

  // API配置
  static const String baseApiUrl = 'https://api.pesticide-detector.example.com';
  static const String modelUpdateEndpoint = '/api/models/check-update';

  /// 检查模型更新
  Future<ModelInfo?> checkForUpdates(String currentVersion) async {
    try {
      _loggingService.log('开始检查模型更新，当前版本: $currentVersion',
          level: LogLevel.info);

      // 1. 尝试调用实际的API
      try {
        final response = await _dio.get(
          '$baseApiUrl$modelUpdateEndpoint',
          queryParameters: {
            'current_version': currentVersion,
            'app_version': '1.0.0', // 应用版本
            'platform': io.Platform.operatingSystem,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final modelInfo = ModelInfo.fromJson(response.data);

          // 比较版本号
          if (_isNewerVersion(modelInfo.version, currentVersion)) {
            _loggingService.log('发现模型更新: ${modelInfo.version}',
                level: LogLevel.info);
            return modelInfo;
          } else {
            _loggingService.log('当前模型已是最新版本: $currentVersion',
                level: LogLevel.info);
            return null;
          }
        }
      } catch (apiError) {
        _loggingService.log('API调用失败，使用模拟数据: $apiError',
            level: LogLevel.warning);
        // API调用失败，使用模拟数据
      }

      // 2. 模拟API响应（作为备份）
      await Future.delayed(const Duration(seconds: 1));

      final mockResponse = {
        'version': '1.1.0',
        'url': 'https://example.com/models/pesticide_model_v1.1.0.tflite',
        'md5': 'd41d8cd98f00b204e9800998ecf8427e',
        'size': 5.2,
      };

      final modelInfo = ModelInfo.fromJson(mockResponse);

      // 比较版本号
      if (_isNewerVersion(modelInfo.version, currentVersion)) {
        _loggingService.log('模拟数据: 发现模型更新 ${modelInfo.version}',
            level: LogLevel.info);
        return modelInfo;
      } else {
        _loggingService.log('模拟数据: 当前模型已是最新版本: $currentVersion',
            level: LogLevel.info);
        return null;
      }
    } catch (e, stack) {
      _errorService.reportError(
        type: AppErrorType.ai_model,
        message: '检查模型更新失败',
        error: e,
        stackTrace: stack,
      );
      _loggingService.log('检查模型更新失败: $e', level: LogLevel.error);
      return null;
    }
  }

  /// 下载并更新模型
  Future<io.File?> downloadAndUpdateModel(
    ModelInfo modelInfo,
    Function(ModelUpdateStatus, double)? onProgress,
  ) async {
    try {
      _loggingService.log('开始下载模型更新: ${modelInfo.version}',
          level: LogLevel.info);

      // 通知开始检查
      onProgress?.call(ModelUpdateStatus.checking, 0);

      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = io.Directory('${appDir.path}/models');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        _loggingService.log('创建模型目录: ${modelDir.path}', level: LogLevel.info);
      }

      // 下载文件路径
      final tempFilePath = '${modelDir.path}/temp_model.tflite';
      final finalFilePath = '${modelDir.path}/pesticide_model.tflite';

      // 通知开始下载
      onProgress?.call(ModelUpdateStatus.downloading, 0);
      _loggingService.log('开始下载模型文件: ${modelInfo.url}', level: LogLevel.info);

      // 下载模型文件
      await _dio.download(
        modelInfo.url,
        tempFilePath,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? received / total : 0;
          onProgress?.call(ModelUpdateStatus.downloading, progress.toDouble());
        },
      );

      // 通知开始验证
      onProgress?.call(ModelUpdateStatus.verifying, 0.9);
      _loggingService.log('开始验证模型文件', level: LogLevel.info);

      // 验证文件MD5
      final tempFile = io.File(tempFilePath);
      final isVerified = await verifyModel(tempFile, modelInfo.md5Hash);
      if (!isVerified) {
        _loggingService.log('模型文件验证失败', level: LogLevel.error);
        throw Exception('模型文件验证失败');
      }
      _loggingService.log('模型文件验证成功', level: LogLevel.info);

      // 通知开始更新
      onProgress?.call(ModelUpdateStatus.updating, 0.95);
      _loggingService.log('开始更新模型文件', level: LogLevel.info);

      // 替换旧模型
      if (await tempFile.exists()) {
        final finalFile = io.File(finalFilePath);
        if (await finalFile.exists()) {
          await finalFile.delete();
          _loggingService.log('删除旧模型文件', level: LogLevel.info);
        }
        await tempFile.rename(finalFilePath);
        _loggingService.log('更新模型文件成功', level: LogLevel.info);
      }

      // 通知完成
      onProgress?.call(ModelUpdateStatus.completed, 1.0);
      _loggingService.log('模型更新完成', level: LogLevel.info);

      return io.File(finalFilePath);
    } catch (e, stack) {
      _errorService.reportError(
        type: AppErrorType.ai_model,
        message: '下载模型失败',
        error: e,
        stackTrace: stack,
      );
      _loggingService.log('下载模型失败: $e', level: LogLevel.error);
      onProgress?.call(ModelUpdateStatus.error, 0);
      return null;
    }
  }

  /// 验证模型文件
  Future<bool> verifyModel(io.File modelFile, String expectedMd5) async {
    try {
      if (!await modelFile.exists()) {
        return false;
      }

      // 计算文件的实际MD5值
      final fileBytes = await modelFile.readAsBytes();
      final digest = md5.convert(fileBytes);
      final actualMd5 = digest.toString();

      // 比较实际MD5与预期MD5
      return actualMd5 == expectedMd5;
    } catch (e, stack) {
      _errorService.reportError(
        type: AppErrorType.ai_model,
        message: '验证模型失败',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 检查模型文件是否存在
  Future<bool> isModelAvailable() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = io.File('${appDir.path}/models/pesticide_model.tflite');
      final exists = await modelFile.exists();
      _loggingService.log('模型文件检查结果: $exists', level: LogLevel.info);
      return exists;
    } catch (e) {
      _loggingService.log('检查模型文件失败: $e', level: LogLevel.error);
      return false;
    }
  }

  /// 获取模型文件路径
  Future<String?> getModelPath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = io.File('${appDir.path}/models/pesticide_model.tflite');
      final exists = await modelFile.exists();
      if (exists) {
        _loggingService.log('使用本地模型文件: ${modelFile.path}',
            level: LogLevel.info);
        return modelFile.path;
      } else {
        // 尝试使用assets中的模型
        _loggingService.log('本地模型文件不存在，使用assets模型', level: LogLevel.warning);
        return 'assets/models/model.tflite';
      }
    } catch (e) {
      _loggingService.log('获取模型路径失败: $e', level: LogLevel.error);
      return null;
    }
  }

  /// 辅助方法：比较版本号
  bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // 获取最大长度
      final maxLength = newParts.length > currentParts.length
          ? newParts.length
          : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final newPart = i < newParts.length ? newParts[i] : 0;
        final currentPart = i < currentParts.length ? currentParts[i] : 0;

        if (newPart > currentPart) {
          return true;
        } else if (newPart < currentPart) {
          return false;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
