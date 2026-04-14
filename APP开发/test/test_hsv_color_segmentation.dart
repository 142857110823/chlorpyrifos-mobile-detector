import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../lib/services/advanced_image_processing_service.dart';

void main() {
  group('HSV Color Segmentation Tests', () {
    late AdvancedImageProcessingService service;

    setUp(() {
      service = AdvancedImageProcessingService();
    });

    test('Test RGB to HSV conversion', () {
      // 测试RGB到HSV的转换
      final hsvRed = service.rgbToHsv(255, 0, 0);
      expect(hsvRed['h'], closeTo(0.0, 0.1));
      expect(hsvRed['s'], closeTo(1.0, 0.1));
      expect(hsvRed['v'], closeTo(1.0, 0.1));

      final hsvGreen = service.rgbToHsv(0, 255, 0);
      expect(hsvGreen['h'], closeTo(120.0, 0.1));
      expect(hsvGreen['s'], closeTo(1.0, 0.1));
      expect(hsvGreen['v'], closeTo(1.0, 0.1));

      final hsvBlue = service.rgbToHsv(0, 0, 255);
      expect(hsvBlue['h'], closeTo(240.0, 0.1));
      expect(hsvBlue['s'], closeTo(1.0, 0.1));
      expect(hsvBlue['v'], closeTo(1.0, 0.1));
    });

    test('Test curve pixel counting', () {
      // 测试曲线像素计数功能
      // 创建一个简单的测试图像
      final testImage = img.Image(10, 10);
      // 设置一些黑色像素作为曲线
      testImage.setPixel(1, 1, 0xFF000000);
      testImage.setPixel(2, 2, 0xFF000000);
      testImage.setPixel(3, 3, 0xFF000000);
      
      final count = service._countCurvePixels(testImage);
      expect(count, equals(3));
    });

    test('Test curve smoothing', () {
      // 测试曲线平滑功能
      final points = [
        Point(0.0, 0.0),
        Point(1.0, 2.0),
        Point(2.0, 1.0),
        Point(3.0, 3.0),
        Point(4.0, 2.0),
      ];

      final smoothed = service._smoothCurve(points);
      expect(smoothed.length, equals(points.length));
      // 平滑后的点应该与原始点有所不同，但保持趋势
      expect(smoothed[1].y, isNot(equals(points[1].y)));
      expect(smoothed[2].y, isNot(equals(points[2].y)));
    });

    test('Test grayscale detection', () {
      // 测试灰度图像检测
      // 创建一个灰度图像
      final grayImage = img.Image(10, 10);
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          final gray = (x + y) % 256;
          grayImage.setPixel(x, y, (gray << 16) | (gray << 8) | gray);
        }
      }

      // 创建一个彩色图像
      final colorImage = img.Image(10, 10);
      colorImage.setPixel(0, 0, 0xFF000000); // 黑色
      colorImage.setPixel(1, 1, 0xFF00FF00); // 绿色

      expect(service._isGrayscale(grayImage), isTrue);
      expect(service._isGrayscale(colorImage), isFalse);
    });
  });
}
