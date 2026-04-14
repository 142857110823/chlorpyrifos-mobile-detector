import 'package:hive/hive.dart';

part 'detection_result.g.dart';

/// 风险等级枚举
@HiveType(typeId: 1)
enum RiskLevel {
  @HiveField(0)
  safe, // 安全
  @HiveField(1)
  low, // 低风险
  @HiveField(2)
  medium, // 中等风险
  @HiveField(3)
  high, // 高风险
  @HiveField(4)
  critical, // 严重超标
}

/// 农药类型
/// 支持多种农药类型的检测
@HiveType(typeId: 2)
enum PesticideType {
  @HiveField(0)
  organophosphate, // 有机磷类

  @HiveField(1)
  carbamate, // 氨基甲酸酯类

  @HiveField(2)
  pyrethroid, // 拟除虫菊酯类

  @HiveField(3)
  neonicotinoid, // 新烟碱类

  @HiveField(4)
  fungicide, // 杀菌剂

  @HiveField(5)
  herbicide, // 除草剂

  @HiveField(6)
  unknown, // 未知类型

  @HiveField(7)
  phenylpyrazole, // 苯基吡唑类

  @HiveField(8)
  organochlorine, // 有机氯类

  @HiveField(9)
  other, // 其他类型
}

/// 检测到的农药残留信息
@HiveType(typeId: 3)
class DetectedPesticide {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final PesticideType type;

  @HiveField(2)
  final double concentration;

  @HiveField(3)
  final double maxResidueLimit;

  @HiveField(4)
  final String unit;

  DetectedPesticide({
    required this.name,
    required this.type,
    required this.concentration,
    required this.maxResidueLimit,
    this.unit = 'mg/kg',
  });

  /// 是否超标
  bool get isOverLimit => concentration > maxResidueLimit;

  /// 超标倍数
  double get overLimitRatio =>
      maxResidueLimit > 0 ? concentration / maxResidueLimit : 0;

