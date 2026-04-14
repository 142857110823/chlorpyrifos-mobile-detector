import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:google_ml_kit/google_ml_kit.dart';

/// 高级图像处理服务
/// 实现更鲁棒的坐标轴检测、刻度线定位和物理坐标映射
class AdvancedImageProcessingService {
  static final AdvancedImageProcessingService _instance = AdvancedImageProcessingService._internal();
  factory AdvancedImageProcessingService() => _instance;
  AdvancedImageProcessingService._internal();

  /// 图像预处理：读取并转换颜色空间
  Future<Map<String, dynamic>> preprocessImage(String imagePath) async {
    try {
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
      return {
        'src': null,
        'gray': null,
        'height': 0,
        'width': 0,
      };
    }
  }

  /// 边缘检测
  img.Image detectEdges(img.Image grayImage) {
    // 使用Sobel边缘检测
    final edges = img.sobel(grayImage);
    // 二值化边缘图像
    return img.threshold(edges, 128);
  }

  /// 检测直线（基于霍夫变换原理的简化实现）
  List<Line> detectLines(img.Image edgeImage, {double threshold = 128}) {
    final lines = <Line>[];
    final width = edgeImage.width;
    final height = edgeImage.height;
    
    // 检测水平直线
    for (int y = 0; y < height; y++) {
      int lineLength = 0;
      int startX = 0;
      
      for (int x = 0; x < width; x++) {
        final pixel = img.getPixel(edgeImage, x, y);
        if (pixel > threshold) {
          if (lineLength == 0) {
            startX = x;
          }
          lineLength++;
        } else {
          if (lineLength > 50) { // 最小直线长度
            lines.add(Line(startX.toDouble(), y.toDouble(), (x - 1).toDouble(), y.toDouble()));
          }
          lineLength = 0;
        }
      }
      
      if (lineLength > 50) {
        lines.add(Line(startX.toDouble(), y.toDouble(), (width - 1).toDouble(), y.toDouble()));
      }
    }
    
    // 检测垂直直线
    for (int x = 0; x < width; x++) {
      int lineLength = 0;
      int startY = 0;
      
      for (int y = 0; y < height; y++) {
        final pixel = img.getPixel(edgeImage, x, y);
        if (pixel > threshold) {
          if (lineLength == 0) {
            startY = y;
          }
          lineLength++;
        } else {
          if (lineLength > 50) { // 最小直线长度
            lines.add(Line(x.toDouble(), startY.toDouble(), x.toDouble(), (y - 1).toDouble()));
          }
          lineLength = 0;
        }
      }
      
      if (lineLength > 50) {
        lines.add(Line(x.toDouble(), startY.toDouble(), x.toDouble(), (height - 1).toDouble()));
      }
    }
    
    return lines;
  }

  /// 找到最长的水平直线（x轴）
  Line? findXAxis(List<Line> lines) {
    Line? xAxis;
    double maxLength = 0;
    
    for (final line in lines) {
      if (line.isHorizontal()) {
        final length = line.length();
        if (length > maxLength) {
          maxLength = length;
          xAxis = line;
        }
      }
    }
    
    return xAxis;
  }

  /// 找到最长的垂直直线（y轴）
  Line? findYAxis(List<Line> lines) {
    Line? yAxis;
    double maxLength = 0;
    
    for (final line in lines) {
      if (line.isVertical()) {
        final length = line.length();
        if (length > maxLength) {
          maxLength = length;
          yAxis = line;
        }
      }
    }
    
    return yAxis;
  }

