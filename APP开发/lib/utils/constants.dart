import 'package:flutter/material.dart';

/// 应用常量定义
class AppConstants {
  AppConstants._();

  // 应用信息
  static const String appName = '毒死蜱检测';
  static const String appVersion = '1.0.0';

  // 颜色定义
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color primaryColorLight = Color(0xFF81C784);
  static const Color primaryColorDark = Color(0xFF388E3C);
  static const Color accentColor = Color(0xFF03A9F4);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color successColor = Color(0xFF4CAF50);

  // 风险等级颜色
  static const Color riskSafeColor = Color(0xFF4CAF50);
  static const Color riskLowColor = Color(0xFF8BC34A);
  static const Color riskMediumColor = Color(0xFFFF9800);
  static const Color riskHighColor = Color(0xFFFF5722);
  static const Color riskCriticalColor = Color(0xFFF44336);

  // 尺寸定义
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double borderRadius = 12.0;
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 16.0;

  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  // 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);

  // 蓝牙相关
  static const Duration bluetoothScanTimeout = Duration(seconds: 10);
  static const Duration bluetoothConnectTimeout = Duration(seconds: 15);
  static const int bluetoothReconnectAttempts = 3;

  // 检测相关
  static const int maxDetectionHistoryCount = 1000;
  static const int spectralDataPointsMin = 100;
  static const int spectralDataPointsMax = 4096;

  // API相关
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int apiRetryCount = 3;

  // 缓存相关
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100;
}

/// 果蔬类别
class ProduceCategory {
  static const List<Map<String, dynamic>> categories = [
    {'id': 'leafy', 'name': '叶菜类', 'icon': Icons.eco},
    {'id': 'root', 'name': '根茎类', 'icon': Icons.grass},
    {'id': 'fruit_veg', 'name': '茄果类', 'icon': Icons.local_florist},
    {'id': 'melon', 'name': '瓜类', 'icon': Icons.spa},
    {'id': 'bean', 'name': '豆类', 'icon': Icons.grain},
    {'id': 'mushroom', 'name': '菌菇类', 'icon': Icons.filter_vintage},
    {'id': 'fruit', 'name': '水果类', 'icon': Icons.apple},
    {'id': 'berry', 'name': '浆果类', 'icon': Icons.circle},
    {'id': 'citrus', 'name': '柑橘类', 'icon': Icons.brightness_5},
    {'id': 'other', 'name': '其他', 'icon': Icons.more_horiz},
  ];

  static String getCategoryName(String id) {
    return categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {'name': '未知'},
    )['name'];
  }
}

/// 蓝牙服务UUID
class BluetoothUUIDs {
  BluetoothUUIDs._();

  static const String primaryService = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String dataCharacteristic =
      '0000FFE1-0000-1000-8000-00805F9B34FB';
  static const String commandCharacteristic =
      '0000FFE2-0000-1000-8000-00805F9B34FB';
}

/// 路由名称
class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String home = '/';
  static const String detection = '/detection';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String deviceConnection = '/device-connection';
  static const String detectionDetail = '/detection-detail';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String register = '/register';
  static const String about = '/about';
  static const String spectralImageDetection = '/spectral-image-detection';
  static const String imagePreview = '/image-preview';
  static const String result = '/result';
}

/// SharedPreferences键名
class PreferenceKeys {
  PreferenceKeys._();

  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String isFirstLaunch = 'is_first_launch';
  static const String lastDeviceId = 'last_device_id';
  static const String autoConnect = 'auto_connect';
  static const String cloudSyncEnabled = 'cloud_sync_enabled';
  static const String notificationEnabled = 'notification_enabled';
  static const String modelVersion = 'model_version';
}
