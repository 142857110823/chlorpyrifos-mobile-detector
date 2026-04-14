import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/detection_result.dart';
import '../ml/explainability/explainability_result.dart';

/// PDF报告生成服务 - Web平台Stub实现
class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  String institutionName = '果蔬农药残留智能检测系统';
  String footerText = '本报告由AI智能分析系统自动生成';

  /// Web平台不支持PDF生成，返回空操作
  Future<String> saveReport({
    required DetectionResult result,
    ExplainabilityResult? explainability,
  }) async {
    throw UnsupportedError('Web平台不支持PDF报告生成');
  }

  /// Web平台不支持打印预览
  Future<void> printPreview({
    required DetectionResult result,
    ExplainabilityResult? explainability,
  }) async {
    throw UnsupportedError('Web平台不支持打印预览');
  }

  /// Web平台不支持分享报告
  Future<void> shareReport({
    required DetectionResult result,
    ExplainabilityResult? explainability,
  }) async {
    throw UnsupportedError('Web平台不支持报告分享');
  }

  /// Web平台不支持打开PDF文件
  Future<void> openPdfFile(String filePath) async {
    throw UnsupportedError('Web平台不支持打开PDF文件');
  }
}
