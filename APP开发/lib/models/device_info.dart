import 'package:hive/hive.dart';

part 'device_info.g.dart';

/// 设备连接状态
@HiveType(typeId: 5)
enum DeviceConnectionState {
  @HiveField(0)
  disconnected,   // 未连接
  @HiveField(1)
  connecting,     // 连接中
  @HiveField(2)
  connected,      // 已连接
  @HiveField(3)
  error,          // 连接错误
}

/// 多光谱检测设备信息
@HiveType(typeId: 6)
class DeviceInfo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? macAddress;

  @HiveField(3)
  final String? firmwareVersion;

  @HiveField(4)
  final int? batteryLevel;

  @HiveField(5)
  final DateTime? lastConnectedAt;

  @HiveField(6)
  final bool isFavorite;

  @HiveField(7)
  final Map<String, dynamic>? capabilities;

  DeviceInfo({
    required this.id,
    required this.name,
    this.macAddress,
    this.firmwareVersion,
    this.batteryLevel,
    this.lastConnectedAt,
    this.isFavorite = false,
    this.capabilities,
  });

  /// 获取电池状态描述
  String get batteryStatusDescription {
    if (batteryLevel == null) return '未知';
    if (batteryLevel! > 80) return '电量充足';
    if (batteryLevel! > 50) return '电量良好';
    if (batteryLevel! > 20) return '电量偏低';
    return '电量不足';
  }

  /// 是否支持多光谱检测
  bool get supportsMultispectral {
    return capabilities?['multispectral'] == true;
  }

  /// 支持的波长范围
  (double, double)? get wavelengthRange {
    final range = capabilities?['wavelengthRange'];
    if (range is List && range.length == 2) {
      return ((range[0] as num).toDouble(), (range[1] as num).toDouble());
    }
    return null;
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      macAddress: json['macAddress'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      batteryLevel: json['batteryLevel'] as int?,
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      capabilities: json['capabilities'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'macAddress': macAddress,
      'firmwareVersion': firmwareVersion,
      'batteryLevel': batteryLevel,
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'capabilities': capabilities,
    };
  }

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? macAddress,
    String? firmwareVersion,
    int? batteryLevel,
    DateTime? lastConnectedAt,
    bool? isFavorite,
    Map<String, dynamic>? capabilities,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  @override
  String toString() {
    return 'DeviceInfo(id: $id, name: $name, battery: $batteryLevel%)';
  }
}
