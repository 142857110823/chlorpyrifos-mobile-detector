import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/spectral_file.dart';
import 'spectral_file_service.dart';

/// 数据导入服务
/// 仅支持 .dx (JCAMP-DX) 和 .spc 格式的毒死蜱光谱数据导入
class DataImportService {
  static final DataImportService _instance = DataImportService._internal();
  factory DataImportService() => _instance;
  DataImportService._internal();

  final SpectralFileService _spectralFileService = SpectralFileService();

  /// 导入结果
  ImportedData? _lastImportedData;
  ImportedData? get lastImportedData => _lastImportedData;

  /// 选择并导入文件
  Future<ImportResult> pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dx', 'jdx', 'jcamp', 'spc'],
        allowMultiple: false,
        withData: true, // Web平台需要bytes
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final file = result.files.first;
      final fileName = file.name;
      final ext = fileName.split('.').last.toLowerCase();

      // 检查格式是否支持
      if (!_spectralFileService.isSupportedFormat(fileName)) {
        return ImportResult.error(
            _spectralFileService.unsupportedFormatMessage);
      }

      // 获取文件字节数据
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        bytes = file.bytes;
      }

      if (bytes == null || bytes.isEmpty) {
        return ImportResult.error('无法读取文件内容');
      }

      return await importFileFromBytes(bytes, fileName);
    } catch (e) {
      return ImportResult.error('选择文件失败: $e');
    }
  }

  /// 从字节数据导入文件
  Future<ImportResult> importFileFromBytes(
      Uint8List bytes, String fileName) async {
    try {
      // 解析光谱文件
      final fileData = _spectralFileService.parseFile(bytes, fileName);

      if (fileData == null) {
        return ImportResult.error('文件解析失败，请确认文件格式正确');
      }

      // 验证数据
      final validation = _spectralFileService.validateFileData(fileData);
      if (!validation.isValid) {
        return ImportResult.error('数据验证失败: ${validation.issues.join('; ')}');
      }

      // 转换为SpectralData
      final spectralData = _spectralFileService.convertToSpectralData(fileData);

      final format = _spectralFileService.getFormat(fileName)!;
      final importedData = ImportedData(
        fileName: fileName,
        filePath: fileName, // Web平台无真实路径
        format: format == SpectralFileFormat.dx
            ? ImportFormat.dx
            : ImportFormat.spc,
        headers: ['波长 (${fileData.xUnits})', '强度 (${fileData.yUnits})'],
        rows: _generatePreviewRows(fileData),
        rowCount: fileData.dataPointCount,
        columnCount: 2,
        spectralData: spectralData,
        importTime: DateTime.now(),
        spectralFileData: fileData,
        validationWarnings: validation.warnings,
      );

      _lastImportedData = importedData;
      return ImportResult.success(importedData);
    } catch (e) {
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 导入指定文件路径 (非Web平台)
  Future<ImportResult> importFile(String filePath, String extension) async {
    try {
      // 检查格式
      if (!_spectralFileService.isSupportedFormat('file.$extension')) {
        return ImportResult.error(
            _spectralFileService.unsupportedFormatMessage);
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult.error('文件不存在');
      }

      final bytes = await file.readAsBytes();
      final fileName = filePath.split(Platform.pathSeparator).last;
      return await importFileFromBytes(bytes, fileName);
    } catch (e) {
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 生成预览行数据
  List<List<String>> _generatePreviewRows(SpectralFileData fileData) {
    final rows = <List<String>>[];
    final count = fileData.dataPointCount < 10 ? fileData.dataPointCount : 10;
    for (int i = 0; i < count; i++) {
      rows.add([
        fileData.wavelengths[i].toStringAsFixed(4),
        fileData.intensities[i].toStringAsFixed(6),
      ]);
    }
    return rows;
  }

  /// 验证导入的数据是否有效
  ValidationResult validateImportedData(ImportedData data) {
    final issues = <String>[];

    if (data.rowCount == 0) {
      issues.add('数据为空，没有检测到有效数据点');
    }

    if (data.spectralData == null) {
      issues.add('无法解析为光谱数据格式');
    } else {
      final spectral = data.spectralData!;
      if (spectral.wavelengths.length < 10) {
        issues.add('数据点过少（${spectral.wavelengths.length}个），建议至少100个数据点');
      }
    }

    // 添加导入时的警告
    if (data.validationWarnings.isNotEmpty) {
      for (final warning in data.validationWarnings) {
        issues.add(warning);
      }
    }

    return ValidationResult(
      isValid:
          issues.isEmpty || (issues.length == data.validationWarnings.length),
      issues: issues,
      dataQuality: issues.isEmpty
          ? DataQuality.good
          : (issues.length <= 1 ? DataQuality.acceptable : DataQuality.poor),
    );
  }

  /// 清除导入的数据
  void clearImportedData() {
    _lastImportedData = null;
  }
}

/// 导入结果
class ImportResult {
  final bool isSuccess;
  final bool isCancelled;
  final ImportedData? data;
  final String? error;

  ImportResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.data,
    this.error,
  });

  factory ImportResult.success(ImportedData data) {
    return ImportResult._(isSuccess: true, isCancelled: false, data: data);
  }

  factory ImportResult.error(String message) {
    return ImportResult._(isSuccess: false, isCancelled: false, error: message);
  }

  factory ImportResult.cancelled() {
    return ImportResult._(isSuccess: false, isCancelled: true);
  }
}

/// 导入的数据
class ImportedData {
  final String fileName;
  final String filePath;
  final ImportFormat format;
  final List<String> headers;
  final List<List<String>> rows;
  final int rowCount;
  final int columnCount;
  final SpectralData? spectralData;
  final DateTime importTime;
  final String? sheetName;
  final SpectralFileData? spectralFileData;
  final List<String> validationWarnings;

  ImportedData({
    required this.fileName,
    required this.filePath,
    required this.format,
    required this.headers,
    required this.rows,
    required this.rowCount,
    required this.columnCount,
    this.spectralData,
    required this.importTime,
    this.sheetName,
    this.spectralFileData,
    this.validationWarnings = const [],
  });

  /// 获取预览数据（前10行）
  List<List<String>> get previewRows => rows.take(10).toList();

  /// 是否包含有效的光谱数据
  bool get hasValidSpectralData => spectralData != null;

  /// 获取数据摘要
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('文件: $fileName');
    buffer.writeln('格式: ${format.displayName}');
    buffer.writeln('数据: $rowCount 个数据点');
    if (spectralData != null) {
      buffer.writeln(
          '波长范围: ${spectralData!.wavelengths.first.toStringAsFixed(1)} - ${spectralData!.wavelengths.last.toStringAsFixed(1)}');
    }
    if (spectralFileData != null) {
      buffer.writeln(
          '光谱类型: ${_spectralTypeDisplayName(spectralFileData!.spectralType)}');
      if (spectralFileData!.casNumber != null) {
        buffer.writeln('CAS号: ${spectralFileData!.casNumber}');
      }
    }
    return buffer.toString();
  }

  String _spectralTypeDisplayName(SpectralType type) {
    switch (type) {
      case SpectralType.uv:
        return '紫外-可见光谱';
      case SpectralType.ir:
        return '红外光谱';
      case SpectralType.raman:
        return '拉曼光谱';
      case SpectralType.unknown:
        return '未知类型';
    }
  }
}

/// 导入格式 - 仅支持 .dx 和 .spc
enum ImportFormat {
  dx,
  spc;

  String get displayName {
    switch (this) {
      case ImportFormat.dx:
        return 'JCAMP-DX (.dx)';
      case ImportFormat.spc:
        return 'SPC (.spc)';
    }
  }
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final List<String> issues;
  final DataQuality dataQuality;

  ValidationResult({
    required this.isValid,
    required this.issues,
    required this.dataQuality,
  });
}

/// 数据质量
enum DataQuality {
  good,
  acceptable,
  poor;

  String get displayName {
    switch (this) {
      case DataQuality.good:
        return '优秀';
      case DataQuality.acceptable:
        return '可接受';
      case DataQuality.poor:
        return '较差';
    }
  }
}
