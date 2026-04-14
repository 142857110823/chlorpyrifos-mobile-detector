import 'dart:convert';
import 'dart:typed_data';

import '../models/spectral_data.dart';
import '../models/spectral_file.dart';

/// 光谱文件解析服务
/// 支持 JCAMP-DX (.dx) 和 SPC (.spc) 格式的解析和验证
class SpectralFileService {
  static final SpectralFileService _instance = SpectralFileService._internal();
  factory SpectralFileService() => _instance;
  SpectralFileService._internal();

  /// 根据文件扩展名判断格式
  SpectralFileFormat? getFormat(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dx':
      case 'jdx':
      case 'jcamp':
        return SpectralFileFormat.dx;
      case 'spc':
        return SpectralFileFormat.spc;
      default:
        return null;
    }
  }

  /// 检查文件格式是否支持
  bool isSupportedFormat(String fileName) {
    return getFormat(fileName) != null;
  }

  /// 获取不支持格式的错误提示
  String get unsupportedFormatMessage => '不支持该文件格式，仅支持.dx和.spc格式';

  /// 解析光谱文件 (自动检测格式)
  /// [bytes] 文件的原始字节数据
  /// [fileName] 文件名 (用于判断格式)
  SpectralFileData? parseFile(Uint8List bytes, String fileName) {
    final format = getFormat(fileName);
    if (format == null) {
      return null;
    }

    switch (format) {
      case SpectralFileFormat.dx:
        return parseDxFile(bytes);
      case SpectralFileFormat.spc:
        return parseSpcFile(bytes);
    }
  }

  /// 验证光谱文件数据
  SpectralFileValidation validateFileData(SpectralFileData? data) {
    if (data == null) {
      return SpectralFileValidation.invalid(['文件解析失败']);
    }

    final issues = <String>[];
    final warnings = <String>[];

    // 检查数据点
    if (data.wavelengths.isEmpty || data.intensities.isEmpty) {
      issues.add('光谱数据为空');
    }

    if (data.wavelengths.length != data.intensities.length) {
      issues.add('波长和强度数据点数不一致');
    }

    // 检查CAS号
    if (data.casNumber != null && data.casNumber != '2921-88-2') {
      warnings.add('CAS号不是毒死蜱(2921-88-2)，检测结果可能不准确');
    }

    if (data.dataPointCount < 10) {
      issues.add('数据点数过少(${data.dataPointCount}个)，至少需要10个数据点');
    }

    if (issues.isEmpty) {
      return SpectralFileValidation.valid(warnings: warnings);
    }
    return SpectralFileValidation(
        isValid: false, issues: issues, warnings: warnings);
  }

  /// 将 SpectralFileData 转换为 SpectralData (应用内使用的模型)
  SpectralData convertToSpectralData(SpectralFileData fileData) {
    return SpectralData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      wavelengths: fileData.wavelengths,
      intensities: fileData.intensities,
      deviceId: 'spectral-file-import',
      timestamp: DateTime.now(),
    );
  }

  // ============ JCAMP-DX (.dx) 解析 ============

  /// 解析 JCAMP-DX 格式文件
  SpectralFileData? parseDxFile(Uint8List bytes) {
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      return _parseDxContent(content);
    } catch (e) {
      print('JCAMP-DX解析失败: $e');
      return null;
    }
  }

  /// 解析 JCAMP-DX 文件内容
  SpectralFileData? _parseDxContent(String content) {
    final labels = <String, String>{};
    final dataLines = <String>[];
    bool inDataSection = false;

    final lines = content.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('##')) {
        // 解析标签
        inDataSection = false;
        final eqIndex = line.indexOf('=');
        if (eqIndex > 0) {
          final key = line.substring(2, eqIndex).trim().toUpperCase();
          final value = line.substring(eqIndex + 1).trim();

          labels[key] = value;

          // 检查是否是数据段开始标记
          if (key == 'XYDATA' || key == 'XYPOINTS' || key == 'PEAK TABLE') {
            inDataSection = true;
          }
        }
      } else if (inDataSection) {
        // 收集数据行
        if (!line.startsWith('##')) {
          dataLines.add(line);
        }
      }
    }

    // 提取元数据
    final title = labels['TITLE'] ?? '未知光谱';
    final casNumber = labels['CAS REGISTRY NO'] ?? labels['CAS NUMBER'];
    final xUnits = labels['XUNITS'] ?? 'nm';
    final yUnits = labels['YUNITS'] ?? 'ABSORBANCE';
    final firstX = double.tryParse(labels['FIRSTX'] ?? '') ?? 0;
    final lastX = double.tryParse(labels['LASTX'] ?? '') ?? 0;
    final nPoints = int.tryParse(labels['NPOINTS'] ?? '') ?? 0;
    final dataType = (labels['DATA TYPE'] ?? '').toUpperCase();

    // 判断光谱类型
    SpectralType spectralType;
    if (dataType.contains('UV') ||
        dataType.contains('ULTRAVIOLET') ||
        xUnits.toUpperCase().contains('NM') ||
        xUnits.toUpperCase().contains('NANOMETER')) {
      spectralType = SpectralType.uv;
    } else if (dataType.contains('INFRARED') ||
        dataType.contains('IR') ||
        xUnits.toUpperCase().contains('1/CM') ||
        xUnits.toUpperCase().contains('CM')) {
      spectralType = SpectralType.ir;
    } else if (dataType.contains('RAMAN')) {
      spectralType = SpectralType.raman;
    } else {
      spectralType = SpectralType.unknown;
    }

    // 解析数据段
    final wavelengths = <double>[];
    final intensities = <double>[];

    if (dataLines.isNotEmpty) {
      _parseAffnData(
          dataLines, wavelengths, intensities, firstX, lastX, nPoints);
    } else if (nPoints > 0 && firstX != 0 && lastX != 0) {
      // 没有数据段但有元数据，生成空数据占位
      // 实际应用中这种情况不应该发生
    }

    // 如果解析失败，检查是否可以用等间距生成X值
    if (wavelengths.isEmpty && nPoints > 0 && firstX != lastX) {
      final step = (lastX - firstX) / (nPoints - 1);
      for (int i = 0; i < nPoints; i++) {
        wavelengths.add(firstX + i * step);
      }
    }

    if (wavelengths.isEmpty || intensities.isEmpty) {
      return null;
    }

    // 构建元数据
    final metadata = <String, String>{};
    for (final entry in labels.entries) {
      if (entry.key != 'XYDATA' && entry.key != 'END') {
        metadata[entry.key] = entry.value;
      }
    }

    return SpectralFileData(
      title: title,
      casNumber: casNumber,
      spectralType: spectralType,
      format: SpectralFileFormat.dx,
      wavelengths: wavelengths,
      intensities: intensities,
      xUnits: xUnits,
      yUnits: yUnits,
      metadata: metadata,
    );
  }

  /// 解析 AFFN 简单格式数据 (空格分隔的 X Y 值)
  void _parseAffnData(
    List<String> dataLines,
    List<double> wavelengths,
    List<double> intensities,
    double firstX,
    double lastX,
    int nPoints,
  ) {
    // 从文件头计算步长
    final double headerStep =
        (nPoints > 1 && firstX != lastX) ? (lastX - firstX) / (nPoints - 1) : 0;

    for (final line in dataLines) {
      // 分割数字，支持空格、制表符、逗号分隔
      final parts =
          line.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();

      if (parts.length >= 2) {
        // 第一个数字是X值，后续是Y值
        final x = double.tryParse(parts[0]);
        if (x != null) {
          for (int i = 1; i < parts.length; i++) {
            final y = double.tryParse(parts[i]);
            if (y != null) {
              if (i == 1) {
                wavelengths.add(x);
              } else {
                // 后续Y值按步长递增
                if (headerStep != 0) {
                  wavelengths.add(x + (i - 1) * headerStep);
                } else if (wavelengths.length >= 2) {
                  final estimatedStep = wavelengths[1] - wavelengths[0];
                  wavelengths.add(x + (i - 1) * estimatedStep);
                } else {
                  wavelengths.add(x + (i - 1));
                }
              }
              intensities.add(y);
            }
          }
        }
      } else if (parts.length == 1) {
        // 只有Y值的情况
        final y = double.tryParse(parts[0]);
        if (y != null) {
          intensities.add(y);
        }
      }
    }

    // 如果只有Y值没有X值，用索引作为X
    if (wavelengths.isEmpty && intensities.isNotEmpty) {
      for (int i = 0; i < intensities.length; i++) {
        wavelengths.add(i.toDouble());
      }
    }
  }

  // ============ SPC (.spc) 解析 ============

  /// 解析 SPC 格式文件 (二进制)
  SpectralFileData? parseSpcFile(Uint8List bytes) {
    try {
      return _parseSpcBinary(bytes);
    } catch (e) {
      print('SPC解析失败: $e');
      return null;
    }
  }

  /// 解析 SPC 二进制数据
  SpectralFileData? _parseSpcBinary(Uint8List bytes) {
    if (bytes.length < 512) {
      print('SPC文件太小，头部需要至少512字节');
      return null;
    }

    final byteData = ByteData.view(bytes.buffer);

    // 解析文件头
    final ftflgs = bytes[0]; // 文件类型标志
    final fversn = bytes[1]; // 版本号 (0x4B=新格式, 0x4D=旧格式)
    final fexper = bytes[2]; // 实验类型

    // 数据点数 (32位整数, 小端序)
    final fnpts = byteData.getInt32(4, Endian.little);

    // 起始和结束X值 (双精度浮点, 小端序)
    final ffirst = byteData.getFloat64(8, Endian.little);
    final flast = byteData.getFloat64(16, Endian.little);

    // X轴类型和Y轴类型
    final fxtype = bytes[30];
    final fytype = bytes[31];

    if (fnpts <= 0 || fnpts > 100000) {
      print('SPC数据点数异常: $fnpts');
      return null;
    }

    // 计算X值数组 (等间距)
    final wavelengths = <double>[];
    if (fnpts > 1) {
      final step = (flast - ffirst) / (fnpts - 1);
      for (int i = 0; i < fnpts; i++) {
        wavelengths.add(ffirst + i * step);
      }
    } else {
      wavelengths.add(ffirst);
    }

    // 读取Y值数据
    final intensities = <double>[];
    final dataOffset = 512; // SPC头部固定512字节

    // 检查数据是否足够
    final hasXYFlag = (ftflgs & 0x80) != 0; // TXYXYS flag
    final yDataOffset = hasXYFlag ? dataOffset + fnpts * 4 : dataOffset;

    if (bytes.length < dataOffset + fnpts * 4) {
      print('SPC文件数据不完整');
      return null;
    }

    // 读取Y值 (32位浮点数, 小端序)
    for (int i = 0; i < fnpts; i++) {
      final offset = dataOffset + i * 4;
      if (offset + 4 <= bytes.length) {
        final y = byteData.getFloat32(offset, Endian.little);
        intensities.add(y.toDouble());
      }
    }

    if (wavelengths.isEmpty || intensities.isEmpty) {
      return null;
    }

    // 确定X轴单位
    String xUnits;
    SpectralType spectralType;
    switch (fxtype) {
      case 1: // Wavenumber (cm-1)
        xUnits = '1/CM';
        spectralType = SpectralType.ir;
        break;
      case 3: // Nanometers
        xUnits = 'nm';
        spectralType = SpectralType.uv;
        break;
      case 14: // Raman shift
        xUnits = '1/CM';
        spectralType = SpectralType.raman;
        break;
      default:
        xUnits = 'nm';
        spectralType = SpectralType.unknown;
    }

    // 确定Y轴单位
    String yUnits;
    switch (fytype) {
      case 1:
        yUnits = 'ABSORBANCE';
        break;
      case 2:
        yUnits = 'TRANSMITTANCE';
        break;
      case 4:
        yUnits = 'COUNTS';
        break;
      default:
        yUnits = 'ARBITRARY';
    }

    // 构建元数据
    final metadata = <String, String>{
      'FORMAT': 'SPC',
      'VERSION': fversn == 0x4B ? 'New (0x4B)' : 'Old (0x4D)',
      'EXPERIMENT_TYPE': fexper.toString(),
      'NPOINTS': fnpts.toString(),
      'FIRST_X': ffirst.toStringAsFixed(4),
      'LAST_X': flast.toStringAsFixed(4),
    };

    // 尝试从SPC日志中提取标题和CAS号
    String title = '毒死蜱光谱数据';
    String? casNumber;

    // SPC文件日志区域从偏移544开始 (如果存在)
    if (bytes.length > 544) {
      try {
        // 尝试读取日志文本
        final logStart = 544;
        final logEnd =
            bytes.length < logStart + 256 ? bytes.length : logStart + 256;
        final logBytes = bytes.sublist(logStart, logEnd);
        final logText = utf8.decode(logBytes, allowMalformed: true);

        if (logText.contains('2921-88-2')) {
          casNumber = '2921-88-2';
        }
        if (logText.contains('chlorpyrifos') || logText.contains('毒死蜱')) {
          title = '毒死蜱光谱数据';
          casNumber ??= '2921-88-2';
        }
      } catch (_) {
        // 日志解析失败不影响主数据
      }
    }

    return SpectralFileData(
      title: title,
      casNumber: casNumber,
      spectralType: spectralType,
      format: SpectralFileFormat.spc,
      wavelengths: wavelengths,
      intensities: intensities,
      xUnits: xUnits,
      yUnits: yUnits,
      metadata: metadata,
    );
  }

  /// 生成 JCAMP-DX 格式的毒死蜱光谱文件模板
  String generateDxTemplate({
    required List<double> wavelengths,
    required List<double> intensities,
    SpectralType spectralType = SpectralType.uv,
    String instrumentInfo = '手机外接多光谱附件',
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    buffer.writeln('##TITLE= 毒死蜱光谱数据');
    buffer.writeln('##JCAMP-DX= 5.01');
    buffer.writeln('##DATA TYPE= ${_spectralTypeToString(spectralType)}');
    buffer.writeln('##CAS REGISTRY NO= 2921-88-2');
    buffer.writeln('##MOLFORM= C9H11Cl3NO3PS');
    buffer.writeln('##MW= 350.59');
    buffer.writeln('##SOURCE REFERENCE= 农药残留检测APP');
    buffer.writeln('##SPECTROMETER/DATA SYSTEM= $instrumentInfo');
    buffer.writeln(
        '##DATE= ${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}');
    buffer.writeln(
        '##TIME= ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}');

    if (spectralType == SpectralType.uv) {
      buffer.writeln('##XUNITS= NANOMETERS');
      buffer.writeln('##YUNITS= ABSORBANCE');
    } else if (spectralType == SpectralType.ir) {
      buffer.writeln('##XUNITS= 1/CM');
      buffer.writeln('##YUNITS= ABSORBANCE');
    } else if (spectralType == SpectralType.raman) {
      buffer.writeln('##XUNITS= 1/CM');
      buffer.writeln('##YUNITS= ARBITRARY UNITS');
    }

    buffer.writeln('##FIRSTX= ${wavelengths.first}');
    buffer.writeln('##LASTX= ${wavelengths.last}');
    buffer.writeln('##NPOINTS= ${wavelengths.length}');
    buffer.writeln('##RESOLUTION= 1.0');

    // 毒死蜱特征峰标注
    if (spectralType == SpectralType.uv) {
      buffer.writeln('##.CHLORPYRIFOS UV PEAKS= 228nm, 293nm');
    } else if (spectralType == SpectralType.ir) {
      buffer.writeln('##.CHLORPYRIFOS IR PEAKS= 1260, 1040, 960, 680 cm-1');
    } else if (spectralType == SpectralType.raman) {
      buffer.writeln('##.CHLORPYRIFOS RAMAN PEAKS= 680, 720 cm-1');
    }

    buffer.writeln('##XYDATA= (X++(Y..Y))');

    // 写入数据
    for (int i = 0; i < wavelengths.length; i++) {
      buffer.writeln(
          '${wavelengths[i].toStringAsFixed(4)} ${intensities[i].toStringAsFixed(6)}');
    }

    buffer.writeln('##END=');

    return buffer.toString();
  }

  String _spectralTypeToString(SpectralType type) {
    switch (type) {
      case SpectralType.uv:
        return 'UV/VISIBLE SPECTRUM';
      case SpectralType.ir:
        return 'INFRARED SPECTRUM';
      case SpectralType.raman:
        return 'RAMAN SPECTRUM';
      case SpectralType.unknown:
        return 'SPECTRUM';
    }
  }
}
