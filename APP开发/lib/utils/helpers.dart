import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/detection_result.dart';

/// 辅助工具函数类
class Helpers {
  Helpers._();

  // ==================== 日期时间格式化 ====================

  /// 格式化日期时间
  static String formatDateTime(DateTime dateTime, {String? pattern}) {
    final formatter = DateFormat(pattern ?? 'yyyy-MM-dd HH:mm:ss');
    return formatter.format(dateTime);
  }

  /// 格式化日期
  static String formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  /// 格式化时间
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  /// 格式化为相对时间
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${difference.inDays ~/ 365}年前';
    } else if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // ==================== 数值格式化 ====================

  /// 格式化百分比
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }

  /// 格式化浓度值
  static String formatConcentration(double value, {String unit = 'mg/kg'}) {
    if (value < 0.001) {
      return '< 0.001 $unit';
    } else if (value < 0.01) {
      return '${value.toStringAsFixed(4)} $unit';
    } else if (value < 1) {
      return '${value.toStringAsFixed(3)} $unit';
    } else {
      return '${value.toStringAsFixed(2)} $unit';
    }
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // ==================== 风险等级相关 ====================

  /// 获取风险等级颜色
  static Color getRiskLevelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return const Color(0xFF4CAF50);
      case RiskLevel.low:
        return const Color(0xFF8BC34A);
      case RiskLevel.medium:
        return const Color(0xFFFF9800);
      case RiskLevel.high:
        return const Color(0xFFFF5722);
      case RiskLevel.critical:
        return const Color(0xFFF44336);
    }
  }

  /// 获取风险等级图标
  static IconData getRiskLevelIcon(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return Icons.check_circle;
      case RiskLevel.low:
        return Icons.info;
      case RiskLevel.medium:
        return Icons.warning;
      case RiskLevel.high:
        return Icons.error;
      case RiskLevel.critical:
        return Icons.dangerous;
    }
  }

  /// 获取风险等级描述
  static String getRiskLevelDescription(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return '安全';
      case RiskLevel.low:
        return '低风险';
      case RiskLevel.medium:
        return '中等风险';
      case RiskLevel.high:
        return '高风险';
      case RiskLevel.critical:
        return '严重超标';
    }
  }

  /// 获取风险等级建议
  static String getRiskLevelAdvice(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return '该样品未检出农药残留或残留量在安全范围内，可以放心食用。';
      case RiskLevel.low:
        return '该样品检出少量农药残留，但在安全限量内，建议清洗后食用。';
      case RiskLevel.medium:
        return '该样品农药残留量接近或略超安全限量，建议充分清洗或浸泡后食用。';
      case RiskLevel.high:
        return '该样品农药残留量明显超标，建议谨慎食用，可考虑去皮或长时间浸泡处理。';
      case RiskLevel.critical:
        return '该样品农药残留严重超标，强烈建议不要食用，以免对健康造成危害。';
    }
  }

  // ==================== 数据处理 ====================

  /// 生成唯一ID
  static String generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return '$timestamp$randomPart';
  }

  /// 计算数组平均值
  static double calculateMean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// 计算数组标准差
  static double calculateStdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = calculateMean(values);
    final squaredDiffs = values.map((x) => pow(x - mean, 2));
    return sqrt(squaredDiffs.reduce((a, b) => a + b) / values.length);
  }

  /// 查找数组中的峰值
  static List<int> findPeaks(List<double> data, {double threshold = 0.1}) {
    final peaks = <int>[];
    for (var i = 1; i < data.length - 1; i++) {
      if (data[i] > data[i - 1] &&
          data[i] > data[i + 1] &&
          data[i] > threshold) {
        peaks.add(i);
      }
    }
    return peaks;
  }

  // ==================== UI辅助 ====================

  /// 显示SnackBar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Color? backgroundColor;
    if (isError) {
      backgroundColor = Colors.red;
    } else if (isSuccess) {
      backgroundColor = Colors.green;
    } else if (isWarning) {
      backgroundColor = Colors.orange;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: Colors.white,
              )
            : null,
      ),
    );
  }

  /// 显示错误SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showSnackBar(
      context,
      message,
      isError: true,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 显示成功SnackBar
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    showSnackBar(
      context,
      message,
      isSuccess: true,
      duration: duration,
    );
  }

  /// 显示警告SnackBar
  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    showSnackBar(
      context,
      message,
      isWarning: true,
      duration: duration,
    );
  }

  /// 显示确认对话框
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDangerous
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示加载对话框
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message ?? '请稍候...'),
          ],
        ),
      ),
    );
  }

  /// 隐藏加载对话框
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // ==================== 触摸反馈 ====================

  /// 创建带涟漪效果的按钮
  static Widget createRippleButton({
    required Widget child,
    required VoidCallback onPressed,
    Color? splashColor,
    Color? highlightColor,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        splashColor: splashColor ?? Colors.grey.withValues(alpha: 0.3),
        highlightColor: highlightColor ?? Colors.grey.withValues(alpha: 0.1),
        borderRadius: borderRadius,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  /// 创建带动画效果的按钮
  static Widget createAnimatedButton({
    required Widget child,
    required VoidCallback onPressed,
    double scaleFactor = 0.95,
    Duration animationDuration = const Duration(milliseconds: 150),
    Color? splashColor,
    Color? highlightColor,
    BorderRadius? borderRadius,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        // 按下时的动画
      },
      onTapUp: (_) {
        // 抬起时的动画
      },
      onTapCancel: () {
        // 取消时的动画
      },
      onTap: onPressed,
      child: createRippleButton(
        child: child,
        onPressed: onPressed,
        splashColor: splashColor,
        highlightColor: highlightColor,
        borderRadius: borderRadius,
      ),
    );
  }

  /// 创建带缩放效果的卡片
  static Widget createAnimatedCard({
    required Widget child,
    VoidCallback? onTap,
    double scaleFactor = 0.98,
    Duration animationDuration = const Duration(milliseconds: 200),
    Color? splashColor,
    Color? highlightColor,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Material(
      elevation: 2,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor ?? Colors.grey.withValues(alpha: 0.3),
        highlightColor: highlightColor ?? Colors.grey.withValues(alpha: 0.1),
        borderRadius: borderRadius,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  // ==================== 友好的错误提示 ====================

  /// 显示友好的错误提示
  static void showFriendlyError({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  /// 显示网络错误提示
  static void showNetworkError(BuildContext context) {
    showFriendlyError(
      context: context,
      title: '网络连接错误',
      message: '请检查您的网络连接后重试。',
      actionLabel: '重试',
      onAction: () {
        // 可以在这里添加重试逻辑
      },
    );
  }

  /// 显示设备连接错误提示
  static void showDeviceConnectionError(BuildContext context) {
    showFriendlyError(
      context: context,
      title: '设备连接失败',
      message: '无法连接到检测设备，请确保设备已开启并在蓝牙范围内。',
      actionLabel: '重新搜索',
      onAction: () {
        // 可以在这里添加重新搜索设备的逻辑
      },
    );
  }

  /// 显示模型加载错误提示
  static void showModelLoadingError(BuildContext context) {
    showFriendlyError(
      context: context,
      title: '模型加载失败',
      message: '无法加载AI模型，系统将使用备用分析方法。',
      actionLabel: '检查模型',
      onAction: () {
        // 可以在这里添加检查模型的逻辑
      },
    );
  }

  /// 显示操作成功提示
  static void showSuccessMessage({
    required BuildContext context,
    required String title,
    required String message,
    String actionLabel = '确定',
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction?.call();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// 显示信息提示
  static void showInfoMessage({
    required BuildContext context,
    required String title,
    required String message,
    String actionLabel = '我知道了',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// 显示进度对话框
  static void showProgressDialog({
    required BuildContext context,
    required String title,
    required String message,
    double? progress,
    bool isIndeterminate = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            isIndeterminate
                ? const CircularProgressIndicator()
                : LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }

  /// 显示Toast提示
  static void showToast({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: _getToastColor(type),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  /// 获取Toast颜色
  static Color _getToastColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.error:
        return Colors.red;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.info:
      default:
        return Colors.blue;
    }
  }

  // ==================== 验证相关 ====================

  /// 验证邮箱格式
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// 验证手机号格式
  static bool isValidPhone(String phone) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  /// 验证密码强度
  static PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 6) {
      return PasswordStrength.weak;
    }

    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }
}

/// Toast类型枚举
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// 密码强度枚举
enum PasswordStrength {
  weak,
  medium,
  strong,
}
