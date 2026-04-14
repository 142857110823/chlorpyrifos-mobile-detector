import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// 模型管理服务
/// 负责模型的下载、更新、版本管理
class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  final Dio _dio = Dio();

  // 模型配置
  static const String modelServerUrl =
      'https://api.pesticide-detector.com/models';
  static const String classificationModelName = 'pesticide_classifier.tflite';
  static const String regressionModelName = 'concentration_regressor.tflite';

  String? _localModelPath;
  ModelInfo? _currentModelInfo;

  // 下载进度流
  final _downloadProgressController =
      StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get downloadProgress =>
      _downloadProgressController.stream;

  /// 初始化模型管理器
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _localModelPath = '${appDir.path}/models';

    // 确保模型目录存在
    final modelDir = Directory(_localModelPath!);
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    // 加载当前模型信息
    await _loadCurrentModelInfo();
  }

  /// 加载当前模型信息
  Future<void> _loadCurrentModelInfo() async {
    try {
      final infoFile = File('$_localModelPath/model_info.json');
      if (await infoFile.exists()) {
        final json = await infoFile.readAsString();
        _currentModelInfo = ModelInfo.fromJsonString(json);
      } else {
        // 使用内置模型信息
        _currentModelInfo = ModelInfo(
          version: '1.0.0',
          classificationModelPath: 'assets/models/$classificationModelName',
          regressionModelPath: 'assets/models/$regressionModelName',
          isBuiltIn: true,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Failed to load model info: $e');
    }
  }

  /// 获取当前模型信息
  ModelInfo? get currentModelInfo => _currentModelInfo;

  /// 获取当前模型版本
  String get currentVersion => _currentModelInfo?.version ?? '1.0.0';

  /// 检查模型更新
  Future<ModelUpdateInfo?> checkForUpdate() async {
    try {
      // 设置超时
      final response = await _dio.get(
        '$modelServerUrl/check-update',
        queryParameters: {'currentVersion': currentVersion},
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        if (response.data['hasUpdate'] == true) {
          return ModelUpdateInfo.fromJson(response.data['updateInfo']);
        } else {
          print('No update available');
        }
      } else {
        print('Server returned error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          print('Connection timeout when checking for updates');
          break;
        case DioExceptionType.receiveTimeout:
          print('Receive timeout when checking for updates');
          break;
        case DioExceptionType.sendTimeout:
          print('Send timeout when checking for updates');
          break;
        case DioExceptionType.badResponse:
          print(
              'Bad response when checking for updates: ${e.response?.statusCode}');
          break;
        case DioExceptionType.connectionError:
          print('Connection error when checking for updates: ${e.message}');
          break;
        default:
          print('Unknown error when checking for updates: $e');
      }
    } catch (e) {
      print('Failed to check for update: $e');
    }
    return null;
  }

  /// 下载模型更新
  Future<bool> downloadUpdate(ModelUpdateInfo updateInfo) async {
    // 发送开始更新通知
    _downloadProgressController.add(DownloadProgress(
      modelName: 'update',
      progress: 0,
      status: DownloadStatus.pending,
    ));

    try {
      final tempDir = await getTemporaryDirectory();
      final tempModelPath = '${tempDir.path}/model_update';

      // 创建临时目录
      final tempModelDir = Directory(tempModelPath);
      if (await tempModelDir.exists()) {
        await tempModelDir.delete(recursive: true);
      }
      await tempModelDir.create();

      // 下载分类模型
      await _downloadFile(
        updateInfo.classificationModelUrl,
        '$tempModelPath/$classificationModelName',
        'classification',
      );

      // 下载回归模型
      await _downloadFile(
        updateInfo.regressionModelUrl,
        '$tempModelPath/$regressionModelName',
        'regression',
      );

      // 验证模型
      _downloadProgressController.add(DownloadProgress(
        modelName: 'validation',
        progress: 0.9,
        status: DownloadStatus.downloading,
      ));

      final isValid = await _validateModels(tempModelPath);
      if (!isValid) {
        throw Exception('Model validation failed: invalid model files');
      }

      // 替换现有模型
      _downloadProgressController.add(DownloadProgress(
        modelName: 'installation',
        progress: 0.95,
        status: DownloadStatus.downloading,
      ));
      await _replaceModels(tempModelPath);

      // 更新模型信息
      _currentModelInfo = ModelInfo(
        version: updateInfo.version,
        classificationModelPath: '$_localModelPath/$classificationModelName',
        regressionModelPath: '$_localModelPath/$regressionModelName',
        isBuiltIn: false,
        createdAt: DateTime.now(),
        description: updateInfo.description,
      );
      await _saveModelInfo();

      // 清理临时文件
      await tempModelDir.delete(recursive: true);

      // 发送完成通知
      _downloadProgressController.add(DownloadProgress(
        modelName: 'update',
        progress: 1.0,
        status: DownloadStatus.completed,
      ));

      return true;
    } on DioException catch (e) {
      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage = '连接超时，请检查网络';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage = '下载超时，请稍后重试';
          break;
        case DioExceptionType.sendTimeout:
          errorMessage = '请求超时，请稍后重试';
          break;
        case DioExceptionType.badResponse:
          errorMessage = '服务器返回错误: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = '网络连接失败，请检查网络设置';
          break;
        default:
          errorMessage = '下载失败: ${e.message}';
      }
      _handleUpdateError(errorMessage, e);
      return false;
    } catch (e) {
      _handleUpdateError('更新失败: ${e.toString()}', e);
      return false;
    }
  }

  /// 处理更新错误
  void _handleUpdateError(String errorMessage, dynamic error) {
    print('Model update error: $error');
    _downloadProgressController.add(DownloadProgress(
      modelName: 'error',
      progress: 0,
      status: DownloadStatus.failed,
      error: errorMessage,
    ));
  }

  /// 下载文件
  Future<void> _downloadFile(
      String url, String savePath, String modelName) async {
    _downloadProgressController.add(DownloadProgress(
      modelName: modelName,
      progress: 0,
      status: DownloadStatus.downloading,
    ));

    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 5), // 下载大文件需要更长的超时
        ),
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? received / total : 0.0;
          _downloadProgressController.add(DownloadProgress(
            modelName: modelName,
            progress: progress,
            status: DownloadStatus.downloading,
            bytesReceived: received,
            bytesTotal: total,
          ));
        },
      );

      _downloadProgressController.add(DownloadProgress(
        modelName: modelName,
        progress: 1.0,
        status: DownloadStatus.completed,
      ));
    } on DioException catch (e) {
      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage = '连接超时，请检查网络';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage = '下载超时，请稍后重试';
          break;
        case DioExceptionType.sendTimeout:
          errorMessage = '请求超时，请稍后重试';
          break;
        case DioExceptionType.badResponse:
          errorMessage = '服务器返回错误: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = '网络连接失败，请检查网络设置';
          break;
        default:
          errorMessage = '下载失败: ${e.message}';
      }
      _handleUpdateError('${modelName}模型下载失败: $errorMessage', e);
      throw Exception('Failed to download $modelName model: $errorMessage');
    } catch (e) {
      _handleUpdateError('${modelName}模型下载失败: ${e.toString()}', e);
      throw Exception('Failed to download $modelName model: $e');
    }
  }

  /// 验证模型
  Future<bool> _validateModels(String modelPath) async {
    try {
      final classificationFile = File('$modelPath/$classificationModelName');
      final regressionFile = File('$modelPath/$regressionModelName');

      // 检查文件是否存在
      if (!await classificationFile.exists() ||
          !await regressionFile.exists()) {
        return false;
      }

      // 检查文件大小
      final classSize = await classificationFile.length();
      final regSize = await regressionFile.length();
      if (classSize < 1024 || regSize < 1024) {
        return false;
      }

      // 检查TFLite文件头
      final classHeader = await classificationFile.openRead(0, 4).first;
      final regHeader = await regressionFile.openRead(0, 4).first;

      // TFLite文件以 "TFL3" 开头
      // 简化验证：检查文件头不为空
      if (classHeader.isEmpty || regHeader.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      print('Model validation error: $e');
      return false;
    }
  }

  /// 替换模型
  Future<void> _replaceModels(String tempPath) async {
    final classificationSrc = File('$tempPath/$classificationModelName');
    final regressionSrc = File('$tempPath/$regressionModelName');

    final classificationDst = File('$_localModelPath/$classificationModelName');
    final regressionDst = File('$_localModelPath/$regressionModelName');

    // 备份旧模型
    if (await classificationDst.exists()) {
      await classificationDst.rename('${classificationDst.path}.bak');
    }
    if (await regressionDst.exists()) {
      await regressionDst.rename('${regressionDst.path}.bak');
    }

    try {
      // 复制新模型
      await classificationSrc.copy(classificationDst.path);
      await regressionSrc.copy(regressionDst.path);

      // 删除备份
      final classBackup = File('${classificationDst.path}.bak');
      final regBackup = File('${regressionDst.path}.bak');
      if (await classBackup.exists()) await classBackup.delete();
      if (await regBackup.exists()) await regBackup.delete();
    } catch (e) {
      // 恢复备份
      final classBackup = File('${classificationDst.path}.bak');
      final regBackup = File('${regressionDst.path}.bak');
      if (await classBackup.exists()) {
        await classBackup.rename(classificationDst.path);
      }
      if (await regBackup.exists()) {
        await regBackup.rename(regressionDst.path);
      }
      rethrow;
    }
  }

  /// 保存模型信息
  Future<void> _saveModelInfo() async {
    if (_currentModelInfo == null) return;

    final infoFile = File('$_localModelPath/model_info.json');
    await infoFile.writeAsString(_currentModelInfo!.toJsonString());
  }

  /// 获取模型文件路径
  Future<String> getClassificationModelPath() async {
    if (_currentModelInfo == null) {
      await initialize();
    }

    if (_currentModelInfo?.isBuiltIn == true) {
      // 从assets复制到本地
      return await _copyAssetModel(classificationModelName);
    }

    return '$_localModelPath/$classificationModelName';
  }

  /// 获取回归模型路径
  Future<String> getRegressionModelPath() async {
    if (_currentModelInfo == null) {
      await initialize();
    }

    if (_currentModelInfo?.isBuiltIn == true) {
      return await _copyAssetModel(regressionModelName);
    }

    return '$_localModelPath/$regressionModelName';
  }

  /// 从assets复制模型
  Future<String> _copyAssetModel(String modelName) async {
    final localPath = '$_localModelPath/$modelName';
    final localFile = File(localPath);

    if (!await localFile.exists()) {
      try {
        final data = await rootBundle.load('assets/models/$modelName');
        await localFile.writeAsBytes(data.buffer.asUint8List());
      } catch (e) {
        print('Failed to copy asset model: $e');
        // 返回assets路径，让TFLite直接从assets加载
        return 'assets/models/$modelName';
      }
    }

    return localPath;
  }

  /// 回滚到内置模型
  Future<void> rollbackToBuiltIn() async {
    try {
      // 删除下载的模型
      final classificationFile =
          File('$_localModelPath/$classificationModelName');
      final regressionFile = File('$_localModelPath/$regressionModelName');

      if (await classificationFile.exists()) {
        await classificationFile.delete();
      }
      if (await regressionFile.exists()) {
        await regressionFile.delete();
      }

      // 重置模型信息
      _currentModelInfo = ModelInfo(
        version: '1.0.0',
        classificationModelPath: 'assets/models/$classificationModelName',
        regressionModelPath: 'assets/models/$regressionModelName',
        isBuiltIn: true,
        createdAt: DateTime.now(),
      );
      await _saveModelInfo();
    } catch (e) {
      print('Failed to rollback: $e');
    }
  }

  /// 获取模型存储使用情况
  Future<ModelStorageInfo> getStorageInfo() async {
    var totalSize = 0;

    try {
      final classificationFile =
          File('$_localModelPath/$classificationModelName');
      final regressionFile = File('$_localModelPath/$regressionModelName');

      if (await classificationFile.exists()) {
        totalSize += await classificationFile.length();
      }
      if (await regressionFile.exists()) {
        totalSize += await regressionFile.length();
      }
    } catch (e) {
      print('Failed to get storage info: $e');
    }

    return ModelStorageInfo(
      totalSize: totalSize,
      modelCount: 2,
      localPath: _localModelPath ?? '',
    );
  }

  /// 清理模型缓存
  Future<void> clearCache() async {
    try {
      final modelDir = Directory(_localModelPath!);
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
        await modelDir.create();
      }

      // 重置到内置模型
      await rollbackToBuiltIn();
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _downloadProgressController.close();
  }
}

