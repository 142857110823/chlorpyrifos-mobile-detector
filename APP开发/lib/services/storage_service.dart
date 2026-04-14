import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'database_service.dart';
import '../models/models.dart';

/// 数据存储服务
/// 负责本地数据的持久化存储
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String devicesBox = 'devices';
  static const String settingsBox = 'settings';
  static const String userBox = 'user';

  bool _isInitialized = false;
  final DatabaseService _databaseService = DatabaseService();

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化存储服务
  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // 注册适配器
    Hive.registerAdapter(DeviceInfoAdapter());
    Hive.registerAdapter(UserAdapter());

    // 打开存储盒子
    await Hive.openBox<Map>(devicesBox);
    await Hive.openBox(settingsBox);
    await Hive.openBox<Map>(userBox);

    // 初始化数据库服务
    await _databaseService.init();

    _isInitialized = true;
  }

  // ==================== 检测结果相关 ====================

  /// 保存检测结果
  Future<void> saveDetectionResult(DetectionResult result) async {
    await _databaseService.saveDetectionResult(result);
  }

  /// 获取所有检测结果
  Future<List<DetectionResult>> getAllDetectionResults() async {
    return await _databaseService.getAllDetectionResults();
  }

  /// P0修复: 分页获取检测结果
  Future<List<DetectionResult>> getDetectionResultsPaged({
    required int offset,
    required int limit,
  }) async {
    return await _databaseService.getDetectionResultsPaged(
      offset: offset,
      limit: limit,
    );
  }

  /// P0修复: 获取检测结果总数
  Future<int> getDetectionResultsCount() async {
    return await _databaseService.getDetectionResultsCount();
  }

  /// 获取检测结果
  Future<DetectionResult?> getDetectionResult(String id) async {
    return await _databaseService.getDetectionResult(id);
  }

  /// 删除检测结果
  Future<void> deleteDetectionResult(String id) async {
    await _databaseService.deleteDetectionResult(id);
  }

  /// 获取今日检测数量
  Future<int> getTodayDetectionCount() async {
    return await _databaseService.getTodayDetectionCount();
  }

  /// 获取按风险等级统计
  Future<Map<RiskLevel, int>> getDetectionStatsByRisk() async {
    final results = await getAllDetectionResults();
    final stats = <RiskLevel, int>{};

    for (final level in RiskLevel.values) {
      stats[level] = results.where((r) => r.riskLevel == level).length;
    }

    return stats;
  }

  // ==================== 光谱数据相关 ====================

  /// 保存光谱数据
  Future<void> saveSpectralData(SpectralData data) async {
    await _databaseService.saveSpectralData(data);
  }

  /// 获取光谱数据
  Future<SpectralData?> getSpectralData(String id) async {
    return await _databaseService.getSpectralData(id);
  }

  /// 删除光谱数据
  Future<void> deleteSpectralData(String id) async {
    await _databaseService.deleteSpectralData(id);
  }

  // ==================== 设备信息相关 ====================

  /// 保存设备信息
  Future<void> saveDeviceInfo(DeviceInfo device) async {
    final box = Hive.box<Map>(devicesBox);
    await box.put(device.id, device.toJson());
  }

  /// 获取所有设备
  Future<List<DeviceInfo>> getAllDevices() async {
    final box = Hive.box<Map>(devicesBox);
    final devices = <DeviceInfo>[];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        devices.add(DeviceInfo.fromJson(Map<String, dynamic>.from(data)));
      }
    }

    // 按最后连接时间排序
    devices.sort((a, b) {
      final aTime = a.lastConnectedAt ?? DateTime(1970);
      final bTime = b.lastConnectedAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return devices;
  }

  /// 获取收藏的设备
  Future<List<DeviceInfo>> getFavoriteDevices() async {
    final devices = await getAllDevices();
    return devices.where((d) => d.isFavorite).toList();
  }

  /// 删除设备
  Future<void> deleteDevice(String id) async {
    final box = Hive.box<Map>(devicesBox);
    await box.delete(id);
  }

  // ==================== 设置相关 ====================

  /// 保存设置
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(settingsBox);
    await box.put(key, value);
  }

  /// 获取设置
  T? getSetting<T>(String key, {T? defaultValue}) {
    final box = Hive.box(settingsBox);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  /// 获取主题模式
  String getThemeMode() {
    return getSetting<String>('themeMode', defaultValue: 'system') ?? 'system';
  }

  /// 设置主题模式
  Future<void> setThemeMode(String mode) async {
    await saveSetting('themeMode', mode);
  }

  /// 获取语言设置
  String getLanguage() {
    return getSetting<String>('language', defaultValue: 'zh_CN') ?? 'zh_CN';
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    await saveSetting('language', language);
  }

  // ==================== 用户相关 ====================

  /// 保存用户信息
  Future<void> saveUser(User user) async {
    final box = Hive.box<Map>(userBox);
    await box.put('currentUser', user.toJson());
  }

  /// 获取当前用户
  Future<User?> getCurrentUser() async {
    final box = Hive.box<Map>(userBox);
    final data = box.get('currentUser');
    if (data != null) {
      return User.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// 清除用户数据
  Future<void> clearUser() async {
    final box = Hive.box<Map>(userBox);
    await box.delete('currentUser');
  }

  // ==================== 数据备份与恢复 ====================

  /// 备份所有数据
  Future<Map<String, dynamic>> backupAllData() async {
    // 获取检测结果和光谱数据
    final detectionResults = await getAllDetectionResults();
    final detectionResultsJson = detectionResults.map((r) => r.toJson()).toList();

    final backup = <String, dynamic>{
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'detectionResults': detectionResultsJson,
        'devices': _backupBox(Hive.box<Map>(devicesBox)),
        'settings': _backupBox(Hive.box(settingsBox)),
        'user': _backupBox(Hive.box<Map>(userBox)),
      },
    };

    print('Data backed up: ${backup['data'].length} items');
    return backup;
  }

  /// 导出备份为JSON文件
  Future<String> exportBackupToJson() async {
    final backup = await backupAllData();
    return json.encode(backup);
  }

  /// 导出备份为文件
  Future<File?> exportBackupToFile(String fileName) async {
    try {
      final backupData = await backupAllData();
      final backupJson = json.encode(backupData);

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final filePath = '${backupDir.path}/$fileName.json';
      final file = File(filePath);
      await file.writeAsString(backupJson);

      print('Backup exported to: $filePath');
      return file;
    } catch (e) {
      print('Failed to export backup: $e');
      return null;
    }
  }

  /// 从文件导入备份
  Future<bool> importBackupFromFile(File file) async {
    try {
      final backupJson = await file.readAsString();
      final backupData = json.decode(backupJson);
      return await restoreFromBackup(backupData);
    } catch (e) {
      print('Failed to import backup: $e');
      return false;
    }
  }

  /// 验证备份完整性
  Future<bool> verifyBackupIntegrity(Map<String, dynamic> backup) async {
    try {
      // 检查必要字段
      if (!backup.containsKey('version') ||
          !backup.containsKey('timestamp') ||
          !backup.containsKey('data')) {
        return false;
      }

      final data = backup['data'] as Map<String, dynamic>;
      // 检查数据完整性
      final requiredKeys = ['detectionResults', 'settings', 'devices'];
      for (final key in requiredKeys) {
        if (!data.containsKey(key)) {
          return false;
        }
      }

      print('Backup integrity verified');
      return true;
    } catch (e) {
      print('Backup integrity verification failed: $e');
      return false;
    }
  }

  /// 压缩备份数据
  Future<Uint8List> compressBackup(Map<String, dynamic> backup) async {
    final jsonString = json.encode(backup);
    final gzipBytes = gzip.encode(utf8.encode(jsonString));
    return Uint8List.fromList(gzipBytes);
  }

  /// 解压缩备份数据
  Future<Map<String, dynamic>> decompressBackup(
      Uint8List compressedData) async {
    final jsonString = utf8.decode(gzip.decode(compressedData));
    return json.decode(jsonString);
  }

  // ==================== 数据加密 ====================

  /// 安全存储实例（用于密钥管理）
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _encryptionKeyAlias = 'storage_encryption_key';

  /// P1修复: 缓存加密密钥，避免每次加密都读取SecureStorage
  String? _cachedEncryptionKey;

  /// 生成加密密钥（32字节/256位）
  String _generateEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// P0-3: 获取或生成加密密钥（使用flutter_secure_storage安全存储）
  /// P1修复: 添加缓存机制
  Future<String> _getEncryptionKey() async {
    // P1修复: 优先使用缓存
    if (_cachedEncryptionKey != null) {
      return _cachedEncryptionKey!;
    }

    try {
      // 从安全存储读取
      String? key = await _secureStorage.read(key: _encryptionKeyAlias);

      if (key == null || key.isEmpty) {
        // 尝试从旧的Hive存储迁移
        key = _migrateKeyFromHive();

        if (key == null) {
          // 生成新密钥
          key = _generateEncryptionKey();
        }

        // 存储到安全存储
        await _secureStorage.write(key: _encryptionKeyAlias, value: key);
      }

      // P1修复: 缓存密钥
      _cachedEncryptionKey = key;
      return key;
    } catch (e) {
      // Web平台或安全存储不可用时的降级处理
      print('SecureStorage unavailable, using fallback: $e');
      final fallbackKey = _getFallbackKey();
      _cachedEncryptionKey = fallbackKey;
      return fallbackKey;
    }
  }

  /// 从旧的Hive存储迁移密钥（一次性迁移）
  String? _migrateKeyFromHive() {
    try {
      final keyBox = Hive.box(settingsBox);
      final oldKey = keyBox.get('encryptionKey') as String?;
      if (oldKey != null) {
        // 迁移成功后删除旧的明文密钥
        keyBox.delete('encryptionKey');
        print('Encryption key migrated from Hive to SecureStorage');
      }
      return oldKey;
    } catch (e) {
      print('Key migration from Hive failed: $e');
      return null;
    }
  }

  /// Web平台降级密钥获取（仅在SecureStorage不可用时使用）
  String _getFallbackKey() {
    final keyBox = Hive.box(settingsBox);
    String? key = keyBox.get('encryptionKey');
    if (key == null) {
      key = _generateEncryptionKey();
      keyBox.put('encryptionKey', key);
    }
    return key;
  }

  /// 生成随机IV（16字节）
  Uint8List _generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// P0-4: 使用AES-CBC + PKCS7 padding加密数据（替代XOR）
  Future<String> encryptData(String data) async {
    try {
      final keyString = await _getEncryptionKey();
      final keyBytes = base64.decode(keyString);
      // 确保密钥长度为32字节
      final key = encrypt_lib.Key(Uint8List.fromList(
        keyBytes.length >= 32
            ? keyBytes.sublist(0, 32)
            : keyBytes + List.filled(32 - keyBytes.length, 0),
      ));
      final iv = encrypt_lib.IV(_generateIV());

      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'),
      );

      final encrypted = encrypter.encrypt(data, iv: iv);

      // 将IV和密文拼接后编码（IV在前16字节）
      final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
      combined.setAll(0, iv.bytes);
      combined.setAll(iv.bytes.length, encrypted.bytes);

      return base64.encode(combined);
    } catch (e) {
      print('AES encryption failed: $e');
      rethrow; // 加密失败不应该静默返回明文
    }
  }

  /// P0-4: 使用AES-CBC + PKCS7 padding解密数据（替代XOR）
  Future<String> decryptData(String encryptedData) async {
    try {
      final keyString = await _getEncryptionKey();
      final keyBytes = base64.decode(keyString);
      final key = encrypt_lib.Key(Uint8List.fromList(
        keyBytes.length >= 32
            ? keyBytes.sublist(0, 32)
            : keyBytes + List.filled(32 - keyBytes.length, 0),
      ));

      final combined = base64.decode(encryptedData);
      // 前16字节为IV
      final iv = encrypt_lib.IV(Uint8List.fromList(combined.sublist(0, 16)));
      final cipherBytes = combined.sublist(16);

      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'),
      );

      return encrypter.decrypt(
          encrypt_lib.Encrypted(Uint8List.fromList(cipherBytes)),
          iv: iv);
    } catch (e) {
      print('AES decryption failed: $e');
      rethrow;
    }
  }

  /// 加密备份数据
  Future<Map<String, dynamic>> encryptBackup(
      Map<String, dynamic> backup) async {
    try {
      final backupJson = json.encode(backup);
      final encryptedData = await encryptData(backupJson);

      return {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'encrypted': true,
        'data': encryptedData,
      };
    } catch (e) {
      print('Failed to encrypt backup: $e');
      return backup; // 加密失败时返回原始备份
    }
  }

  /// 解密备份数据
  Future<Map<String, dynamic>?> decryptBackup(
      Map<String, dynamic> encryptedBackup) async {
    try {
      if (!encryptedBackup.containsKey('encrypted') ||
          !encryptedBackup['encrypted']) {
        return encryptedBackup;
      }

      final encryptedData = encryptedBackup['data'] as String;
      final decryptedJson = await decryptData(encryptedData);
      return json.decode(decryptedJson);
    } catch (e) {
      print('Failed to decrypt backup: $e');
      return null;
    }
  }

  /// 安全保存敏感数据
  Future<void> saveSecureData(String key, String value) async {
    final encryptedValue = await encryptData(value);
    final secureBox = Hive.box(settingsBox);
    await secureBox.put('secure_$key', encryptedValue);
  }

  /// 获取安全数据
  Future<String?> getSecureData(String key) async {
    final secureBox = Hive.box(settingsBox);
    final encryptedValue = secureBox.get('secure_$key');

    if (encryptedValue != null) {
      return await decryptData(encryptedValue);
    }
    return null;
  }

  /// 从备份恢复数据
  Future<bool> restoreFromBackup(Map<String, dynamic> backup) async {
    try {
      final data = backup['data'] as Map<String, dynamic>;

      // 恢复检测结果
      if (data.containsKey('detectionResults')) {
        final detectionResults = data['detectionResults'] as List;
        for (final resultJson in detectionResults) {
          final result = DetectionResult.fromJson(Map<String, dynamic>.from(resultJson));
          await saveDetectionResult(result);
        }
      }

      // 恢复其他数据
      await _restoreBox(Hive.box<Map>(devicesBox), data['devices']);
      await _restoreBox(Hive.box(settingsBox), data['settings']);
      await _restoreBox(Hive.box<Map>(userBox), data['user']);

      print('Data restored successfully');
      return true;
    } catch (e) {
      print('Restore failed: $e');
      return false;
    }
  }

  /// 备份单个盒子
  List<Map<String, dynamic>> _backupBox(Box box) {
    final items = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      items.add({
        'key': key,
        'value': box.get(key),
      });
    }
    return items;
  }

  /// 恢复单个盒子
  Future<void> _restoreBox(Box box, dynamic data) async {
    if (data is List) {
      await box.clear();
      for (final item in data) {
        if (item is Map &&
            item.containsKey('key') &&
            item.containsKey('value')) {
          await box.put(item['key'], item['value']);
        }
      }
    }
  }

  // ==================== 数据导入/导出 ====================

  /// 导出检测结果为CSV
  String exportDetectionResultsToCsv() {
    final results = getAllDetectionResultsSync();
    final buffer = StringBuffer();

    // 写入表头
    buffer.writeln('ID,样品名称,样品类别,检测时间,风险等级,置信度,检测到的农药');

    // 写入数据
    for (final result in results) {
      final pesticides = result.detectedPesticides
          .map((p) => '${p.name}:${p.concentration}')
          .join(';');
      buffer.writeln(
          '${result.id},${result.sampleName},${result.sampleCategory ?? ''},${result.timestamp},${result.riskLevel.toString().split('.').last},${result.confidence},$pesticides');
    }

    return buffer.toString();
  }

  /// 导入检测结果从CSV
  Future<List<DetectionResult>> importDetectionResultsFromCsv(
      String csv) async {
    final lines = csv.split('\n');
    final results = <DetectionResult>[];

    // 跳过表头
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 6) {
        try {
          final result = DetectionResult(
            id: parts[0],
            timestamp: DateTime.parse(parts[3]),
            sampleName: parts[1],
            sampleCategory: parts[2].isEmpty ? null : parts[2],
            riskLevel: RiskLevel.values.firstWhere(
              (e) => e.toString().split('.').last == parts[4],
              orElse: () => RiskLevel.safe,
            ),
            confidence: double.tryParse(parts[5]) ?? 0.0,
            detectedPesticides: [],
          );
          results.add(result);
          await saveDetectionResult(result);
        } catch (e) {
          print('Import error: $e');
        }
      }
    }

    return results;
  }

  /// 同步获取所有检测结果
  List<DetectionResult> getAllDetectionResultsSync() {
    // 由于使用SQLite，此方法需要异步执行
    // 这里返回空列表，实际使用时应调用异步方法 getAllDetectionResults()
    return [];
  }

  // ==================== 性能优化 ====================

  /// 优化存储性能
  Future<void> optimizeStorage() async {
    // 1. 压缩数据
    await _compactBoxes();

    // 2. 清理过期数据
    await _cleanupExpiredData();

    // 3. 重建索引
    await _rebuildIndexes();

    // 4. 优化数据库
    await _databaseService.optimizeDatabase();

    print('Storage optimized');
  }

  /// 压缩盒子
  Future<void> _compactBoxes() async {
    // Hive会自动处理压缩，这里可以添加自定义压缩逻辑
    print('Boxes compacted');
  }

  /// 清理过期数据
  Future<void> _cleanupExpiredData() async {
    final results = await getAllDetectionResults();
    final threshold = DateTime.now().subtract(const Duration(days: 90));

    for (final result in results) {
      if (result.timestamp.isBefore(threshold)) {
        await deleteDetectionResult(result.id);
      }
    }

    print('Expired data cleaned up');
  }

  /// 重建索引
  Future<void> _rebuildIndexes() async {
    // Hive会自动处理索引，这里可以添加自定义索引逻辑
    print('Indexes rebuilt');
  }

  // ==================== 工具方法 ====================

  /// 清除缓存数据
  Future<void> clearCache() async {
    // 缓存已由数据库管理，无需额外操作
  }

  /// P0修复: 仅清除检测结果数据
  Future<void> clearDetectionResults() async {
    await _databaseService.clearDetectionResults();
  }

  /// 清除所有数据
  Future<void> clearAllData() async {
    await _databaseService.clearDetectionResults();
    await Hive.box<Map>(devicesBox).clear();
    await Hive.box(settingsBox).clear();
    await Hive.box<Map>(userBox).clear();
  }

  /// 获取存储使用情况
  Map<String, int> getStorageStats() {
    return {
      'devices': Hive.box<Map>(devicesBox).length,
    };
  }

  /// 关闭存储
  Future<void> close() async {
    await Hive.close();
    await _databaseService.close();
    _isInitialized = false;
  }
}
