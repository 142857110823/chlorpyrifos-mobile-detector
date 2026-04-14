import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/error_handling_service.dart';
import '../services/logging_service.dart';

/// 应用更新信息
class UpdateInfo {
  final String version;
  final String title;
  final String description;
  final String downloadUrl;
  final int size;
  final bool isMandatory;

  UpdateInfo({
    required this.version,
    required this.title,
    required this.description,
    required this.downloadUrl,
    required this.size,
    required this.isMandatory,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'],
      title: json['title'],
      description: json['description'],
      downloadUrl: json['downloadUrl'],
      size: json['size'] ?? 0,
      isMandatory: json['isMandatory'] ?? false,
    );
  }
}

/// 应用更新服务
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final _dio = Dio();
  final _errorService = ErrorHandlingService();
  final _loggingService = LoggingService();

  // API配置
  static const String updateApiUrl =
      'https://api.pesticide-detector.example.com/api/app/check-update';

  /// 检查应用更新
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      _loggingService.log('开始检查应用更新', level: LogLevel.info);

      // 获取当前应用版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      _loggingService.log('当前应用版本: $currentVersion (build: $buildNumber)',
          level: LogLevel.info);

      // 尝试调用实际的API
      try {
        final response = await _dio.get(
          updateApiUrl,
          queryParameters: {
            'currentVersion': currentVersion,
            'buildNumber': buildNumber,
            'platform': Platform.operatingSystem,
            'platformVersion': Platform.operatingSystemVersion,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final hasUpdate = response.data['hasUpdate'] ?? false;
          if (hasUpdate) {
            final updateInfo = UpdateInfo.fromJson(response.data['updateInfo']);

            // 比较版本号
            if (_isNewerVersion(updateInfo.version, currentVersion)) {
              _loggingService.log('发现应用更新: ${updateInfo.version}',
                  level: LogLevel.info);
              return updateInfo;
            } else {
              _loggingService.log('当前应用已是最新版本: $currentVersion',
                  level: LogLevel.info);
              return null;
            }
          }
        }
      } catch (apiError) {
        _loggingService.log('API调用失败，使用模拟数据: $apiError',
            level: LogLevel.warning);
        // API调用失败，使用模拟数据
      }

      // 模拟API响应（作为备份）
      await Future.delayed(const Duration(seconds: 1));

      final mockResponse = {
        'hasUpdate': true,
        'updateInfo': {
          'version': '1.1.0',
          'title': '应用更新',
          'description':
              '\n1. 优化了蓝牙连接稳定性\n2. 提高了AI模型检测准确率\n3. 修复了已知问题\n4. 改善了用户体验\n',
          'downloadUrl':
              'https://example.com/app/pesticide-detector-v1.1.0.apk',
          'size': 20480000, // 20MB
          'isMandatory': false,
        },
      };

      final hasUpdate = mockResponse['hasUpdate'] ?? false;
      if (hasUpdate == true) {
        final updateInfo = UpdateInfo.fromJson(
            mockResponse['updateInfo'] as Map<String, dynamic>);

        if (_isNewerVersion(updateInfo.version, currentVersion)) {
          _loggingService.log('模拟数据: 发现应用更新 ${updateInfo.version}',
              level: LogLevel.info);
          return updateInfo;
        }
      }

      _loggingService.log('当前应用已是最新版本: $currentVersion', level: LogLevel.info);
      return null;
    } catch (e, stack) {
      _errorService.reportError(
        type: AppErrorType.general,
        message: '检查应用更新失败',
        error: e,
        stackTrace: stack,
      );
      _loggingService.log('检查应用更新失败: $e', level: LogLevel.error);
      return null;
    }
  }

  /// 验证更新包的完整性
  Future<bool> verifyUpdatePackage(File updateFile, String expectedHash) async {
    try {
      _loggingService.log('开始验证更新包完整性', level: LogLevel.info);

      if (!updateFile.existsSync()) {
        _loggingService.log('更新包文件不存在', level: LogLevel.error);
        return false;
      }

      // 计算文件的SHA256哈希值
      final fileBytes = await updateFile.readAsBytes();
      final digest = sha256.convert(fileBytes);
      final actualHash = digest.toString();

      _loggingService.log('计算得到的哈希值: $actualHash', level: LogLevel.info);
      _loggingService.log('预期的哈希值: $expectedHash', level: LogLevel.info);

      final isValid = actualHash == expectedHash;
      _loggingService.log('更新包验证结果: $isValid', level: LogLevel.info);

      return isValid;
    } catch (e, stack) {
      _errorService.reportError(
        type: AppErrorType.general,
        message: '验证更新包失败',
        error: e,
        stackTrace: stack,
      );
      _loggingService.log('验证更新包失败: $e', level: LogLevel.error);
      return false;
    }
  }

  /// 获取当前应用版本信息
  Future<Map<String, String>> getCurrentVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
      };
    } catch (e) {
      _loggingService.log('获取版本信息失败: $e', level: LogLevel.error);
      return {
        'version': 'unknown',
        'buildNumber': 'unknown',
        'appName': 'Pesticide Detector',
        'packageName': 'com.pesticide.detector',
      };
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
      _loggingService.log('比较版本号失败: $e', level: LogLevel.error);
      return false;
    }
  }

  /// 格式化文件大小
  String formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    final k = 1024;
    final sizes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(k)).floor();
    return '${(bytes / pow(k, i)).toStringAsFixed(2)} ${sizes[i]}';
  }
}
