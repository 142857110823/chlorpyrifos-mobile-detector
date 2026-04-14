import 'dart:typed_data';

/// Web平台stub: 文件保存不通过dart:io
/// Web平台在PdfReportService中使用kIsWeb判断，走Printing.sharePdf路径
/// 此stub仅为满足条件导入的编译需求
Future<String> saveToFile(Uint8List bytes, String fileName) async {
  throw UnsupportedError('File saving is not supported on Web platform');
}
