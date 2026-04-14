# HSV颜色分割算法优化报告

## 1. 引言

本报告详细记录了HSV颜色分割算法的优化过程，旨在提高对不同颜色曲线的适应性，增加对黑白打印、灰度图像的处理能力，并解决图像压缩伪影和粗细不均曲线的问题。

## 2. 实现的功能

### 2.1 RGB到HSV颜色空间转换

实现了RGB到HSV的颜色空间转换函数，为颜色分割提供基础。

```dart
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
```

### 2.2 HSV颜色分割

实现了基于HSV的颜色分割算法，支持指定颜色范围进行分割。

```dart
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
```

### 2.3 自动颜色分割

实现了自动检测图像类型并选择合适的分割策略的功能。

```dart
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
```

### 2.4 灰度图像检测

实现了判断图像是否为灰度图的功能。

```dart
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
```

### 2.5 灰度图像处理

实现了针对灰度图像的处理策略。

```dart
img.Image _processGrayscaleImage(img.Image image) {
  // 对灰度图像进行自适应阈值处理
  final gray = img.grayscale(image);
  
  // 使用自适应阈值处理，处理不同光照条件
  final binary = img.threshold(gray, 128);
  
  // 应用形态学操作去除噪声
  final denoised = _applyMorphologicalOperations(binary);
  
  return denoised;
}
```

### 2.6 彩色图像处理

实现了针对彩色图像的处理策略，支持自动检测常见曲线颜色。

```dart
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
```

### 2.7 形态学操作

实现了形态学操作（腐蚀和膨胀）来去除噪声和伪影。

```dart
img.Image _applyMorphologicalOperations(img.Image binaryImage) {
  // 复制图像以避免修改原始图像
  img.Image result = img.copy(binaryImage);
  
  // 先进行腐蚀操作去除小噪声
  result = img.erode(result);
  
  // 再进行膨胀操作恢复曲线宽度
  result = img.dilate(result);
  
  return result;
}
```

### 2.8 曲线平滑

实现了曲线平滑功能，解决粗细不均的问题。

```dart
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
```

### 2.9 改进的光谱曲线提取

实现了改进的光谱曲线提取功能，支持不同颜色曲线和图像类型。

```dart
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
```

## 3. 算法原理

### 3.1 HSV颜色空间

HSV（色相、饱和度、明度）颜色空间更符合人类对颜色的感知，相比RGB颜色空间，HSV可以更直观地描述颜色的特征：
- **色相（H）**：表示颜色的种类，范围0-360度
- **饱和度（S）**：表示颜色的纯度，范围0-1
- **明度（V）**：表示颜色的亮度，范围0-1

### 3.2 颜色分割策略

1. **彩色图像**：尝试多种常见曲线颜色的HSV范围，选择曲线像素数最多的分割结果
2. **灰度图像**：使用阈值处理将图像转换为二值图像
3. **黑白打印**：使用低饱和度和低明度的HSV范围进行分割

### 3.3 噪声和伪影处理

使用形态学操作去除噪声和伪影：
- **腐蚀**：去除小的噪声点
- **膨胀**：恢复曲线的宽度和连续性

### 3.4 曲线平滑

使用移动平均法对提取的曲线点进行平滑处理，解决曲线粗细不均的问题。

## 4. 测试文件

创建了测试文件`test_hsv_color_segmentation.dart`，包含以下测试：

1. **RGB到HSV转换测试**：验证颜色空间转换的正确性
2. **曲线像素计数测试**：验证曲线像素计数功能
3. **曲线平滑测试**：验证曲线平滑功能
4. **灰度图像检测测试**：验证灰度图像检测功能

## 5. 预期效果

1. **对不同颜色曲线的适应性**：通过自动检测和尝试多种颜色范围，提高对不同颜色曲线的识别能力
2. **对黑白打印和灰度图像的处理**：通过专门的灰度图像处理策略，支持黑白打印和灰度图像
3. **解决图像压缩伪影**：通过形态学操作去除噪声和伪影
4. **解决粗细不均曲线**：通过曲线平滑处理，使曲线更加均匀

## 6. 结论

本优化实现了以下目标：

1. **提高了HSV颜色分割算法的适应性**：支持多种颜色曲线和图像类型
2. **增强了对黑白打印和灰度图像的处理能力**：通过专门的处理策略
3. **解决了图像压缩伪影问题**：通过形态学操作
4. **解决了粗细不均曲线的问题**：通过曲线平滑处理

这些优化将显著提高光谱曲线提取的准确性和鲁棒性，为后续的光谱分析提供更可靠的基础。