  /// 检测刻度线
  List<Point> detectTickMarks(img.Image edgeImage, Line axis, {bool isHorizontal = true}) {
    final ticks = <Point>[];
    final width = edgeImage.width;
    final height = edgeImage.height;
    
    if (isHorizontal) {
      // 检测x轴刻度线（垂直短线）
      final y = axis.y1.round();
      
      for (int x = 0; x < width; x++) {
        // 检查是否有垂直短线
        int tickLength = 0;
        for (int dy = 1; dy <= 10; dy++) { // 刻度线最大长度
          if (y + dy < height && img.getPixel(edgeImage, x, y + dy) > 128) {
            tickLength++;
          } else {
            break;
          }
        }
        
        if (tickLength >= 3) { // 最小刻度线长度
          ticks.add(Point(x.toDouble(), y.toDouble()));
        }
      }
    } else {
      // 检测y轴刻度线（水平短线）
      final x = axis.x1.round();
      
      for (int y = 0; y < height; y++) {
        // 检查是否有水平短线
        int tickLength = 0;
        for (int dx = 1; dx <= 10; dx++) { // 刻度线最大长度
          if (x - dx >= 0 && img.getPixel(edgeImage, x - dx, y) > 128) {
            tickLength++;
          } else {
            break;
          }
        }
        
        if (tickLength >= 3) { // 最小刻度线长度
          ticks.add(Point(x.toDouble(), y.toDouble()));
        }
      }
    }
    
    return ticks;
  }

  /// 使用OCR识别图像中的文本
  Future<List<String>> recognizeText(String imagePath) async {
    try {
      final file = File(imagePath);
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      final texts = <String>[];
      for (final textBlock in recognizedText.blocks) {
        for (final line in textBlock.lines) {
          texts.add(line.text);
        }
      }
      
      await textRecognizer.close();
      return texts;
    } catch (e) {
      print('OCR识别失败: $e');
      return [];
    }
  }

  /// 从OCR结果中提取刻度值
  Map<String, List<double>> extractScaleValues(List<String> ocrTexts) {
    final xValues = <double>[];
    final yValues = <double>[];
    
    // 正则表达式匹配数字（包括整数和小数）
    final numberRegex = RegExp(r'\d+(\.\d+)?');
    
    for (final text in ocrTexts) {
      final matches = numberRegex.allMatches(text);
      for (final match in matches) {
        final numberStr = match.group(0);
        if (numberStr != null) {
          final number = double.tryParse(numberStr);
          if (number != null) {
            // 简单判断：较大的数字可能是波长（x轴），较小的可能是吸光度（y轴）
            if (number >= 100) {
              xValues.add(number);
            } else {
              yValues.add(number);
            }
          }
        }
      }
    }
    
    // 排序并去重
    xValues.sort();
    yValues.sort();
    
    // 去重
    final uniqueXValues = xValues.toSet().toList();
    final uniqueYValues = yValues.toSet().toList();
    
    return {
      'x': uniqueXValues,
      'y': uniqueYValues,
    };
  }

  /// 确定坐标轴范围
  Map<String, double> determineAxisRanges(List<double> xValues, List<double> yValues) {
    double xMin = 200.0;
    double xMax = 700.0;
    double yMin = 0.0;
    double yMax = 4.5;
    
    // 确定x轴范围
    if (xValues.isNotEmpty) {
      xMin = xValues.reduce((a, b) => a < b ? a : b);
      xMax = xValues.reduce((a, b) => a > b ? a : b);
    }
    
    // 确定y轴范围
    if (yValues.isNotEmpty) {
      yMin = yValues.reduce((a, b) => a < b ? a : b);
      yMax = yValues.reduce((a, b) => a > b ? a : b);
      // 如果y轴最小值大于0，可能是截断的坐标轴，设置为0
      if (yMin > 0.1) {
        yMin = 0.0;
      }
    }
    
    return {
      'xMin': xMin,
      'xMax': xMax,
      'yMin': yMin,
      'yMax': yMax,
    };
  }

  /// 检测刻度类型（线性或非线性）
  String detectScaleType(List<double> values) {
    if (values.length < 3) {
      return 'linear';
    }
    
    // 计算相邻值之间的差异
    final differences = <double>[];
    for (int i = 1; i < values.length; i++) {
      differences.add(values[i] - values[i - 1]);
    }
    
    // 检查差异是否大致相同（线性刻度）
    final avgDiff = differences.reduce((a, b) => a + b) / differences.length;
    final maxDiff = differences.reduce((a, b) => a > b ? a : b);
    final minDiff = differences.reduce((a, b) => a < b ? a : b);
    
    // 如果最大差异和最小差异的比值小于2，则认为是线性刻度
    if (maxDiff / minDiff < 2) {
      return 'linear';
    } else {
      return 'nonlinear';
    }
  }

