import 'dart:io';
import 'package:path/path.dart' as path;
import 'APP开发/lib/services/advanced_image_processing_service.dart';

void main() async {
  // 测试图像路径
  final testImagePath = 'd:\\王元元老师大创\\test_spectrum_image.png';
  
  // 检查测试图像是否存在
  if (!File(testImagePath).existsSync()) {
    print('测试图像不存在，请确保 test_spectrum_image.png 存在于指定路径');
    return;
  }
  
  // 创建高级图像处理服务实例
  final processingService = AdvancedImageProcessingService();
  
  print('开始测试坐标轴检测算法...');
  
  // 测试坐标轴定位
  print('\n1. 测试坐标轴定位:');
  final axesResult = await processingService.locateAxes(testImagePath);
  
  if (axesResult['src'] != null) {
    print('✓ 图像加载成功');
    
    final xAxis = axesResult['xAxis'];
    final yAxis = axesResult['yAxis'];
    final origin = axesResult['origin'];
    final xTicks = axesResult['xTicks'];
    final yTicks = axesResult['yTicks'];
    
    if (xAxis != null && yAxis != null) {
      print('✓ 坐标轴检测成功');
      print('  X轴: $xAxis');
      print('  Y轴: $yAxis');
      print('  原点: $origin');
      print('  X轴刻度线数量: ${xTicks.length}');
      print('  Y轴刻度线数量: ${yTicks.length}');
    } else {
      print('✗ 坐标轴检测失败');
    }
  } else {
    print('✗ 图像加载失败');
  }
  
  // 测试光谱曲线提取
  print('\n2. 测试光谱曲线提取:');
  final curvePoints = await processingService.extractSpectralCurve(testImagePath);
  
  if (curvePoints.isNotEmpty) {
    print('✓ 光谱曲线提取成功');
    print('  提取的曲线点数量: ${curvePoints.length}');
    print('  前5个点: ${curvePoints.take(5)}');
  } else {
    print('✗ 光谱曲线提取失败');
  }
  
  // 测试物理坐标转换
  print('\n3. 测试物理坐标转换:');
  if (curvePoints.isNotEmpty && axesResult['origin'] != null && 
      axesResult['xAxis'] != null && axesResult['yAxis'] != null) {
    final spectralData = processingService.convertToPhysicalCoordinates(
      curvePoints,
      axesResult['origin'],
      axesResult['xAxis'],
      axesResult['yAxis'],
      axesResult['xMin'],
      axesResult['xMax'],
      axesResult['yMin'],
      axesResult['yMax'],
    );
    
    if (spectralData.isNotEmpty) {
      print('✓ 物理坐标转换成功');
      print('  转换后的光谱数据点数量: ${spectralData.length}');
      print('  前5个数据点:');
      spectralData.take(5).forEach((data) {
        print('    波长: ${data['wavelength']?.toStringAsFixed(2)} nm, 吸光度: ${data['absorbance']?.toStringAsFixed(3)}');
      });
    } else {
      print('✗ 物理坐标转换失败');
    }
  } else {
    print('✗ 缺少必要的参数进行物理坐标转换');
  }
  
  print('\n测试完成!');
}
