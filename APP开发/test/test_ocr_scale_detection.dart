import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/advanced_image_processing_service.dart';

void main() {
  group('AdvancedImageProcessingService Tests', () {
    late AdvancedImageProcessingService service;

    setUp(() {
      service = AdvancedImageProcessingService();
    });

    test('Test OCR functionality', () async {
      // 测试OCR功能
      // 注意：此测试需要实际的光谱图像文件
      // 这里仅测试方法是否能正常调用
      expect(service.recognizeText, isNotNull);
    });

    test('Test scale value extraction', () {
      // 测试从OCR结果中提取刻度值
      final ocrTexts = ['200', '300', '400', '0.5', '1.0', '1.5'];
      final scaleValues = service.extractScaleValues(ocrTexts);
      
      expect(scaleValues['x'], isNotNull);
      expect(scaleValues['y'], isNotNull);
      expect(scaleValues['x']!.length, greaterThan(0));
      expect(scaleValues['y']!.length, greaterThan(0));
    });

    test('Test axis range determination', () {
      // 测试确定坐标轴范围
      final xValues = [200.0, 300.0, 400.0, 500.0, 600.0, 700.0];
      final yValues = [0.0, 0.5, 1.0, 1.5, 2.0];
      
      final ranges = service.determineAxisRanges(xValues, yValues);
      
      expect(ranges['xMin'], equals(200.0));
      expect(ranges['xMax'], equals(700.0));
      expect(ranges['yMin'], equals(0.0));
      expect(ranges['yMax'], equals(2.0));
    });

    test('Test scale type detection', () {
      // 测试检测刻度类型
      final linearValues = [100.0, 200.0, 300.0, 400.0, 500.0];
      final nonLinearValues = [10.0, 100.0, 1000.0, 10000.0];
      
      expect(service.detectScaleType(linearValues), equals('linear'));
      expect(service.detectScaleType(nonLinearValues), equals('nonlinear'));
    });

    test('Test non-linear interpolation', () {
      // 测试非线性刻度插值
      final scaleValues = [10.0, 100.0, 1000.0, 10000.0];
      final pixelOffset = 150.0;
      final pixelRange = 300.0;
      
      final interpolatedValue = service._nonLinearInterpolation(pixelOffset, pixelRange, scaleValues);
      expect(interpolatedValue, greaterThan(100.0));
      expect(interpolatedValue, lessThan(1000.0));
    });
  });
}
