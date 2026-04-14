import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/services.dart';

/// 应用状态管理Provider
class AppProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final BluetoothService _bluetoothService = BluetoothService();
  final CloudService _cloudService = CloudService();
  StreamSubscription<DeviceConnectionState>? _connectionSubscription;

  // 用户状态
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // 设备连接状态
  DeviceConnectionState _deviceConnectionState =
      DeviceConnectionState.disconnected;
  DeviceConnectionState get deviceConnectionState => _deviceConnectionState;
  DeviceInfo? get connectedDevice => _bluetoothService.currentDeviceInfo;

  // 主题模式
  String _themeMode = 'system';
  String get themeMode => _themeMode;

  // 检测统计
  int _totalDetections = 0;
  int _todayDetections = 0;
  int get totalDetections => _totalDetections;
  int get todayDetections => _todayDetections;

  // 初始化标志
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初始化应用状态
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化存储服务
    await _storageService.init();

    // 初始化云服务
    _cloudService.init();

    // 加载用户信息
    _currentUser = await _storageService.getCurrentUser();

    // 加载主题设置
    _themeMode = _storageService.getThemeMode();

    // 加载统计数据
    await _refreshStatistics();

    // 监听蓝牙连接状态
    _deviceConnectionState = _bluetoothService.currentConnectionState;
    _connectionSubscription?.cancel();
    _connectionSubscription = _bluetoothService.connectionState.listen((state) {
      _deviceConnectionState = state;
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// 刷新统计数据
  Future<void> _refreshStatistics() async {
    final results = await _storageService.getAllDetectionResults();
    _totalDetections = results.length;
    _todayDetections = await _storageService.getTodayDetectionCount();
    notifyListeners();
  }

  /// 公开刷新统计，供页面在检测完成后主动同步首页数据
  Future<void> refreshStatistics() async {
    await _refreshStatistics();
  }

  /// 设置主题模式
  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _storageService.setThemeMode(mode);
    notifyListeners();
  }

  /// 用户登录
  Future<bool> login({required String email, required String password}) async {
    final response =
        await _cloudService.login(email: email, password: password);
    if (response.isSuccess && response.data != null) {
      _currentUser = response.data;
      await _storageService.saveUser(_currentUser!);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 直接设置用户（用于外部登录成功后）
  Future<void> setUser(User user) async {
    _currentUser = user;
    await _storageService.saveUser(user);
    notifyListeners();
  }

  /// 用户登出
  Future<void> logout() async {
    await _cloudService.logout();
    await _storageService.clearUser();
    _currentUser = null;
    notifyListeners();
  }

  /// 添加检测结果
  Future<void> addDetectionResult(DetectionResult result) async {
    await _storageService.saveDetectionResult(result);
    await _refreshStatistics();
  }

  /// 同步数据到云端
  Future<bool> syncToCloud() async {
    if (!isLoggedIn) return false;

    final results = await _storageService.getAllDetectionResults();
    final unsyncedResults = results.where((r) => !r.isSynced).toList();

    if (unsyncedResults.isEmpty) return true;

    final response =
        await _cloudService.uploadDetectionResults(unsyncedResults);
    if (response.isSuccess) {
      // 更新同步状态
      for (final result in unsyncedResults) {
        await _storageService.saveDetectionResult(
          result.copyWith(isSynced: true),
        );
      }
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
