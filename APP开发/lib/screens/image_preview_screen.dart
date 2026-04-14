import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/image_processing_service.dart';
import '../services/spectral_analysis_service.dart';
import 'result_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  final String imagePath;

  const ImagePreviewScreen({super.key, required this.imagePath});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final ImageProcessingService _imageProcessingService = ImageProcessingService();
  final SpectralAnalysisService _spectralAnalysisService = SpectralAnalysisService();
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStandardLibrary();
  }

  Future<void> _loadStandardLibrary() async {
    try {
      await _spectralAnalysisService.loadStandardLibrary();
    } catch (e) {
      print('加载标准光谱库失败: $e');
    }
  }

  Future<void> _processImage() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = '正在处理图像...';
    });

    try {
      // 1. 提取光谱曲线
      _processingMessage = '正在提取光谱曲线...';
      setState(() {});
      final curvePixels = await _imageProcessingService.extractSpectralCurve(widget.imagePath);

      if (curvePixels.isEmpty) {
        throw Exception('无法提取光谱曲线');
      }

      // 2. 定位坐标轴
      _processingMessage = '正在定位坐标轴...';
      setState(() {});
      final axesResult = await _imageProcessingService.locateAxes(widget.imagePath);

      // 3. 转换为光谱数据
      _processingMessage = '正在转换为光谱数据...';
      setState(() {});
      final spectralData = _spectralAnalysisService.convertToSpectralData(
        curvePixels,
        axesResult['x0'],
        axesResult['x1'],
        axesResult['y0'],
        axesResult['y1'],
      );

      // 4. 转换为均匀间隔的光谱数据
      _processingMessage = '正在处理光谱数据...';
      setState(() {});
      final uniformSpectrum = _spectralAnalysisService.convertToUniformSpectrum(spectralData);

      // 5. 平滑处理
      final smoothedSpectrum = _spectralAnalysisService.smoothSpectralData(uniformSpectrum);

      // 6. 识别农药
      _processingMessage = '正在识别农药...';
      setState(() {});
      final recognitionResults = _spectralAnalysisService.recognizePesticide(smoothedSpectrum);

      // 7. 估算浓度
      final resultsWithConcentration = recognitionResults.map((result) {
        try {
          final concentration = _spectralAnalysisService.estimateConcentration(
            smoothedSpectrum,
            result.name,
          );
          return {
            'name': result.name,
            'cas': result.cas,
            'confidence': result.confidence,
            'concentration': concentration,
          };
        } catch (e) {
          return {
            'name': result.name,
            'cas': result.cas,
            'confidence': result.confidence,
            'concentration': 0.0,
          };
        }
      }).toList();

      // 8. 导航到结果页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(results: resultsWithConcentration),
        ),
      );
    } catch (e) {
      _showError('处理失败: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图像预览'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '请确认图像是否清晰且包含完整的光谱曲线',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Image.file(File(widget.imagePath)),
              ),
              const SizedBox(height: 40),
              if (_isProcessing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(_processingMessage),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _processImage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: const Text('自动处理'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: 实现手动调整功能
                        _showError('手动调整功能正在开发中');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text('手动调整'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('重新选择图像'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
