import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../providers/detection_provider.dart';
import '../providers/history_provider.dart';
import '../services/logging_service.dart';
import '../utils/utils.dart';

/// 光谱图片检测页面
/// 实现真实的光谱图片农药残留检测功能
class SpectralImageDetectionScreen extends StatefulWidget {
  const SpectralImageDetectionScreen({super.key});

  @override
  State<SpectralImageDetectionScreen> createState() => _SpectralImageDetectionScreenState();
}

class _SpectralImageDetectionScreenState extends State<SpectralImageDetectionScreen> {
  final LoggingService _logger = LoggingService();
  final TextEditingController _sampleNameController = TextEditingController();
  final TextEditingController _sampleCategoryController = TextEditingController();

  File? _selectedImage;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _sampleNameController.dispose();
    _sampleCategoryController.dispose();
    super.dispose();
  }

  /// 请求相机权限
  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }

  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    var status = await Permission.photos.status;
    if (!status.isGranted) {
      status = await Permission.photos.request();
    }
    return status.isGranted;
  }

  /// 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      // 请求权限
      if (source == ImageSource.camera) {
        bool hasPermission = await _requestCameraPermission();
        if (!hasPermission) {
          setState(() {
            _errorMessage = "需要相机权限才能拍摄图片";
          });
          return;
        }
      } else {
        bool hasPermission = await _requestStoragePermission();
        if (!hasPermission) {
          setState(() {
            _errorMessage = "需要存储权限才能选择图片";
          });
          return;
        }
      }

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = null;
        });
        _logger.info('图片已选择: ${pickedFile.path}', tag: 'SpectralImageDetection');
      }
    } catch (e) {
      setState(() {
        _errorMessage = "选择图片失败: $e";
      });
      _logger.error('选择图片失败: $e', tag: 'SpectralImageDetection');
    }
  }

  /// 开始检测
  Future<void> _startDetection() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = "请先选择光谱图片";
      });
      return;
    }

    if (_sampleNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "请输入样品名称";
      });
      return;
    }

    final detectionProvider = context.read<DetectionProvider>();

    // 设置样品信息
    detectionProvider.setSampleInfo(
      sampleName: _sampleNameController.text.trim(),
      sampleCategory: _sampleCategoryController.text.trim().isEmpty
          ? null
          : _sampleCategoryController.text.trim(),
      imagePath: _selectedImage!.path,
    );

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      _logger.info('开始光谱图片检测: ${_sampleNameController.text}', tag: 'SpectralImageDetection');

      // 执行检测
      final result = await detectionProvider.startDetection();

      if (result != null) {
        _logger.info('检测完成: ${result.riskLevelDescription}', tag: 'SpectralImageDetection');

        // 刷新历史记录
        context.read<HistoryProvider>().refreshHistory();

        // 显示结果
        if (mounted) {
          _showResultDialog(result);
        }
      } else {
        setState(() {
          _errorMessage = detectionProvider.errorMessage ?? "检测失败";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "检测失败: $e";
      });
      _logger.error('检测失败: $e', tag: 'SpectralImageDetection');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  /// 显示结果对话框
  void _showResultDialog(DetectionResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.hasOverLimit ? Icons.warning : Icons.check_circle,
              color: result.hasOverLimit ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('检测结果'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('样品: ${result.sampleName}'),
              const SizedBox(height: 8),
              Text('风险等级: ${result.riskLevelDescription}'),
              const SizedBox(height: 8),
              Text('置信度: ${(result.confidence * 100).toStringAsFixed(1)}%'),
              if (result.detectedPesticides.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '检测到的农药:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result.detectedPesticides.map((p) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    '• ${p.name}: ${p.concentration.toStringAsFixed(3)} ${p.unit}',
                    style: TextStyle(
                      color: p.isOverLimit ? Colors.red : Colors.green,
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 重置状态
              setState(() {
                _selectedImage = null;
                _sampleNameController.clear();
                _sampleCategoryController.clear();
              });
              context.read<DetectionProvider>().reset();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detectionProvider = context.watch<DetectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("光谱图片农药检测"),
        backgroundColor: AppConstants.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 样品信息输入
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '样品信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sampleNameController,
                      decoration: const InputDecoration(
                        labelText: '样品名称 *',
                        hintText: '请输入样品名称',
                        prefixIcon: Icon(Icons.label_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sampleCategoryController,
                      decoration: const InputDecoration(
                        labelText: '样品类别',
                        hintText: '如：蔬菜、水果、粮食等',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 图片预览
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '光谱图片',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  "请选择或拍摄光谱图片",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("拍摄"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text("相册"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 错误信息
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 20),

            // 检测进度
            if (detectionProvider.isProcessing) ...[
              LinearProgressIndicator(
                value: detectionProvider.progress > 0 ? detectionProvider.progress : null,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
              ),
              const SizedBox(height: 12),
              Text(
                '正在分析... ${(detectionProvider.progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
            ],

            // 开始检测按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: detectionProvider.isProcessing || _isAnalyzing ? null : _startDetection,
                icon: detectionProvider.isProcessing || _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.science),
                label: Text(
                  detectionProvider.isProcessing || _isAnalyzing ? '检测中...' : '开始检测',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 图片输入规范提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "图片输入规范",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "• 格式：支持 PNG、JPG 格式\n"
                    "• 内容：清晰的光谱曲线图像\n"
                    "• 背景：纯色背景，曲线清晰可见\n"
                    "• 分辨率：建议 ≥480×480 像素",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
