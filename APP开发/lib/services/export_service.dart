import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

enum ExportFormat {
  csv,
  json,
}

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final DateFormat _fileNameFormat = DateFormat('yyyyMMdd_HHmmss');

  Future<ExportResult> exportDetectionResults({
    required List<DetectionResult> results,
    required ExportFormat format,
    String? customFileName,
  }) async {
    if (results.isEmpty) {
      return ExportResult(success: false, error: '没有可导出的记录');
    }

    if (kIsWeb) {
      return ExportResult(success: false, error: 'Web平台暂不支持导出功能');
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(directory.path, 'exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = _fileNameFormat.format(DateTime.now());
      final fileName = customFileName ?? 'detection_results_$timestamp';

      late final String filePath;
      late final String content;
      switch (format) {
        case ExportFormat.csv:
          content = _generateCsv(results);
          filePath = path.join(exportDir.path, '$fileName.csv');
          break;
        case ExportFormat.json:
          content = _generateJson(results);
          filePath = path.join(exportDir.path, '$fileName.json');
          break;
      }

      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: path.basename(filePath),
        fileSize: await file.length(),
      );
    } catch (e) {
      return ExportResult(success: false, error: 'Export failed: $e');
    }
  }

  String _generateCsv(List<DetectionResult> results) {
    final rows = <List<dynamic>>[];
    rows.add([
      'Timestamp',
      'Sample name',
      'Category',
      'Risk level',
      'Confidence (%)',
      'Pesticide',
      'Concentration (mg/kg)',
      'MRL (mg/kg)',
      'Over limit',
      'Over-limit ratio',
      'Device ID',
      'Spectral data ID',
      'Execution notes',
    ]);

    for (final result in results) {
      if (result.detectedPesticides.isEmpty) {
        rows.add([
          _dateFormat.format(result.timestamp),
          result.sampleName,
          result.sampleCategory ?? '',
          _riskLevelLabel(result.riskLevel),
          (result.confidence * 100).toStringAsFixed(1),
          'None detected',
          '-',
          '-',
          'No',
          '-',
          result.deviceId ?? '',
          result.spectralDataId ?? '',
          result.notes ?? '',
        ]);
        continue;
      }

      for (final pesticide in result.detectedPesticides) {
        rows.add([
          _dateFormat.format(result.timestamp),
          result.sampleName,
          result.sampleCategory ?? '',
          _riskLevelLabel(result.riskLevel),
          (result.confidence * 100).toStringAsFixed(1),
          pesticide.name,
          pesticide.concentration.toStringAsFixed(4),
          pesticide.maxResidueLimit.toStringAsFixed(4),
          pesticide.isOverLimit ? 'Yes' : 'No',
          pesticide.isOverLimit
              ? pesticide.overLimitRatio.toStringAsFixed(2)
              : '-',
          result.deviceId ?? '',
          result.spectralDataId ?? '',
          result.notes ?? '',
        ]);
      }
    }

    return rows
        .map((row) => row.map((cell) {
              final str = cell.toString();
              if (str.contains(',') ||
                  str.contains('"') ||
                  str.contains('\n')) {
                return '"${str.replaceAll('"', '""')}"';
              }
              return str;
            }).join(','))
        .join('\n');
  }

  String _generateJson(List<DetectionResult> results) {
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'totalCount': results.length,
      'results': results
          .map((result) => {
                'id': result.id,
                'timestamp': result.timestamp.toIso8601String(),
                'sampleName': result.sampleName,
                'sampleCategory': result.sampleCategory,
                'riskLevel': result.riskLevel.toString().split('.').last,
                'confidence': result.confidence,
                'detectedPesticides': result.detectedPesticides
                    .map((pesticide) => {
                          'name': pesticide.name,
                          'type': pesticide.type.toString().split('.').last,
                          'concentration': pesticide.concentration,
                          'maxResidueLimit': pesticide.maxResidueLimit,
                          'isOverLimit': pesticide.isOverLimit,
                          'overLimitRatio': pesticide.overLimitRatio,
                        })
                    .toList(),
                'deviceId': result.deviceId,
                'spectralDataId': result.spectralDataId,
                'notes': result.notes,
                'isSynced': result.isSynced,
              })
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<ExportResult> exportAndShare({
    required List<DetectionResult> results,
    required ExportFormat format,
  }) async {
    final exportResult =
        await exportDetectionResults(results: results, format: format);
    if (!exportResult.success || exportResult.filePath == null) {
      return exportResult;
    }

    try {
      await Share.shareXFiles(
        [XFile(exportResult.filePath!)],
        subject: 'Detection results export',
        text: 'Attached ${results.length} detection record(s).',
      );
      return exportResult;
    } catch (e) {
      return ExportResult(success: false, error: 'Share failed: $e');
    }
  }

  Future<void> shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      print('Share file failed: $e');
    }
  }

  Future<ExportResult> generateTextReport(DetectionResult result) async {
    return exportSingleReport(result);
  }

  Future<ExportResult> exportSingleReport(DetectionResult result) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportDir = Directory(path.join(directory.path, 'reports'));
      if (!await reportDir.exists()) {
        await reportDir.create(recursive: true);
      }

      final timestamp = _fileNameFormat.format(result.timestamp);
      final fileName = 'report_${result.sampleName}_$timestamp.txt';
      final filePath = path.join(reportDir.path, fileName);
      final content = _generateTextReport(result);

      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: await file.length(),
      );
    } catch (e) {
      return ExportResult(
          success: false, error: 'Report generation failed: $e');
    }
  }

  String _generateTextReport(DetectionResult result) {
    final buffer = StringBuffer();
    final divider = '=' * 60;

    buffer.writeln(divider);
    buffer.writeln('毒死蜱残留检测报告');
    buffer.writeln(divider);
    buffer.writeln();
    buffer.writeln('[基本信息]');
    buffer.writeln('检测时间: ${_dateFormat.format(result.timestamp)}');
    buffer.writeln('样品名称: ${result.sampleName}');
    buffer.writeln('样品类别: ${result.sampleCategory ?? '未指定'}');
    buffer.writeln('设备ID: ${result.deviceId ?? '未知'}');
    buffer.writeln('光谱数据ID: ${result.spectralDataId ?? '无'}');
    buffer.writeln();
    buffer.writeln('[检测概要]');
    buffer.writeln('风险等级: ${_riskLevelLabel(result.riskLevel)}');
    buffer.writeln('置信度: ${(result.confidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('是否合格: ${result.isQualified ? '合格' : '不合格'}');
    buffer.writeln();

    if (result.detectedPesticides.isEmpty) {
      buffer.writeln('检出毒死蜱: 无');
      buffer.writeln();
      buffer.writeln('[评估结论]');
      buffer.writeln('该样品未检出毒死蜱残留，可安全食用。');
    } else {
      buffer.writeln('[检出毒死蜱详情]');
      for (final pesticide in result.detectedPesticides) {
        buffer.writeln('- 名称: ${pesticide.name}');
        buffer.writeln('  类型: ${_pesticideTypeLabel(pesticide.type)}');
        buffer.writeln(
            '  浓度: ${pesticide.concentration.toStringAsFixed(4)} mg/kg');
        buffer.writeln(
            '  最大残留限量: ${pesticide.maxResidueLimit.toStringAsFixed(4)} mg/kg');
        buffer.writeln(
          '  是否超标: ${pesticide.isOverLimit ? '是 (${pesticide.overLimitRatio.toStringAsFixed(2)}倍)' : '否'}',
        );
      }
      buffer.writeln();
      buffer.writeln('[评估结论]');
      if (result.hasOverLimit) {
        buffer.writeln('警告: 检出毒死蜱残留超出安全限量标准。');
        buffer.writeln('1. 不建议直接食用。');
        buffer.writeln('2. 可尝试充分清洗、浸泡或去皮处理。');
        buffer.writeln('3. 如需食用请充分加热处理。');
      } else {
        buffer.writeln('检出毒死蜱残留但未超出安全限量标准。');
        buffer.writeln('建议食用前进行常规清洗处理。');
      }
    }

    if ((result.notes ?? '').trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('[执行信息]');
      for (final line in result.notes!.split('\n')) {
        if (line.trim().isNotEmpty) {
          buffer.writeln(line.trim());
        }
      }
    }

    buffer.writeln();
    buffer.writeln(divider);
    buffer.writeln('生成时间: ${_dateFormat.format(DateTime.now())}');
    buffer.writeln(divider);
    return buffer.toString();
  }

  String _riskLevelLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'Safe';
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }

  String _pesticideTypeLabel(PesticideType type) {
    switch (type) {
      case PesticideType.organophosphate:
        return 'Organophosphate';
      case PesticideType.carbamate:
        return 'Carbamate';
      case PesticideType.pyrethroid:
        return 'Pyrethroid';
      case PesticideType.neonicotinoid:
        return 'Neonicotinoid';
      case PesticideType.fungicide:
        return 'Fungicide';
      case PesticideType.herbicide:
        return 'Herbicide';
      case PesticideType.unknown:
        return 'Unknown';
      case PesticideType.phenylpyrazole:
        return 'Phenylpyrazole';
      case PesticideType.organochlorine:
        return 'Organochlorine';
      case PesticideType.other:
        return 'Other';
    }
  }

  Future<int> cleanExportFiles({int keepDays = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(directory.path, 'exports'));
      final reportDir = Directory(path.join(directory.path, 'reports'));
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      var deletedCount = 0;

      for (final dir in [exportDir, reportDir]) {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      return deletedCount;
    } catch (e) {
      print('Clean export files failed: $e');
      return 0;
    }
  }

  Future<List<ExportFileInfo>> getExportFiles() async {
    final files = <ExportFileInfo>[];

    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(directory.path, 'exports'));
      final reportDir = Directory(path.join(directory.path, 'reports'));

      for (final dir in [exportDir, reportDir]) {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final stat = await entity.stat();
          files.add(
            ExportFileInfo(
              path: entity.path,
              name: path.basename(entity.path),
              size: stat.size,
              createdAt: stat.modified,
            ),
          );
        }
      }

      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Load export file list failed: $e');
    }

    return files;
  }
}

class ExportResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? error;

  ExportResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.error,
  });

  bool get isSuccess => success;

  String get fileSizeText {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024)
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class ExportFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  ExportFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });

  String get sizeText {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
