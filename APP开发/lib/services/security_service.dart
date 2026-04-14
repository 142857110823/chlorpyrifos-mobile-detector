import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';

/// 安全服务
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _secureStorage = const FlutterSecureStorage();
  final _random = Random.secure();

  /// 初始化安全服务
  Future<void> initialize() async {
    // 检查是否需要生成密钥
    final hasKey = await _hasEncryptionKey();
    if (!hasKey) {
      await _generateEncryptionKey();
    }

    print('SecurityService initialized');
  }

  /// 检查是否存在加密密钥
  Future<bool> _hasEncryptionKey() async {
    final key = await _secureStorage.read(key: 'encryption_key');
    return key != null && key.isNotEmpty;
  }

  /// 生成加密密钥
  Future<void> _generateEncryptionKey() async {
    final key = _generateRandomKey(32); // 256-bit key
    await _secureStorage.write(
      key: 'encryption_key',
      value: base64.encode(key),
    );
    print('Encryption key generated');
  }

  /// 生成随机密钥
  Uint8List _generateRandomKey(int length) {
    final key = Uint8List(length);
    for (var i = 0; i < length; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }

  /// 获取加密密钥
  Future<Uint8List> _getEncryptionKey() async {
    final keyString = await _secureStorage.read(key: 'encryption_key');
    if (keyString == null) {
      await _generateEncryptionKey();
      return _getEncryptionKey();
    }
    return base64.decode(keyString);
  }

  // ==================== 数据加密 ====================

  /// 加密字符串
  Future<String> encryptString(String plaintext) async {
    try {
      final key = await _getEncryptionKey();
      final iv = _generateIV();
      final encrypted = _aesEncrypt(plaintext, key, iv);
      // 将IV和密文一起编码，以便解密时使用
      final combined = Uint8List(iv.length + encrypted.length);
      combined.setAll(0, iv);
      combined.setAll(iv.length, encrypted);
      return base64.encode(combined);
    } catch (e) {
      print('Encryption failed: $e');
      return plaintext; // 降级处理
    }
  }

  /// 解密字符串
  Future<String> decryptString(String ciphertext) async {
    try {
      final key = await _getEncryptionKey();
      final combined = base64.decode(ciphertext);
      // 提取IV和密文
      final iv = combined.sublist(0, 16); // AES block size is 16 bytes
      final encrypted = combined.sublist(16);
      return _aesDecrypt(encrypted, key, iv);
    } catch (e) {
      print('Decryption failed: $e');
      return ciphertext; // 降级处理
    }
  }

  /// 生成初始化向量 (IV)
  Uint8List _generateIV() {
    final iv = Uint8List(16); // AES block size is 16 bytes
    for (var i = 0; i < 16; i++) {
      iv[i] = _random.nextInt(256);
    }
    return iv;
  }

  /// AES加密实现（使用CBC模式 + PKCS7 padding）
  Uint8List _aesEncrypt(String plaintext, Uint8List key, Uint8List iv) {
    final encrypter = Encrypter(
      AES(Key(key), mode: AESMode.cbc, padding: 'PKCS7'),
    );
    final encrypted = encrypter.encryptBytes(
      utf8.encode(plaintext),
      iv: IV(iv),
    );
    return encrypted.bytes;
  }

  /// AES解密实现（使用CBC模式 + PKCS7 padding）
  String _aesDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    final encrypter = Encrypter(
      AES(Key(key), mode: AESMode.cbc, padding: 'PKCS7'),
    );
    final decrypted = encrypter.decryptBytes(
      Encrypted(ciphertext),
      iv: IV(iv),
    );
    return utf8.decode(decrypted);
  }

  // ==================== 安全存储 ====================

  /// 安全存储数据
  Future<void> secureWrite(String key, dynamic value) async {
    try {
      final jsonValue = json.encode(value);
      final encrypted = await encryptString(jsonValue);
      await _secureStorage.write(key: key, value: encrypted);
    } catch (e) {
      print('Secure write failed: $e');
    }
  }

  /// 安全读取数据
  Future<dynamic> secureRead(String key) async {
    try {
      final encrypted = await _secureStorage.read(key: key);
      if (encrypted == null) return null;
      final decrypted = await decryptString(encrypted);
      return json.decode(decrypted);
    } catch (e) {
      print('Secure read failed: $e');
      return null;
    }
  }

  /// 安全删除数据
  Future<void> secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      print('Secure delete failed: $e');
    }
  }

  // ==================== 权限管理 ====================

  /// 检查权限状态
  Future<Map<String, bool>> checkPermissions() async {
    final permissions = <String, bool>{};

    // 检查蓝牙权限
    try {
      // 实际应用中应使用permission_handler库
      permissions['bluetooth'] = true;
    } catch (e) {
      permissions['bluetooth'] = false;
    }

    // 检查存储权限
    try {
      // 实际应用中应使用permission_handler库
      permissions['storage'] = true;
    } catch (e) {
      permissions['storage'] = false;
    }

    return permissions;
  }

  /// 请求权限
  Future<bool> requestPermission(String permission) async {
    try {
      // 实际应用中应使用permission_handler库
      print('Requesting $permission permission');
      return true;
    } catch (e) {
      print('Permission request failed: $e');
      return false;
    }
  }

  // ==================== 安全审计 ====================

  /// 记录安全事件
  Future<void> logSecurityEvent(String eventType, {String? details}) async {
    try {
      final event = {
        'timestamp': DateTime.now().toIso8601String(),
        'eventType': eventType,
        'details': details,
        'deviceId': await _getDeviceId(),
      };

      // 读取现有日志
      final existingLogs = await secureRead('security_logs') as List? ?? [];
      existingLogs.add(event);

      // 限制日志大小
      if (existingLogs.length > 1000) {
        existingLogs.removeRange(0, existingLogs.length - 1000);
      }

      await secureWrite('security_logs', existingLogs);
      print('Security event logged: $eventType');
    } catch (e) {
      print('Security log failed: $e');
    }
  }

  /// 获取设备ID（匿名）
  Future<String> _getDeviceId() async {
    try {
      // 实际应用中应使用device_info_plus库
      return 'device_${_random.nextInt(1000000)}';
    } catch (e) {
      return 'device_unknown';
    }
  }

  /// 获取安全日志
  Future<List<dynamic>> getSecurityLogs() async {
    try {
      return await secureRead('security_logs') as List? ?? [];
    } catch (e) {
      print('Get security logs failed: $e');
      return [];
    }
  }

  /// 清除安全日志
  Future<void> clearSecurityLogs() async {
    try {
      await secureWrite('security_logs', []);
    } catch (e) {
      print('Clear security logs failed: $e');
    }
  }

  // ==================== 安全工具 ====================

  /// 生成随机密码
  String generateRandomPassword({int length = 12}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()_+';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  /// 验证密码强度
  int validatePasswordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*()_+]'))) score++;
    return score;
  }

  /// 释放资源
  void dispose() {
    // 清理资源
    print('SecurityService disposed');
  }
}