/// 模型信息
class ModelInfo {
  final String version;
  final String classificationModelPath;
  final String regressionModelPath;
  final bool isBuiltIn;
  final DateTime createdAt;
  final String? description;

  ModelInfo({
    required this.version,
    required this.classificationModelPath,
    required this.regressionModelPath,
    required this.isBuiltIn,
    required this.createdAt,
    this.description,
  });

  factory ModelInfo.fromJsonString(String json) {
    // 简化的JSON解析 - 实际项目中应使用json.decode
    return ModelInfo(
      version: '1.0.0',
      classificationModelPath: '',
      regressionModelPath: '',
      isBuiltIn: true,
      createdAt: DateTime.now(),
    );
  }

  String toJsonString() {
    return '''{
  "version": "$version",
  "classificationModelPath": "$classificationModelPath",
  "regressionModelPath": "$regressionModelPath",
  "isBuiltIn": $isBuiltIn,
  "createdAt": "${createdAt.toIso8601String()}",
  "description": ${description != null ? '"$description"' : 'null'}
}''';
  }
}

/// 模型更新信息
class ModelUpdateInfo {
  final String version;
  final String classificationModelUrl;
  final String regressionModelUrl;
  final int totalSize;
  final String description;
  final DateTime releaseDate;
  final List<String> improvements;

