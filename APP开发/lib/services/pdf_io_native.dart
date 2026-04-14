import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// 原生平台: 保存PDF到用户可访问的文件系统目录
///
/// 保存策略（按优先级）：
/// 1. 外部存储目录（用户可通过文件管理器访问）
/// 2. 应用文档目录（回退方案）
Future<String> saveToFile(Uint8List bytes, String fileName) async {
  if (bytes.isEmpty) {
    throw Exception('PDF数据为空，无法保存');
  }

  // 策略1: 尝试外部存储目录（文件管理器可见）
  try {
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final filePath = await _writeAndVerify(extDir, bytes, fileName);
      print('[PDF] 已保存到外部存储: $filePath');
      return filePath;
    }
  } catch (e) {
    print('[PDF] 外部存储保存失败: $e，尝试回退方案...');
  }

  // 策略2: 回退到应用文档目录
  try {
    final docDir = await getApplicationDocumentsDirectory();
    final filePath = await _writeAndVerify(docDir, bytes, fileName);
    print('[PDF] 已保存到应用文档目录: $filePath');
    return filePath;
  } catch (e) {
    throw Exception('PDF文件保存失败: $e');
  }
}

/// 写入文件并验证完整性
Future<String> _writeAndVerify(
    Directory baseDir, Uint8List bytes, String fileName) async {
  // 创建 Reports 子目录，方便用户查找
  final reportsDir = Directory('${baseDir.path}/Reports');
  if (!await reportsDir.exists()) {
    await reportsDir.create(recursive: true);
  }

  final filePath = '${reportsDir.path}/$fileName';
  final file = File(filePath);

  // 写入文件（flush确保数据完全写入磁盘）
  await file.writeAsBytes(bytes, flush: true);

  // 验证文件存在
  if (!await file.exists()) {
    throw Exception('文件写入后未找到: $filePath');
  }

  // 验证文件大小一致
  final actualSize = await file.length();
  if (actualSize == 0) {
    await file.delete();
    throw Exception('文件写入异常：大小为0字节');
  }

  if (actualSize != bytes.length) {
    await file.delete();
    throw Exception('文件不完整：期望${bytes.length}字节，实际${actualSize}字节');
  }

  return filePath;
}