  /// 坐标轴定位（高级版本）
  Future<Map<String, dynamic>> locateAxes(String imagePath) async {
    try {
      final preprocessed = await preprocessImage(imagePath);
      final src = preprocessed['src'];
      final gray = preprocessed['gray'];

      if (src == null || gray == null) {
        throw Exception('图像预处理失败');
      }

      // 边缘检测
      final edges = detectEdges(gray);
      
      // 检测直线
      final lines = detectLines(edges);
      
      // 找到x轴和y轴
      final xAxis = findXAxis(lines);
      final yAxis = findYAxis(lines);
      
      if (xAxis == null || yAxis == null) {
        throw Exception('无法检测到坐标轴');
      }
      
      // 检测刻度线
      final xTicks = detectTickMarks(edges, xAxis, isHorizontal: true);
      final yTicks = detectTickMarks(edges, yAxis, isHorizontal: false);
      
      // 计算坐标轴交点（原点）
      final origin = calculateOrigin(xAxis, yAxis);
      
      // 使用OCR识别刻度数字
      final ocrTexts = await recognizeText(imagePath);
      final scaleValues = extractScaleValues(ocrTexts);
      final axisRanges = determineAxisRanges(scaleValues['x']!, scaleValues['y']!);
      
      // 检测刻度类型
      final xScaleType = detectScaleType(scaleValues['x']!);
      final yScaleType = detectScaleType(scaleValues['y']!);
      
      return {
        'src': src,
        'xAxis': xAxis,
        'yAxis': yAxis,
        'origin': origin,
        'xTicks': xTicks,
        'yTicks': yTicks,
        'xMin': axisRanges['xMin']!,
        'xMax': axisRanges['xMax']!,
        'yMin': axisRanges['yMin']!,
        'yMax': axisRanges['yMax']!,
        'xScaleType': xScaleType,
        'yScaleType': yScaleType,
        'scaleValues': scaleValues,
      };
    } catch (e) {
      print('坐标轴定位失败: $e');
      return {
        'src': null,
        'xAxis': null,
        'yAxis': null,
        'origin': null,
        'xTicks': [],
        'yTicks': [],
        'xMin': 200.0,
        'xMax': 700.0,
        'yMin': 0.0,
        'yMax': 4.5,
        'xScaleType': 'linear',
        'yScaleType': 'linear',
        'scaleValues': {'x': [], 'y': []},
      };
    }
  }

  /// 计算坐标轴交点（原点）
  Point calculateOrigin(Line xAxis, Line yAxis) {
    // 对于水平x轴和垂直y轴，交点就是(yAxis.x1, xAxis.y1)
    return Point(yAxis.x1, xAxis.y1);
  }