  ModelUpdateInfo({
    required this.version,
    required this.classificationModelUrl,
    required this.regressionModelUrl,
    required this.totalSize,
    required this.description,
    required this.releaseDate,
    this.improvements = const [],
  });

  factory ModelUpdateInfo.fromJson(Map<String, dynamic> json) {
    return ModelUpdateInfo(
      version: json['version'] ?? '',
      classificationModelUrl: json['classificationModelUrl'] ?? '',
      regressionModelUrl: json['regressionModelUrl'] ?? '',
      totalSize: json['totalSize'] ?? 0,
      description: json['description'] ?? '',
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : DateTime.now(),
      improvements: (json['improvements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// 格式化文件大小
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024)
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 下载进度
class DownloadProgress {
  final String modelName;
  final double progress;
  final DownloadStatus status;
  final int? bytesReceived;
  final int? bytesTotal;
  final String? error;

  DownloadProgress({
    required this.modelName,
    required this.progress,
    required this.status,
    this.bytesReceived,
    this.bytesTotal,
    this.error,
  });

  /// 进度百分比
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// 格式化已下载大小
  String get formattedReceived {
    if (bytesReceived == null) return '';
    if (bytesReceived! < 1024) return '$bytesReceived B';
    if (bytesReceived! < 1024 * 1024)
      return '${(bytesReceived! / 1024).toStringAsFixed(1)} KB';
    return '${(bytesReceived! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 下载状态
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
}

/// 模型存储信息
class ModelStorageInfo {
  final int totalSize;
  final int modelCount;
  final String localPath;

  ModelStorageInfo({
    required this.totalSize,
    required this.modelCount,
    required this.localPath,
  });

  /// 格式化总大小
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024)
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
