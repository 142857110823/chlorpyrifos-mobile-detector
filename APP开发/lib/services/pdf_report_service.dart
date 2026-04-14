import 'package:flutter/foundation.dart';
import '../models/detection_result.dart';
import '../ml/explainability/explainability_result.dart';

/// PDF报告生成服务
/// 注意：Web平台不支持PDF生成，此服务仅在原生平台可用
class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  String institutionName = '果蔬农药残留智能检测系统';
  String footerText = '本报告由AI智能分析系统自动生成';

  /// 生成并保存PDF报告
  Future<String> saveReport({
    required DetectionResult result,
    ExplainabilityResult? explainability,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web平台不支持PDF报告生成');
    }
    throw UnsupportedError('PDF功能已暂时禁用，请使用原生平台');
  }

  /// 打印预览
  Future<void> printPreview({
    required DetectionResult result,
    ExplainabilityResult? explainability,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web平台不支持打印预览');
    }
    throw UnsupportedError('PDF功能已暂时禁用，请使用原生平台');
  }

  /// 分享报告
  Future<void> shareReport({
    required DetectionResult result,
    ExplainabilityResult? explainability,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web平台不支持报告分享');
    }
    throw UnsupportedError('PDF功能已暂时禁用，请使用原生平台');
  }

  /// 打开PDF文件
  Future<void> openPdfFile(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Web平台不支持打开PDF文件');
    }
    throw UnsupportedError('PDF功能已暂时禁用，请使用原生平台');
  }
}
