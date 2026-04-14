import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

/// 日志级别
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  critical,
}

/// 日志条目
class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? tag;
  final dynamic data;
  final StackTrace? stackTrace;

  LogEntry({
    required this.level,
    required this.message,
    this.tag,
    this.data,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'tag': tag,
      'data': data,
      'stackTrace': stackTrace?.toString(),
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'],
      tag: json['tag'],
      data: json['data'],
      stackTrace: json['stackTrace'] != null
          ? StackTrace.fromString(json['stackTrace'])
          : null,
    );
  }

  @override
  String toString() {
    final timestampStr = timestamp.toIso8601String();
    final levelStr = level.name.toUpperCase();
    final tagStr = tag != null ? ' [$tag]' : '';
    return '$timestampStr [$levelStr]$tagStr: $message${data != null ? ' $data' : ''}';
  }
}

/// 日志服务
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final _logController = StreamController<LogEntry>.broadcast();
  final _logHistory = <LogEntry>[];
  final _maxHistorySize = 500;

  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get logHistory => List.unmodifiable(_logHistory);

  bool _isInitialized = false;
  File? _logFile;
  Timer? _flushTimer;

  /// 初始化日志服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化日志文件
    await _initializeLogFile();

    // 启动定期刷新日志到文件
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _flushLogsToFile();
    });

    _isInitialized = true;
    print('LoggingService initialized');
  }

  /// 初始化日志文件
  Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File('${logDir.path}/app_$timestamp.log');
      await _logFile?.create();
      print('Log file created: ${_logFile?.path}');
    } catch (e) {
      print('Failed to initialize log file: $e');
    }
  }

  /// 通用日志记录方法
  void log(String message,
      {LogLevel level = LogLevel.info, String? tag, dynamic data}) {
    _log(level, message, tag: tag, data: data);
  }

  /// 记录详细日志
  void verbose(String message, {String? tag, dynamic data}) {
    _log(LogLevel.verbose, message, tag: tag, data: data);
  }

  /// 记录调试日志
  void debug(String message, {String? tag, dynamic data}) {
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  /// 记录信息日志
  void info(String message, {String? tag, dynamic data}) {
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  /// 记录警告日志
  void warning(String message,
      {String? tag, dynamic data, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message,
        tag: tag, data: data, stackTrace: stackTrace);
  }

  /// 记录错误日志
  void error(String message,
      {String? tag, dynamic data, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message,
        tag: tag,
        data: data,
        stackTrace: stackTrace ?? (error is Error ? error.stackTrace : null));
  }

  /// 记录严重错误日志
  void critical(String message,
      {String? tag, dynamic data, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, message,
        tag: tag,
        data: data,
        stackTrace: stackTrace ?? (error is Error ? error.stackTrace : null));
  }

  /// 内部日志记录方法
  void _log(
    LogLevel level,
    String message, {
    String? tag,
    dynamic data,
    StackTrace? stackTrace,
  }) {
    final logEntry = LogEntry(
      level: level,
      message: message,
      tag: tag,
      data: data,
      stackTrace: stackTrace,
    );

    // 添加到历史记录
    _logHistory.add(logEntry);
    if (_logHistory.length > _maxHistorySize) {
      _logHistory.removeAt(0);
    }

    // 发送到流
    _logController.add(logEntry);

    // 打印到控制台（根据日志级别）
    if (level.index >= LogLevel.info.index) {
      print(logEntry.toString());
    } else if (kDebugMode) {
      print(logEntry.toString());
    }
  }

  /// 刷新日志到文件
  Future<void> _flushLogsToFile() async {
    if (!_isInitialized || _logFile == null) return;

    try {
      final logsToWrite = _logHistory.where((log) => log.timestamp
          .isAfter(DateTime.now().subtract(const Duration(minutes: 5))));
      if (logsToWrite.isNotEmpty) {
        final logLines =
            logsToWrite.map((log) => json.encode(log.toJson())).join('\n');
        await _logFile?.writeAsString('$logLines\n', mode: FileMode.append);
      }
    } catch (e) {
      print('Failed to flush logs to file: $e');
    }
  }

  /// 获取日志统计
  Map<LogLevel, int> getLogStats() {
    final stats = <LogLevel, int>{};
    for (final level in LogLevel.values) {
      stats[level] = _logHistory.where((log) => log.level == level).length;
    }
    return stats;
  }

  /// 按标签获取日志
  List<LogEntry> getLogsByTag(String tag) {
    return _logHistory.where((log) => log.tag == tag).toList();
  }

  /// 按级别获取日志
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logHistory.where((log) => log.level == level).toList();
  }

  /// 按时间范围获取日志
  List<LogEntry> getLogsByTimeRange(DateTime start, DateTime end) {
    return _logHistory
        .where((log) =>
            log.timestamp.isAfter(start) && log.timestamp.isBefore(end))
        .toList();
  }

  /// 清除日志历史
  void clearHistory() {
    _logHistory.clear();
  }

  /// 导出日志
  Future<File?> exportLogs() async {
    if (!_isInitialized) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/exports');
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final exportFile = File('${exportDir.path}/logs_$timestamp.json');

      final logJson = _logHistory.map((log) => log.toJson()).toList();
      await exportFile
          .writeAsString(const JsonEncoder.withIndent('  ').convert(logJson));

      return exportFile;
    } catch (e) {
      error('Failed to export logs', error: e);
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _logController.close();
    _flushTimer?.cancel();
    _isInitialized = false;
  }
}

/// 日志扩展方法
extension LoggingExtensions on Object {
  void logVerbose(String message, {String? tag, dynamic data}) {
    LoggingService().verbose(message, tag: tag, data: data);
  }

  void logDebug(String message, {String? tag, dynamic data}) {
    LoggingService().debug(message, tag: tag, data: data);
  }

  void logInfo(String message, {String? tag, dynamic data}) {
    LoggingService().info(message, tag: tag, data: data);
  }

  void logWarning(String message,
      {String? tag, dynamic data, StackTrace? stackTrace}) {
    LoggingService()
        .warning(message, tag: tag, data: data, stackTrace: stackTrace);
  }

  void logError(String message,
      {String? tag, dynamic data, dynamic error, StackTrace? stackTrace}) {
    LoggingService().error(message,
        tag: tag, data: data, error: error, stackTrace: stackTrace);
  }

  void logCritical(String message,
      {String? tag, dynamic data, dynamic error, StackTrace? stackTrace}) {
    LoggingService().critical(message,
        tag: tag, data: data, error: error, stackTrace: stackTrace);
  }
}

/// 调试模式检查
bool get kDebugMode {
  bool isDebug = false;
  assert(isDebug = true);
  return isDebug;
}
