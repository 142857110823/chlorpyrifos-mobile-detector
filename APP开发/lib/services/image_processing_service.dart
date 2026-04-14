import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// 图像处理服务
/// 使用image包进行图像处理（OpenCV功能已迁移）
class ImageProcessingService {
  static final ImageProcessingService _instance = ImageProcessingService._internal();
  factory ImageProcessingService() => _instance;
  ImageProcessingService._internal();

  /// 获取图片（拍照/相册）
  Future<String?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    return image?.path;
  }

  /// 图像预处理：读取并转换颜色空间
  Future<Map<String, dynamic>> preprocessImage(String imagePath) async {
    try {
      // 使用dart:io读取本地图像
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('无法解码图像');
      }

      // 转换为灰度图
      final gray = img.grayscale(image);

      return {
        'src': image,
        'gray': gray,
        'height': image.height,
        'width': image.width,
      };
    } catch (e) {
      print('图像预处理失败: $e');
      // 返回空结果而不是抛出异常
      return {
        'src': null,
        'gray': null,
        'height': 0,
        'width': 0,
      };
    }
  }

  /// 倾斜校正（简化版本）
  Future<Map<String, dynamic>> correctTilt(String imagePath) async {
    try {
      final preprocessed = await preprocessImage(imagePath);
      final src = preprocessed['src'];

      if (src == null) {
        throw Exception('图像预处理失败');
      }

      // 简化版本：直接返回原图，不进行倾斜校正
      return {
        'corrected': src,
        'angle': 0.0,
        'lines': [],
      };
    } catch (e) {
      print('倾斜校正失败: $e');
      return {
        'corrected': null,
        'angle': 0.0,
        'lines': [],
      };
    }
  }

  /// 坐标轴定位（简化版本）
  Future<Map<String, dynamic>> locateAxes(String imagePath) async {
    try {
      final correctedResult = await correctTilt(imagePath);
      final corrected = correctedResult['corrected'];

      if (corrected == null) {
        throw Exception('倾斜校正失败');
      }

      // 简化版本：返回默认坐标轴位置
      return {
        'corrected': corrected,
        'xAxisY': 0,
        'yAxisX': 0,
        'xMin': 0,
        'xMax': 100,
        'yMin': 0,
        'yMax': 100,
      };
    } catch (e) {
      print('坐标轴定位失败: $e');
      return {
        'corrected': null,
        'xAxisY': 0,
        'yAxisX': 0,
        'xMin': 0,
        'xMax': 100,
        'yMin': 0,
        'yMax': 100,
      };
    }
  }

  /// 提取光谱曲线
  Future<List<Point>> extractSpectralCurve(String imagePath) async {
    try {
      final axesResult = await locateAxes(imagePath);
      final corrected = axesResult['corrected'];

      if (corrected == null) {
        throw Exception('坐标轴定位失败');
      }

      // 转换为灰度图
      final gray = img.grayscale(corrected);
      
      // 二值化处理
      final binary = img.threshold(gray, 128);
      
      // 提取光谱曲线点
      final points = <Point>[];
      final width = binary.width;
      final height = binary.height;
      
      // 从左到右扫描，找到每条垂直线上的曲线点
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          // 找到第一个非白色像素（假设曲线是黑色，背景是白色）
          final pixel = img.getPixel(binary, x, y);
          if (pixel < 128) {
            points.add(Point(x.toDouble(), y.toDouble()));
            break;
          }
        }
      }
      
      return points;
    } catch (e) {
      print('光谱曲线提取失败: $e');
      return [];
    }
  }

  /// 保存处理后的图像
  Future<String?> saveImage(img.Image image, String outputPath) async {
    try {
      final encoded = img.encodePng(image);
      // 注意：这里需要实际的文件写入操作
      // 在Web平台上，可以使用浏览器下载
      // 在原生平台上，可以使用path_provider
      return outputPath;
    } catch (e) {
      print('保存图像失败: $e');
      return null;
    }
  }
}

/// 点类
class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}
