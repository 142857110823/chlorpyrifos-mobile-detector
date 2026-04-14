import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/models.dart';

/// 云服务运行模式
enum CloudServiceMode {
  /// 真实API模式
  real,
  /// Mock模式
  mock,
}

/// 云端服务
/// 负责与后端API进行数据同步和云端存储
class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  late final Dio _dio;
  String? _authToken;
  CloudServiceMode _mode = CloudServiceMode.mock;
  
  // Mock数据存储
  User? _mockUser;
  final List<DetectionResult> _mockCloudResults = [];
  final Random _random = Random();
  
  // API基础URL
  static const String baseUrl = 'https://api.pesticide-detector.com/v1';

  /// 设置运行模式
  void setMode(CloudServiceMode mode) {
    _mode = mode;
    print('CloudService mode set to: $mode');
  }

  CloudServiceMode get mode => _mode;

  /// 初始化服务
  void init({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? CloudService.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _authToken = null;
        }
        return handler.next(error);
      },
    ));
  }

  /// 设置认证令牌
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// 是否已认证
  bool get isAuthenticated => _authToken != null || _mockUser != null;

  // ==================== 用户认证 ====================

  /// 用户登录
  Future<ApiResponse<User>> login({
    required String email,
    required String password,
  }) async {
    if (_mode == CloudServiceMode.mock) {
      return _mockLogin(email, password);
    }

    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      _authToken = data['token'];
      
      return ApiResponse.success(User.fromJson(data['user']));
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('登录失败: $e');
    }
  }

  /// Mock登录
  Future<ApiResponse<User>> _mockLogin(String email, String password) async {
    // 模拟网络延迟
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(500)));

    // 验证测试账号
    if (email == 'demo@test.com' && password == 'password123') {
      _mockUser = User(
        id: 'mock_user_001',
        email: email,
        displayName: '测试用户',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastLoginAt: DateTime.now(),
      );
      _authToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      return ApiResponse.success(_mockUser!);
    }

    // 允许任意邮箱登录（演示用）
    if (email.contains('@') && password.length >= 6) {
      _mockUser = User(
        id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: email.split('@')[0],
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      _authToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      return ApiResponse.success(_mockUser!);
    }

    return ApiResponse.error('邮箱或密码错误');
  }

  /// 用户注册
  Future<ApiResponse<User>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (_mode == CloudServiceMode.mock) {
      return _mockRegister(email, password, displayName);
    }

    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      });

      final data = response.data;
      _authToken = data['token'];
      
      return ApiResponse.success(User.fromJson(data['user']));
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('注册失败: $e');
    }
  }

  /// Mock注册
  Future<ApiResponse<User>> _mockRegister(String email, String password, String? displayName) async {
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(500)));

    if (!email.contains('@')) {
      return ApiResponse.error('邮箱格式不正确');
    }
    if (password.length < 6) {
      return ApiResponse.error('密码长度至少6位');
    }

    _mockUser = User(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: displayName ?? email.split('@')[0],
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _authToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    
    return ApiResponse.success(_mockUser!);
  }

  /// 退出登录
  Future<void> logout() async {
    if (_mode == CloudServiceMode.mock) {
      _mockUser = null;
      _authToken = null;
      return;
    }

    try {
      await _dio.post('/auth/logout');
    } catch (_) {
    } finally {
      _authToken = null;
    }
  }

  /// 获取当前用户信息
  Future<ApiResponse<User>> getCurrentUser() async {
    if (_mode == CloudServiceMode.mock) {
      if (_mockUser != null) {
        return ApiResponse.success(_mockUser!);
      }
      return ApiResponse.error('未登录');
    }

    try {
      final response = await _dio.get('/auth/me');
      return ApiResponse.success(User.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('获取用户信息失败: $e');
    }
  }

  // ==================== 检测结果同步 ====================

  /// 上传检测结果
  Future<ApiResponse<void>> uploadDetectionResult(DetectionResult result) async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
      _mockCloudResults.add(result);
      return ApiResponse.success(null);
    }

    try {
      await _dio.post('/detections', data: result.toJson());
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('上传检测结果失败: $e');
    }
  }

  /// 批量上传检测结果
  Future<ApiResponse<int>> uploadDetectionResults(List<DetectionResult> results) async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));
      _mockCloudResults.addAll(results);
      return ApiResponse.success(results.length);
    }

    try {
      final response = await _dio.post('/detections/batch', data: {
        'results': results.map((r) => r.toJson()).toList(),
      });
      
      return ApiResponse.success(response.data['uploadedCount'] ?? results.length);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('批量上传失败: $e');
    }
  }

  /// 获取云端检测结果
  Future<ApiResponse<List<DetectionResult>>> getCloudDetectionResults({
    int page = 1,
    int pageSize = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
      
      var results = List<DetectionResult>.from(_mockCloudResults);
      
      if (startDate != null) {
        results = results.where((r) => r.timestamp.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        results = results.where((r) => r.timestamp.isBefore(endDate)).toList();
      }
      
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      final start = (page - 1) * pageSize;
      final end = start + pageSize;
      
      if (start >= results.length) {
        return ApiResponse.success([]);
      }
      
      return ApiResponse.success(
        results.sublist(start, end > results.length ? results.length : end),
      );
    }

    try {
      final response = await _dio.get('/detections', queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      });

      final results = (response.data['data'] as List)
          .map((e) => DetectionResult.fromJson(e))
          .toList();

      return ApiResponse.success(results);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('获取检测结果失败: $e');
    }
  }

  /// 删除云端检测结果
  Future<ApiResponse<void>> deleteCloudDetectionResult(String id) async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 50 + _random.nextInt(100)));
      _mockCloudResults.removeWhere((r) => r.id == id);
      return ApiResponse.success(null);
    }

    try {
      await _dio.delete('/detections/$id');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('删除检测结果失败: $e');
    }
  }

  // ==================== 光谱数据上传 ====================

  /// 上传光谱数据
  Future<ApiResponse<void>> uploadSpectralData(SpectralData data) async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
      return ApiResponse.success(null);
    }

    try {
      await _dio.post('/spectral-data', data: data.toJson());
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('上传光谱数据失败: $e');
    }
  }

  // ==================== AI模型更新 ====================

  /// 检查模型更新
  Future<ApiResponse<ModelUpdateInfo?>> checkModelUpdate(String currentVersion) async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));
      
      // 随机返回是否有更新
      if (_random.nextDouble() > 0.7) {
        return ApiResponse.success(ModelUpdateInfo(
          version: '1.1.0',
          downloadUrl: 'https://example.com/models/v1.1.0/model.tflite',
          fileSize: 2048000,
          description: '优化了农药检测准确率，新增支持3种农药类型',
          releaseDate: DateTime.now().subtract(const Duration(days: 1)),
        ));
      }
      return ApiResponse.success(null);
    }

    try {
      final response = await _dio.get('/models/check-update', queryParameters: {
        'currentVersion': currentVersion,
      });

      if (response.data['hasUpdate'] == true) {
        return ApiResponse.success(ModelUpdateInfo.fromJson(response.data['updateInfo']));
      }
      
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('检查模型更新失败: $e');
    }
  }

  /// 下载模型
  Future<ApiResponse<String>> downloadModel(String modelUrl, String savePath) async {
    if (_mode == CloudServiceMode.mock) {
      // 模拟下载进度
      await Future.delayed(const Duration(seconds: 2));
      return ApiResponse.success(savePath);
    }

    try {
      await _dio.download(
        modelUrl,
        savePath,
        onReceiveProgress: (received, total) {
          // 下载进度回调
        },
      );
      return ApiResponse.success(savePath);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('下载模型失败: $e');
    }
  }

  // ==================== 统计数据 ====================

  /// 获取统计数据
  Future<ApiResponse<Map<String, dynamic>>> getStatistics() async {
    if (_mode == CloudServiceMode.mock) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
      
      return ApiResponse.success({
        'totalDetections': _mockCloudResults.length + _random.nextInt(100),
        'safeCount': _random.nextInt(50) + 20,
        'riskCount': _random.nextInt(20),
        'lastWeekDetections': _random.nextInt(30) + 5,
        'mostDetectedPesticide': '毒死蜱',
      });
    }

    try {
      final response = await _dio.get('/statistics');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('获取统计数据失败: $e');
    }
  }

  // ==================== 工具方法 ====================

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '响应超时，请稍后重试';
      case DioExceptionType.sendTimeout:
        return '请求超时，请稍后重试';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'];
        if (statusCode == 401) return '登录已过期，请重新登录';
        if (statusCode == 403) return '没有权限执行此操作';
        if (statusCode == 404) return '请求的资源不存在';
        if (statusCode == 500) return '服务器内部错误';
        return message ?? '请求失败 ($statusCode)';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      default:
        return '网络错误: ${e.message}';
    }
  }
}

/// API响应包装类
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory ApiResponse.success(T? data) => ApiResponse._(
    isSuccess: true,
    data: data,
  );

  factory ApiResponse.error(String error) => ApiResponse._(
    isSuccess: false,
    error: error,
  );
}

/// 模型更新信息
class ModelUpdateInfo {
  final String version;
  final String downloadUrl;
  final int fileSize;
  final String description;
  final DateTime releaseDate;

  ModelUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.fileSize,
    required this.description,
    required this.releaseDate,
  });

  factory ModelUpdateInfo.fromJson(Map<String, dynamic> json) {
    return ModelUpdateInfo(
      version: json['version'],
      downloadUrl: json['downloadUrl'],
      fileSize: json['fileSize'],
      description: json['description'],
      releaseDate: DateTime.parse(json['releaseDate']),
    );
  }
}