  /// 提取光谱曲线
  Future<List<Point>> extractSpectralCurve(String imagePath) async {
    try {
      final axesResult = await locateAxes(imagePath);
      final src = axesResult['src'];
      final xAxis = axesResult['xAxis'];
      final yAxis = axesResult['yAxis'];
      final origin = axesResult['origin'];

      if (src == null || xAxis == null || yAxis == null || origin == null) {
        throw Exception('坐标轴定位失败');
      }

      // 转换为灰度图
      final gray = img.grayscale(src);
      
      // 二值化处理
      final binary = img.threshold(gray, 128);
      
      // 提取光谱曲线点
      final points = <Point>[];
      final width = binary.width;
      final height = binary.height;
      
      // 只在坐标轴范围内扫描
      final startX = origin.x.round();
      final endX = xAxis.x2.round();
      final startY = yAxis.y1.round();
      final endY = yAxis.y2.round();
      
      // 从左到右扫描，找到每条垂直线上的曲线点
      for (int x = startX; x < endX; x++) {
        // 从y轴顶部到底部扫描
        for (int y = startY; y < endY; y++) {
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

  /// 像素坐标转物理坐标（支持非线性刻度）
  List<Map<String, double>> convertToPhysicalCoordinates(
    List<Point> curvePixels,
    Point origin,
    Line xAxis,
    Line yAxis,
    double xMin,
    double xMax,
    double yMin,
    double yMax,
    String xScaleType,
    String yScaleType,
    Map<String, List<double>> scaleValues,
  ) {
    final spectralData = <Map<String, double>>[];
    
    // 计算映射关系
    final xRange = xMax - xMin;
    final yRange = yMax - yMin;
    
    final xPixelRange = xAxis.length();
    final yPixelRange = yAxis.length();
    
    final xScale = xRange / xPixelRange;
    final yScale = yRange / yPixelRange;
    
    // 转换每个像素点
    for (final point in curvePixels) {
      // 计算相对于原点的偏移
      final xOffset = point.x - origin.x;
      final yOffset = point.y - origin.y;
      
      // 计算物理坐标
      double wavelength;
      double absorbance;
      
      // 处理x轴刻度
      if (xScaleType == 'linear' || scaleValues['x']!.length < 3) {
        wavelength = xMin + xOffset * xScale;
      } else {
        // 非线性刻度处理：使用线性插值
        wavelength = _nonLinearInterpolation(xOffset, xPixelRange, scaleValues['x']!);
      }
      
      // 处理y轴刻度
      if (yScaleType == 'linear' || scaleValues['y']!.length < 3) {
        // 注意：图像y轴向下，所以吸光度需要反转
        absorbance = yMax - yOffset * yScale;
      } else {
        // 非线性刻度处理：使用线性插值
        absorbance = _nonLinearInterpolation(yOffset, yPixelRange, scaleValues['y']!);
      }
      
      // 过滤超出范围的数据
      if (wavelength >= xMin && wavelength <= xMax &&
          absorbance >= yMin && absorbance <= yMax) {
        spectralData.add({
          'wavelength': wavelength,
          'absorbance': absorbance,
        });
      }
    }
    
    return spectralData;
  }

  /// 非线性刻度插值
  double _nonLinearInterpolation(double pixelOffset, double pixelRange, List<double> scaleValues) {
    // 计算像素位置的比例
    final ratio = pixelOffset / pixelRange;
    
    // 找到对应的刻度范围
    final index = (ratio * (scaleValues.length - 1)).floor();
    final clampedIndex = index.clamp(0, scaleValues.length - 2);
    
    // 获取相邻的两个刻度值
    final value1 = scaleValues[clampedIndex];
    final value2 = scaleValues[clampedIndex + 1];
    
    // 计算在这两个值之间的插值
    final localRatio = (ratio * (scaleValues.length - 1)) - clampedIndex;
    return value1 + (value2 - value1) * localRatio;
  }

  /// RGB转HSV
  Map<String, double> rgbToHsv(int r, int g, int b) {
    final double red = r / 255.0;
    final double green = g / 255.0;
    final double blue = b / 255.0;
    
    final double max = [red, green, blue].reduce((a, b) => a > b ? a : b);
    final double min = [red, green, blue].reduce((a, b) => a < b ? a : b);
    final double delta = max - min;
    
    double h = 0.0;
    double s = 0.0;
    double v = max;
    
    if (delta > 0) {
      if (max == red) {
        h = ((green - blue) / delta) * 60.0;
      } else if (max == green) {
        h = (2.0 + (blue - red) / delta) * 60.0;
      } else {
        h = (4.0 + (red - green) / delta) * 60.0;
      }
      
      if (h < 0) h += 360.0;
      
      s = delta / max;
    }
    
    return {'h': h, 's': s, 'v': v};
  }

  /// HSV颜色分割
  img.Image hsvColorSegmentation(img.Image image, {
    required double hMin, 
    required double hMax, 
    required double sMin, 
    required double sMax, 
    required double vMin, 
    required double vMax,
  }) {
    final result = img.copy(image);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;
        
        final hsv = rgbToHsv(r, g, b);
        final h = hsv['h']!;
        final s = hsv['s']!;
        final v = hsv['v']!;
        
        // 检查是否在指定的HSV范围内
        bool inRange = false;
        if (hMin <= hMax) {
          inRange = h >= hMin && h <= hMax &&
                    s >= sMin && s <= sMax &&
                    v >= vMin && v <= vMax;
        } else {
          // 处理色相环的环绕情况
          inRange = (h >= hMin || h <= hMax) &&
                    s >= sMin && s <= sMax &&
                    v >= vMin && v <= vMax;
        }
        
        if (inRange) {
          // 保留颜色
          result.setPixel(x, y, 0xFF000000); // 黑色曲线
        } else {
          // 设为白色背景
          result.setPixel(x, y, 0xFFFFFFFF);
        }
      }
    }
    
    return result;
  }

  /// 自动检测曲线颜色并分割
  Future<img.Image> autoColorSegmentation(String imagePath) async {
    final preprocessed = await preprocessImage(imagePath);
    final src = preprocessed['src'];
    
    if (src == null) {
      throw Exception('图像预处理失败');
    }
    
    // 检测图像类型（彩色、灰度、黑白）
    final isGrayscale = _isGrayscale(src);
    
    if (isGrayscale) {
      // 灰度图像处理
      return _processGrayscaleImage(src);
    } else {
      // 彩色图像处理
      return _processColorImage(src);
    }
  }

  /// 判断图像是否为灰度图
  bool _isGrayscale(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;
        
        if (r != g || g != b) {
          return false;
        }
      }
    }
    return true;
  }

