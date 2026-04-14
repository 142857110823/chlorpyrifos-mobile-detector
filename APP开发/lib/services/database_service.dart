import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

/// SQLite 数据库服务
/// 负责使用 SQLite 存储检测结果和相关数据
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  /// 数据库文件路径
  Future<String> get _databasePath async {
    final directory = await getApplicationDocumentsDirectory();
    return join(directory.path, 'pesticide_detector.db');
  }

  /// 初始化数据库
  Future<void> init() async {
    if (_database != null) return;

    final path = await _databasePath;
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 创建检测结果表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS detection_results (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            sample_name TEXT NOT NULL,
            sample_category TEXT,
            risk_level INTEGER NOT NULL,
            confidence REAL NOT NULL,
            spectral_data_id TEXT,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        ''');

        // 创建农药检测结果表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS detected_pesticides (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            detection_result_id TEXT NOT NULL,
            name TEXT NOT NULL,
            type INTEGER NOT NULL,
            concentration REAL NOT NULL,
            max_residue_limit REAL NOT NULL,
            unit TEXT NOT NULL,
            FOREIGN KEY (detection_result_id) REFERENCES detection_results(id) ON DELETE CASCADE
          );
        ''');

        // 创建光谱数据表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS spectral_data (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            wavelengths TEXT NOT NULL,
            intensity_values TEXT NOT NULL,
            device_id TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        ''');

        // 创建索引以提高查询性能
        await db.execute('CREATE INDEX IF NOT EXISTS idx_detection_results_timestamp ON detection_results(timestamp);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_detection_results_risk_level ON detection_results(risk_level);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_detected_pesticides_detection_result_id ON detected_pesticides(detection_result_id);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 数据库升级逻辑
      },
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// 保存检测结果
  Future<void> saveDetectionResult(DetectionResult result) async {
    await init();
    final db = _database!;

    await db.transaction((txn) async {
      // 插入检测结果
      await txn.insert(
        'detection_results',
        {
          'id': result.id,
          'timestamp': result.timestamp.toIso8601String(),
          'sample_name': result.sampleName,
          'sample_category': result.sampleCategory,
          'risk_level': result.riskLevel.index,
          'confidence': result.confidence,
          'spectral_data_id': result.spectralDataId,
          'is_synced': result.isSynced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 删除旧的农药检测结果
      await txn.delete(
        'detected_pesticides',
        where: 'detection_result_id = ?',
        whereArgs: [result.id],
      );

      // 插入新的农药检测结果
      for (final pesticide in result.detectedPesticides) {
        await txn.insert(
          'detected_pesticides',
          {
            'detection_result_id': result.id,
            'name': pesticide.name,
            'type': pesticide.type.index,
            'concentration': pesticide.concentration,
            'max_residue_limit': pesticide.maxResidueLimit,
            'unit': pesticide.unit,
          },
        );
      }
    });
  }

  /// 保存光谱数据
  Future<void> saveSpectralData(SpectralData data) async {
    await init();
    final db = _database!;

    await db.insert(
      'spectral_data',
      {
        'id': data.id,
        'timestamp': data.timestamp.toIso8601String(),
        'wavelengths': data.wavelengths.join(','),
        'intensity_values': data.intensityValues.join(','),
        'device_id': data.deviceId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有检测结果
  Future<List<DetectionResult>> getAllDetectionResults() async {
    await init();
    final db = _database!;

    final results = await db.query(
      'detection_results',
      orderBy: 'timestamp DESC',
    );

    final detectionResults = <DetectionResult>[];
    for (final row in results) {
      final result = await _buildDetectionResult(row);
      detectionResults.add(result);
    }

    return detectionResults;
  }

  /// 分页获取检测结果
  Future<List<DetectionResult>> getDetectionResultsPaged({
    required int offset,
    required int limit,
  }) async {
    await init();
    final db = _database!;

    final results = await db.query(
      'detection_results',
      orderBy: 'timestamp DESC',
      offset: offset,
      limit: limit,
    );

    final detectionResults = <DetectionResult>[];
    for (final row in results) {
      final result = await _buildDetectionResult(row);
      detectionResults.add(result);
    }

    return detectionResults;
  }

  /// 获取检测结果总数
  Future<int> getDetectionResultsCount() async {
    await init();
    final db = _database!;

    final result = await db.rawQuery('SELECT COUNT(*) FROM detection_results');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 根据ID获取检测结果
  Future<DetectionResult?> getDetectionResult(String id) async {
    await init();
    final db = _database!;

    final results = await db.query(
      'detection_results',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return await _buildDetectionResult(results.first);
  }

  /// 根据风险等级筛选检测结果
  Future<List<DetectionResult>> getDetectionResultsByRiskLevel(RiskLevel riskLevel) async {
    await init();
    final db = _database!;

    final results = await db.query(
      'detection_results',
      where: 'risk_level = ?',
      whereArgs: [riskLevel.index],
      orderBy: 'timestamp DESC',
    );

    final detectionResults = <DetectionResult>[];
    for (final row in results) {
      final result = await _buildDetectionResult(row);
      detectionResults.add(result);
    }

    return detectionResults;
  }

  /// 根据日期范围筛选检测结果
  Future<List<DetectionResult>> getDetectionResultsByDateRange(DateTime start, DateTime end) async {
    await init();
    final db = _database!;

    final results = await db.query(
      'detection_results',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    final detectionResults = <DetectionResult>[];
    for (final row in results) {
      final result = await _buildDetectionResult(row);
      detectionResults.add(result);
    }

    return detectionResults;
  }

  /// 获取今日检测数量
  Future<int> getTodayDetectionCount() async {
    await init();
    final db = _database!;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM detection_results WHERE timestamp >= ? AND timestamp <= ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 删除检测结果
  Future<void> deleteDetectionResult(String id) async {
    await init();
    final db = _database!;

    await db.transaction((txn) async {
      // 删除相关的农药检测结果
      await txn.delete(
        'detected_pesticides',
        where: 'detection_result_id = ?',
        whereArgs: [id],
      );

      // 删除检测结果
      await txn.delete(
        'detection_results',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// 清空检测结果
  Future<void> clearDetectionResults() async {
    await init();
    final db = _database!;

    await db.transaction((txn) async {
      await txn.delete('detected_pesticides');
      await txn.delete('detection_results');
    });
  }

  /// 获取光谱数据
  Future<SpectralData?> getSpectralData(String id) async {
    await init();
    final db = _database!;

    final results = await db.query(
      'spectral_data',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return SpectralData(
      id: row['id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      wavelengths: (row['wavelengths'] as String).split(',').map(double.parse).toList(),
      intensities: (row['intensity_values'] as String).split(',').map(double.parse).toList(),
      deviceId: row['device_id'] as String? ?? 'unknown',
    );
  }

  /// 删除光谱数据
  Future<void> deleteSpectralData(String id) async {
    await init();
    final db = _database!;

    await db.delete(
      'spectral_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 构建检测结果对象
  Future<DetectionResult> _buildDetectionResult(Map<String, dynamic> row) async {
    final db = _database!;

    // 获取相关的农药检测结果
    final pesticides = await db.query(
      'detected_pesticides',
      where: 'detection_result_id = ?',
      whereArgs: [row['id']],
    );

    final detectedPesticides = <DetectedPesticide>[];
    for (final pesticideRow in pesticides) {
      detectedPesticides.add(DetectedPesticide(
        name: pesticideRow['name'] as String,
        type: PesticideType.values[pesticideRow['type'] as int],
        concentration: pesticideRow['concentration'] as double,
        maxResidueLimit: pesticideRow['max_residue_limit'] as double,
        unit: pesticideRow['unit'] as String,
      ));
    }

    return DetectionResult(
      id: row['id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      sampleName: row['sample_name'] as String,
      sampleCategory: row['sample_category'] as String?,
      riskLevel: RiskLevel.values[row['risk_level'] as int],
      confidence: row['confidence'] as double,
      detectedPesticides: detectedPesticides,
      spectralDataId: row['spectral_data_id'] as String?,
      isSynced: (row['is_synced'] as int) == 1,
    );
  }

  /// 优化数据库
  Future<void> optimizeDatabase() async {
    await init();
    final db = _database!;

    // 执行 VACUUM 命令来优化数据库
    await db.execute('VACUUM');
  }

  /// 获取数据库大小
  Future<int> getDatabaseSize() async {
    final path = await _databasePath;
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
}