  factory DetectedPesticide.fromJson(Map<String, dynamic> json) {
    return DetectedPesticide(
      name: json['name'] as String,
      type: PesticideType.values[json['type'] as int],
      concentration: (json['concentration'] as num).toDouble(),
      maxResidueLimit: (json['maxResidueLimit'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'mg/kg',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.index,
      'concentration': concentration,
      'maxResidueLimit': maxResidueLimit,
      'unit': unit,
    };
  }
}

/// 检测结果模型
@HiveType(typeId: 4)
class DetectionResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String sampleName;

  @HiveField(3)
  final String? sampleCategory;

  @HiveField(4)
  final RiskLevel riskLevel;

  @HiveField(5)
  final double confidence;

  @HiveField(6)
  final List<DetectedPesticide> detectedPesticides;

  @HiveField(7)
  final String? spectralDataId;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String? imagePath;

  @HiveField(10)
  final bool isSynced;

  @HiveField(11)
  final String? deviceId;

  /// 样品照片路径 (相机拍摄的样品参考照片)
  @HiveField(12)
  final String? samplePhotoPath;

  DetectionResult({
    required this.id,
    required this.timestamp,
    required this.sampleName,
    this.sampleCategory,
    required this.riskLevel,
    required this.confidence,
    required this.detectedPesticides,
    this.spectralDataId,
    this.notes,
    this.imagePath,
    this.isSynced = false,
    this.deviceId,
    this.samplePhotoPath,
  });

  /// 获取风险等级描述
  String get riskLevelDescription {
    switch (riskLevel) {
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

  /// 获取风险等级颜色代码
  int get riskLevelColorValue {
    switch (riskLevel) {
      case RiskLevel.safe:
        return 0xFF4CAF50; // 绿色
      case RiskLevel.low:
        return 0xFF8BC34A; // 浅绿色
      case RiskLevel.medium:
        return 0xFFFF9800; // 橙色
      case RiskLevel.high:
        return 0xFFFF5722; // 深橙色
      case RiskLevel.critical:
        return 0xFFF44336; // 红色
    }
  }

  /// 是否有农药残留
  bool get hasPesticides => detectedPesticides.isNotEmpty;

  /// 是否有超标农药
  bool get hasOverLimitPesticides =>
      detectedPesticides.any((p) => p.isOverLimit);

  /// 是否有超标 (别名)
  bool get hasOverLimit => hasOverLimitPesticides;

  /// 超标农药数量
  int get overLimitCount =>
      detectedPesticides.where((p) => p.isOverLimit).length;

  // ============ PDF报告服务兼容属性 ============

  /// 样品类型（用于PDF报告）
  String get sampleType => sampleCategory ?? '未分类';

  /// 是否合格（用于PDF报告）
  bool get isQualified => !hasOverLimitPesticides;

  /// 风险等级字符串（用于PDF报告）
  String get riskLevelString {
    switch (riskLevel) {
      case RiskLevel.safe:
        return 'safe';
      case RiskLevel.low:
        return 'low';
      case RiskLevel.medium:
        return 'medium';
      case RiskLevel.high:
        return 'high';
      case RiskLevel.critical:
        return 'high';
    }
  }

  /// 农药检测结果列表（用于PDF报告）
  List<PesticideResult> get pesticideResults => detectedPesticides
      .map((p) => PesticideResult(
            name: p.name,
            concentration: p.concentration,
            limit: p.maxResidueLimit,
            exceedsLimit: p.isOverLimit,
          ))
      .toList();

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sampleName: json['sampleName'] as String,
      sampleCategory: json['sampleCategory'] as String?,
      riskLevel: RiskLevel.values[json['riskLevel'] as int],
      confidence: (json['confidence'] as num).toDouble(),
      detectedPesticides: (json['detectedPesticides'] as List<dynamic>)
          .map((e) => DetectedPesticide.fromJson(e as Map<String, dynamic>))
          .toList(),
      spectralDataId: json['spectralDataId'] as String?,
      notes: json['notes'] as String?,
      imagePath: json['imagePath'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      deviceId: json['deviceId'] as String?,
      samplePhotoPath: json['samplePhotoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'sampleName': sampleName,
      'sampleCategory': sampleCategory,
      'riskLevel': riskLevel.index,
      'confidence': confidence,
      'detectedPesticides': detectedPesticides.map((e) => e.toJson()).toList(),
      'spectralDataId': spectralDataId,
      'notes': notes,
      'imagePath': imagePath,
      'isSynced': isSynced,
      'deviceId': deviceId,
      'samplePhotoPath': samplePhotoPath,
    };
  }

  /// 创建副本并更新部分字段
  DetectionResult copyWith({
    String? id,
    DateTime? timestamp,
    String? sampleName,
    String? sampleCategory,
    RiskLevel? riskLevel,
    double? confidence,
    List<DetectedPesticide>? detectedPesticides,
    String? spectralDataId,
    String? notes,
    String? imagePath,
    bool? isSynced,
    String? deviceId,
    String? samplePhotoPath,
  }) {
    return DetectionResult(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      sampleName: sampleName ?? this.sampleName,
      sampleCategory: sampleCategory ?? this.sampleCategory,
      riskLevel: riskLevel ?? this.riskLevel,
      confidence: confidence ?? this.confidence,
      detectedPesticides: detectedPesticides ?? this.detectedPesticides,
      spectralDataId: spectralDataId ?? this.spectralDataId,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      isSynced: isSynced ?? this.isSynced,
      deviceId: deviceId ?? this.deviceId,
      samplePhotoPath: samplePhotoPath ?? this.samplePhotoPath,
    );
  }

  @override
  String toString() {
    return 'DetectionResult(id: $id, sample: $sampleName, risk: $riskLevelDescription)';
  }
}

/// 农药检测结果（用于PDF报告）
class PesticideResult {
  final String name;
  final double concentration;
  final double limit;
  final bool exceedsLimit;

  PesticideResult({
    required this.name,
    required this.concentration,
    required this.limit,
    required this.exceedsLimit,
  });
}