  /// 处理灰度图像
  img.Image _processGrayscaleImage(img.Image image) {
    // 对灰度图像进行自适应阈值处理
    final gray = img.grayscale(image);
    
    // 使用自适应阈值处理，处理不同光照条件
    final binary = img.threshold(gray, 128);
    
    // 应用形态学操作去除噪声
    final denoised = _applyMorphologicalOperations(binary);
    
    return denoised;
  }

  /// 处理彩色图像
  img.Image _processColorImage(img.Image image) {
    // 常见曲线颜色的HSV范围
    final colorRanges = [
      // 红色范围（考虑色相环的环绕）
      {'hMin': 0.0, 'hMax': 10.0, 'sMin': 0.5, 'sMax': 1.0, 'vMin': 0.3, 'vMax': 1.0},
      {'hMin': 350.0, 'hMax': 360.0, 'sMin': 0.5, 'sMax': 1.0, 'vMin': 0.3, 'vMax': 1.0},
      // 蓝色范围
      {'hMin': 180.0, 'hMax': 240.0, 'sMin': 0.3, 'sMax': 1.0, 'vMin': 0.2, 'vMax': 1.0},
      // 绿色范围
      {'hMin': 80.0, 'hMax': 150.0, 'sMin': 0.3, 'sMax': 1.0, 'vMin': 0.2, 'vMax': 1.0},
      // 黑色范围（处理黑白打印）
      {'hMin': 0.0, 'hMax': 360.0, 'sMin': 0.0, 'sMax': 0.3, 'vMin': 0.0, 'vMax': 0.5},
    ];
    
    // 尝试不同的颜色范围，选择最佳分割结果
    img.Image bestSegmentation = img.copy(image);
    int maxCurvePixels = 0;
    
    for (final range in colorRanges) {
      final segmentation = hsvColorSegmentation(
        image,
        hMin: range['hMin']!,
        hMax: range['hMax']!,
        sMin: range['sMin']!,
        sMax: range['sMax']!,
        vMin: range['vMin']!,
        vMax: range['vMax']!,
      );
      
      // 计算曲线像素数
      int curvePixels = _countCurvePixels(segmentation);
      
      // 选择曲线像素数最多的分割结果
      if (curvePixels > maxCurvePixels && curvePixels > 100) { // 确保有足够的曲线像素
        maxCurvePixels = curvePixels;
        bestSegmentation = segmentation;
      }
    }
    
    // 应用形态学操作去除噪声和伪影
    final denoised = _applyMorphologicalOperations(bestSegmentation);
    
    return denoised;
  }

  /// 计算曲线像素数
  int _countCurvePixels(img.Image image) {
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel == 0xFF000000) { // 黑色像素
          count++;
        }
      }
    }
    return count;
  }

  /// 应用形态学操作去除噪声和伪影
  img.Image _applyMorphologicalOperations(img.Image binaryImage) {
    // 复制图像以避免修改原始图像
    img.Image result = img.copy(binaryImage);
    
    // 先进行腐蚀操作去除小噪声
    result = img.erode(result);
    
    // 再进行膨胀操作恢复曲线宽度
    result = img.dilate(result);
    
    return result;
  }

  /// 改进的光谱曲线提取（支持不同颜色曲线和图像类型）
  Future<List<Point>> extractSpectralCurve(String imagePath) async {
    try {
      final axesResult = await locateAxes(imagePath);
      final src = axesResult['src'];
      final xAxis = axesResult['xAxis'];
      final yAxis = axesResult['yAxis'];
      final origin = axesResult['origin'];

      if (src == null || xAxis == null || yAxis == null || origin == null) {
        throw Exception('坐标轴定位失败');
      }

      // 使用自动颜色分割处理图像
      final segmented = await autoColorSegmentation(imagePath);
      
      // 提取光谱曲线点
      final points = <Point>[];
      final width = segmented.width;
      final height = segmented.height;
      
      // 只在坐标轴范围内扫描
      final startX = origin.x.round();
      final endX = xAxis.x2.round();
      final startY = yAxis.y1.round();
      final endY = yAxis.y2.round();
      
      // 从左到右扫描，找到每条垂直线上的曲线点
      for (int x = startX; x < endX; x++) {
        // 从y轴顶部到底部扫描
        for (int y = startY; y < endY; y++) {
          // 找到第一个黑色像素（曲线）
          final pixel = segmented.getPixel(x, y);
          if (pixel == 0xFF000000) {
            points.add(Point(x.toDouble(), y.toDouble()));
            break;
          }
        }
      }
      
      // 平滑曲线，解决粗细不均的问题
      final smoothedPoints = _smoothCurve(points);
      
      return smoothedPoints;
    } catch (e) {
      print('光谱曲线提取失败: $e');
      return [];
    }
  }

  /// 平滑曲线，解决粗细不均的问题
  List<Point> _smoothCurve(List<Point> points) {
    if (points.length < 3) {
      return points;
    }
    
    final smoothed = <Point>[];
    
    // 使用移动平均法平滑曲线
    for (int i = 0; i < points.length; i++) {
      double sumX = 0;
      double sumY = 0;
      int count = 0;
      
      // 考虑当前点和前后各一个点
      for (int j = i - 1; j <= i + 1; j++) {
        if (j >= 0 && j < points.length) {
          sumX += points[j].x;
          sumY += points[j].y;
          count++;
        }
      }
      
      smoothed.add(Point(sumX / count, sumY / count));
    }
    
    return smoothed;
  }

  /// 保存处理后的图像
  Future<String?> saveImage(img.Image image, String outputPath) async {
    try {
      final encoded = img.encodePng(image);
      final file = File(outputPath);
      await file.writeAsBytes(encoded);
      return outputPath;
    } catch (e) {
      print('保存图像失败: $e');
      return null;
    }
  }
}

/// 直线类
class Line {
  final double x1, y1, x2, y2;

  Line(this.x1, this.y1, this.x2, this.y2);

  /// 判断是否为水平直线
  bool isHorizontal({double tolerance = 1.0}) {
    return (y1 - y2).abs() < tolerance;
  }

  /// 判断是否为垂直直线
  bool isVertical({double tolerance = 1.0}) {
    return (x1 - x2).abs() < tolerance;
  }

  /// 计算直线长度
  double length() {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  @override
  String toString() => 'Line($x1, $y1, $x2, $y2)';
}

/// 点类
class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}
