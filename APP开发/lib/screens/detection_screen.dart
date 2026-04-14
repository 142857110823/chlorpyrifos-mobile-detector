import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/app_state_manager.dart';
import '../services/services.dart';
import '../services/error_handling_service.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import '../ml/explainability/explainability.dart';
import '../widgets/explainability/explainability_widgets.dart';

/// 检测页面
class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with SingleTickerProviderStateMixin {
  final BluetoothService _bluetoothService = BluetoothService();
  final AIAnalysisService _aiService = AIAnalysisService();
  final StorageService _storageService = StorageService();
  final DataImportService _importService = DataImportService();
  final ExplainabilityService _explainabilityService = ExplainabilityService();
  final PdfReportService _pdfService = PdfReportService();
  final CameraService _cameraService = CameraService();

  final TextEditingController _sampleNameController = TextEditingController();
  String? _selectedCategory;
  AnalysisMode _analysisMode = AnalysisMode.import;
  ImportedData? _importedData;
  String? _samplePhotoPath; // 样品参考照片路径

  DetectionState _detectionState = DetectionState.idle;
  SpectralData? _currentSpectralData;
  DetectionResult? _detectionResult;
  ExplainabilityResult? _explainabilityResult;
  bool _isAnalyzingExplainability = false;
  String _statusMessage = '准备就绪';
  double _progress = 0;

  StreamSubscription<SpectralData>? _dataSubscription;
  String? _lastExecutionSummary;

  @override
  void initState() {
    super.initState();
    _setupDataListener();
  }

  void _setupDataListener() {
    _dataSubscription = _bluetoothService.spectralDataStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _currentSpectralData = data;
      });
    });
  }

  @override
  void dispose() {
    _sampleNameController.dispose();
    _dataSubscription?.cancel();
    // 确保所有StreamSubscription都被取消
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用Consumer监听AppStateManager和DetectionProvider的状态变化
    return Scaffold(
      appBar: AppBar(
        title: const Text('毒死蜱检测'),
        actions: [
          // 全局状态指示器
          Consumer<AppStateManager>(
            builder: (context, appState, _) {
              if (appState.currentState == AppState.loading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelpDialog,
              );
            },
          ),
        ],
      ),
      body: Consumer2<AppStateManager, DetectionProvider>(
        builder: (context, appState, detectionProvider, _) {
          // 监听全局状态事件
          _listenToAppStateEvents(appState);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 全局状态消息显示
                if (appState.currentError != null)
                  _buildErrorBanner(appState.currentError!),
                
                _buildDeviceStatus(),
                const SizedBox(height: 16),
                _buildSampleInput(),
                const SizedBox(height: 16),
                _buildAnalysisModeSelector(),
                const SizedBox(height: 16),
                _buildSpectralPreview(),
                const SizedBox(height: 16),
                _buildProgressIndicator(),
                const SizedBox(height: 24),
                _buildActionButton(),
                if (_detectionResult != null) ...[
                  const SizedBox(height: 24),
                  _buildResult(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// 监听全局状态事件
  void _listenToAppStateEvents(AppStateManager appState) {
    // 使用addPostFrameCallback避免在build过程中setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // 监听状态变化并更新UI
      appState.eventStream.listen((event) {
        if (!mounted) return;
        
        switch (event.state) {
          case AppState.loading:
            // 全局加载状态已在AppBar中处理
            break;
          case AppState.error:
            if (event.error != null && mounted) {
              Helpers.showErrorSnackBar(context, event.error!);
            }
            break;
          case AppState.message:
            if (event.message != null && mounted) {
              _showMessageByType(event.message!, event.messageType);
            }
            break;
          case AppState.navigation:
            if (event.route != null && mounted) {
              Navigator.pushNamed(context, event.route!, arguments: event.arguments);
            }
            break;
          default:
            break;
        }
      });
    });
  }

  /// 根据消息类型显示不同的提示
  void _showMessageByType(String message, MessageType? type) {
    if (!mounted) return;
    
    switch (type) {
      case MessageType.success:
        Helpers.showSuccessSnackBar(context, message);
        break;
      case MessageType.error:
        Helpers.showErrorSnackBar(context, message);
        break;
      case MessageType.warning:
        Helpers.showSnackBar(context, message, isError: true);
        break;
      case MessageType.info:
      default:
        Helpers.showSnackBar(context, message);
        break;
    }
  }

  /// 构建错误提示横幅
  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              context.read<AppStateManager>().clearError();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatus() {
    return StreamBuilder<DeviceConnectionState>(
      stream: _bluetoothService.connectionState,
      initialData: _bluetoothService.currentConnectionState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? DeviceConnectionState.disconnected;
        final isConnected = state == DeviceConnectionState.connected;

        return Card(
          color: isConnected
              ? AppConstants.successColor.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color:
                      isConnected ? AppConstants.successColor : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? '设备已连接' : '设备未连接',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? AppConstants.successColor
                              : Colors.orange,
                        ),
                      ),
                      if (isConnected &&
                          _bluetoothService.currentDeviceInfo != null)
                        Text(
                          _bluetoothService.currentDeviceInfo!.name,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                if (!isConnected)
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.deviceConnection);
                    },
                    child: const Text('连接设备'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSampleInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '样品信息',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: TextField(
                controller: _sampleNameController,
                decoration: InputDecoration(
                  labelText: '样品名称',
                  hintText: '如：苹果、白菜等',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConstants.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                onTap: () {
                  // 添加触摸反馈
                  Feedback.forTap(context);
                },
              ),
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: '样品类别',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConstants.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                items: ProduceCategory.categories.map((category) {
                  return DropdownMenuItem(
                    value: category['id'] as String,
                    child: Row(
                      children: [
                        Icon(category['icon'] as IconData, size: 20),
                        const SizedBox(width: 8),
                        Text(category['name'] as String),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  // 添加触摸反馈
                  Feedback.forTap(context);
                },
                onTap: () {
                  // 添加触摸反馈
                  Feedback.forTap(context);
                },
              ),
            ),
            const SizedBox(height: 16),
            // 样品照片拍摄
            _buildSamplePhotoSection(),
          ],
        ),
      ),
    );
  }

  /// 样品照片拍摄区域
  Widget _buildSamplePhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '样品照片（可选）',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_samplePhotoPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.network(
                        _samplePhotoPath!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
                      )
                    : Image.file(
                        File(_samplePhotoPath!),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _samplePhotoPath = null;
                  });
                },
                tooltip: '移除照片',
              ),
              const Spacer(),
            ],
            if (_samplePhotoPath == null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takeSamplePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('拍摄样品照片'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 拍摄样品照片
  Future<void> _takeSamplePhoto() async {
    final path = await _cameraService.takeSamplePhoto();
    if (path != null) {
      setState(() {
        _samplePhotoPath = path;
      });
      if (mounted) {
        Helpers.showSnackBar(context, '样品照片已保存');
      }
    }
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Widget _buildAnalysisModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '数据来源',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '选择检测数据的来源方式',
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: SegmentedButton<AnalysisMode>(
                segments: const [
                  ButtonSegment<AnalysisMode>(
                    value: AnalysisMode.import,
                    label: Text('导入'),
                    icon: Icon(Icons.file_upload),
                  ),
                  ButtonSegment<AnalysisMode>(
                    value: AnalysisMode.mock,
                    label: Text('模拟'),
                    icon: Icon(Icons.science_outlined),
                  ),
                  ButtonSegment<AnalysisMode>(
                    value: AnalysisMode.deepLearning,
                    label: Text('实时'),
                    icon: Icon(Icons.bluetooth),
                  ),
                ],
                selected: {_analysisMode},
                onSelectionChanged: (Set<AnalysisMode> selection) {
                  setState(() {
                    _analysisMode = selection.first;
                  });
                  // 添加触摸反馈
                  Feedback.forTap(context);
                },
              ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                _getAnalysisModeDescription(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            if (_analysisMode == AnalysisMode.import) ...[
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 80, // 固定高度以避免布局抖动
                child: _buildImportSection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _handleFileImport,
          icon: const Icon(Icons.folder_open),
          label: const Text('选择光谱文件 (.dx / .spc)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_importedData != null) ...[
          const SizedBox(height: 12),
          _buildImportedDataCard(),
        ],
      ],
    );
  }

  Widget _buildImportedDataCard() {
    final data = _importedData!;
    final validation = _importService.validateImportedData(data);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validation.isValid
            ? AppConstants.successColor.withValues(alpha: 0.1)
            : AppConstants.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: validation.isValid
              ? AppConstants.successColor.withValues(alpha: 0.3)
              : AppConstants.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                validation.isValid ? Icons.check_circle : Icons.warning,
                size: 20,
                color: validation.isValid
                    ? AppConstants.successColor
                    : AppConstants.warningColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showDataPreviewDialog(data),
                tooltip: '预览数据',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _importedData = null;
                    _currentSpectralData = null;
                  });
                  _importService.clearImportedData();
                },
                tooltip: '清除',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${data.rowCount} 行 x ${data.columnCount} 列 | ${data.format.displayName}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (data.hasValidSpectralData) ...[
            const SizedBox(height: 4),
            Text(
              '光谱数据: ${data.spectralData!.dataPointCount} 点 (${data.spectralData!.wavelengths.first.toStringAsFixed(0)}-${data.spectralData!.wavelengths.last.toStringAsFixed(0)} nm)',
              style: TextStyle(fontSize: 12, color: AppConstants.successColor),
            ),
          ],
          if (!validation.isValid) ...[
            const SizedBox(height: 8),
            ...validation.issues.map((issue) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '- $issue',
                    style: TextStyle(
                        fontSize: 11, color: AppConstants.warningColor),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _handleFileImport() async {
    final result = await _importService.pickAndImportFile();

    if (!mounted) return;
    if (result.isCancelled) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _importedData = result.data;
        if (result.data!.hasValidSpectralData) {
          _currentSpectralData = result.data!.spectralData;
        }
      });

      // 自动显示预览
      _showDataPreviewDialog(result.data!);

      // 显示成功提示
      Helpers.showSuccessSnackBar(context, '文件导入成功');
    } else {
      final error = AppError(
        type: AppErrorType.storage,
        message: result.error ?? '导入失败',
      );
      ErrorHandlingService().showUserFriendlyError(context, error);
    }
  }

  void _showDataPreviewDialog(ImportedData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.table_chart),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '数据预览: ${data.fileName}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 数据摘要
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('格式: ${data.format.displayName}'),
                    Text('大小: ${data.rowCount} 行 x ${data.columnCount} 列'),
                    if (data.sheetName != null) Text('工作表: ${data.sheetName}'),
                    if (data.hasValidSpectralData)
                      Text(
                        '光谱范围: ${data.spectralData!.wavelengths.first.toStringAsFixed(1)} - ${data.spectralData!.wavelengths.last.toStringAsFixed(1)} nm',
                        style: TextStyle(color: AppConstants.successColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('数据预览 (前10行):',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // 表格预览
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey.shade200),
                      columnSpacing: 16,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columns: data.headers
                          .map((h) => DataColumn(
                                label: Text(
                                  h.isEmpty ? '(空)' : h,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ))
                          .toList(),
                      rows: data.previewRows
                          .map((row) => DataRow(
                                cells: row
                                    .map((cell) => DataCell(
                                          Text(
                                            cell.isEmpty ? '-' : cell,
                                            style:
                                                const TextStyle(fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (data.hasValidSpectralData)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentSpectralData = data.spectralData;
                });
                Helpers.showSnackBar(context, '光谱数据已加载，可以开始检测');
              },
              icon: const Icon(Icons.check),
              label: const Text('使用此数据'),
            ),
        ],
      ),
    );
  }

  String _getAnalysisModeDescription() {
    switch (_analysisMode) {
      case AnalysisMode.import:
        return '从.dx/.spc光谱文件导入毒死蜱检测数据进行分析';
      case AnalysisMode.mock:
        return '使用模拟数据进行毒死蜱检测演示，适合功能展示';
      case AnalysisMode.deepLearning:
        return '连接外接多光谱附件实时采集光谱并执行毒死蜱检测分析';
      case AnalysisMode.ruleEngine:
        return '使用规则引擎进行快速分析';
      case AnalysisMode.hybrid:
        return '同时使用深度学习和规则引擎进行混合分析';
    }
  }

  Widget _buildSpectralPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '光谱数据',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_currentSpectralData != null)
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '${_currentSpectralData!.dataPointCount} 个数据点',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _currentSpectralData != null
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      child: GestureDetector(
                        onTap: () {
                          // 添加触摸反馈
                          Feedback.forTap(context);
                          // 可以在这里添加更多交互，比如显示详细数据
                        },
                        child:
                            SpectralChart(spectralData: _currentSpectralData),
                      ),
                    )
                  : Center(
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '开始检测后显示光谱数据',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _buildStepIndicator(1, '准备', _detectionState.index >= 0),
                _buildStepConnector(_detectionState.index >= 1),
                _buildStepIndicator(2, '采集', _detectionState.index >= 1),
                _buildStepConnector(_detectionState.index >= 2),
                _buildStepIndicator(3, '分析', _detectionState.index >= 2),
                _buildStepConnector(_detectionState.index >= 3),
                _buildStepIndicator(4, '完成', _detectionState.index >= 3),
              ],
            ),
            const SizedBox(height: 16),
            if (_detectionState == DetectionState.acquiring ||
                _detectionState == DetectionState.analyzing)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppConstants.primaryColor : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppConstants.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppConstants.primaryColor : Colors.grey,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? AppConstants.primaryColor : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildActionButton() {
    final canStart = _detectionState == DetectionState.idle ||
        _detectionState == DetectionState.completed;

    return GradientButton(
      text: _getActionButtonText(),
      icon: _getActionButtonIcon(),
      isLoading: _detectionState == DetectionState.acquiring ||
          _detectionState == DetectionState.analyzing,
      onPressed: canStart ? _startDetection : null,
    );
  }

  String _getActionButtonText() {
    switch (_detectionState) {
      case DetectionState.idle:
        return '开始检测';
      case DetectionState.acquiring:
        return '正在采集...';
      case DetectionState.analyzing:
        return '正在分析...';
      case DetectionState.completed:
        return '重新检测';
    }
  }

  IconData _getActionButtonIcon() {
    switch (_detectionState) {
      case DetectionState.idle:
      case DetectionState.completed:
        return Icons.play_arrow;
      case DetectionState.acquiring:
        return Icons.sensors;
      case DetectionState.analyzing:
        return Icons.psychology;
    }
  }

  Widget _buildResult() {
    return Column(
      children: [
        ResultCard(
          result: _detectionResult!,
          onTap: () {
            Navigator.pushNamed(context, RouteNames.history,
                arguments: _detectionResult);
          },
        ),
        const SizedBox(height: 16),
        _buildResultActions(),
        if (_explainabilityResult != null) ...[
          const SizedBox(height: 16),
          _buildExplainabilitySection(),
        ],
      ],
    );
  }

  Widget _buildResultActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('操作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isAnalyzingExplainability
                      ? null
                      : _analyzeExplainability,
                  icon: _isAnalyzingExplainability
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.psychology),
                  label:
                      Text(_isAnalyzingExplainability ? '分析中...' : 'AI可解释性分析'),
                ),
                ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _generatePdfReport,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_isGeneratingPdf ? '生成中...' : '生成PDF报告'),
                ),
                OutlinedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print),
                  label: const Text('打印'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareReport,
                  icon: const Icon(Icons.share),
                  label: const Text('分享'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplainabilitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 8),
                Text('AI可解释性分析结果',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildConfidenceInfo(),
            const SizedBox(height: 16),
            _buildBandImportancePreview(),
            const SizedBox(height: 16),
            _buildCriticalWavelengthsPreview(),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _showFullExplainabilityDialog,
                icon: const Icon(Icons.fullscreen),
                label: const Text('查看完整分析'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceInfo() {
    final ci = _explainabilityResult!.confidenceInterval;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(children: [
            const Text('预测置信度',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('${(_detectionResult!.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
          ]),
          Column(children: [
            const Text('95%置信区间',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
                '[${(ci.lower * 100).toStringAsFixed(1)}%, ${(ci.upper * 100).toStringAsFixed(1)}%]',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _buildBandImportancePreview() {
    final bands = _explainabilityResult!.featureImportance.spectralBands;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('光谱波段贡献', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...bands.entries.take(3).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                    flex: 2,
                    child: Text(e.key, style: const TextStyle(fontSize: 13))),
                Expanded(
                    flex: 5,
                    child: LinearProgressIndicator(
                      value: e.value,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(e.key.contains('UV')
                              ? Colors.purple
                              : e.key.contains('可')
                                  ? Colors.green
                                  : Colors.red),
                    )),
                const SizedBox(width: 8),
                SizedBox(
                    width: 45,
                    child: Text('${(e.value * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12))),
              ]),
            )),
      ],
    );
  }

  Widget _buildCriticalWavelengthsPreview() {
    final wavelengths =
        _explainabilityResult!.criticalWavelengths.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('关键波长', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: wavelengths
              .map((cw) => Chip(
                    label: Text('${cw.wavelength.toStringAsFixed(0)}nm',
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: cw.contribution > 0
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    avatar: Icon(
                        cw.contribution > 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: cw.contribution > 0 ? Colors.green : Colors.red),
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _updateDetectionStage({
    required DetectionState state,
    required String status,
    required double progress,
  }) {
    if (!mounted) return;

    setState(() {
      _detectionState = state;
      _statusMessage = status;
      _progress = progress.clamp(0.0, 1.0);
    });
  }

  Future<SpectralData> _acquireRealtimeSpectralData() async {
    final isConnected = _bluetoothService.currentConnectionState ==
        DeviceConnectionState.connected;
    if (!isConnected) {
      throw Exception('实时模式需要先连接检测设备，或切换到导入/模拟模式');
    }

    StreamSubscription<SpectralData>? subscription;

    try {
      final completer = Completer<SpectralData>();
      subscription = _bluetoothService.spectralDataStream.listen((data) {
        if (!completer.isCompleted) {
          completer.complete(data);
        }
      });

      final started = await _bluetoothService.startSpectralAcquisition();
      if (!started) {
        throw Exception('检测设备已连接，但光谱采集启动失败');
      }

      final spectralData = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('等待设备返回光谱数据超时'),
      );

      if (mounted) {
        setState(() {
          _currentSpectralData = spectralData;
          _statusMessage = '光谱采集完成，正在准备AI分析...';
          _progress = 0.5;
        });
      }

      return spectralData;
    } finally {
      await subscription?.cancel();
      await _bluetoothService.stopSpectralAcquisition();
    }
  }

  String _getCurrentDataSourceLabel() {
    switch (_analysisMode) {
      case AnalysisMode.import:
        return 'Imported file';
      case AnalysisMode.mock:
        return 'Mock spectrum';
      case AnalysisMode.deepLearning:
        return 'Live capture';
      case AnalysisMode.ruleEngine:
        return 'Rule engine';
      case AnalysisMode.hybrid:
        return 'Hybrid analysis';
    }
  }

  Future<void> _persistSpectralDataIfAvailable() async {
    final spectralData = _currentSpectralData ?? _importedData?.spectralData;
    if (spectralData == null) {
      return;
    }

    await _storageService.saveSpectralData(spectralData);
  }

  DetectionResult _attachExecutionMetadata(DetectionResult result) {
    final modelInfo = _aiService.getModelInfo();
    final spectralData = _currentSpectralData ?? _importedData?.spectralData;
    final device = _bluetoothService.currentDeviceInfo;
    final notes = <String>[
      'Execution mode: ${_lastExecutionSummary ?? 'not recorded'}',
      'Data source: ${_getCurrentDataSourceLabel()}',
      'Runtime status: ${modelInfo['runtime_status'] ?? 'unknown'}',
      'Inference framework: ${modelInfo['framework'] ?? 'unknown'}',
      'Model version: ${modelInfo['version'] ?? 'unknown'}',
      if (spectralData != null) 'Spectral data ID: ${spectralData.id}',
      if (spectralData != null)
        'Spectral points: ${spectralData.dataPointCount}',
      if (device != null) 'Device ID: ${device.id}',
      if (device != null) 'Device name: ${device.name}',
      if (modelInfo['fallback_reason'] != null)
        'Fallback reason: ${modelInfo['fallback_reason']}',
    ].join('\n');

    return result.copyWith(
      spectralDataId: result.spectralDataId ?? spectralData?.id,
      deviceId: result.deviceId ?? device?.id,
      notes: notes,
      samplePhotoPath: _samplePhotoPath,
    );
  }

  Future<void> _startDetection() async {
    final sampleName = _sampleNameController.text.trim();
    if (sampleName.isEmpty) {
      Helpers.showSnackBar(context, '请输入样品名称', isError: true);
      return;
    }

    if (_analysisMode == AnalysisMode.import) {
      if (_importedData == null || !_importedData!.hasValidSpectralData) {
        Helpers.showSnackBar(context, '请先导入有效的光谱数据文件', isError: true);
        return;
      }
    }

    // 获取全局状态管理器
    final appStateManager = context.read<AppStateManager>();
    
    // 显示全局加载状态
    appStateManager.showLoading('正在准备检测...');

    setState(() {
      _detectionResult = null;
      _explainabilityResult = null;
      _lastExecutionSummary = null;
      if (_analysisMode != AnalysisMode.import) {
        _currentSpectralData = null;
      }
    });
    _updateDetectionStage(
      state: DetectionState.acquiring,
      status: '正在准备数据...',
      progress: 0,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _progress = controller.value * 0.15;
      });
    });
    await controller.forward().whenComplete(() => controller.dispose());

    try {
      if (_analysisMode == AnalysisMode.deepLearning) {
        _updateDetectionStage(
          state: DetectionState.acquiring,
          status: '正在采集实时光谱数据...',
          progress: 0.25,
        );
        appStateManager.showLoading('正在采集实时光谱数据...');
        await _acquireRealtimeSpectralData();
      }

      _updateDetectionStage(
        state: DetectionState.analyzing,
        status: _getAnalyzingMessage(),
        progress: _analysisMode == AnalysisMode.deepLearning ? 0.6 : 0.35,
      );
      appStateManager.showLoading(_getAnalyzingMessage());

      final result = await _performAnalysis(sampleName);

      _updateDetectionStage(
        state: DetectionState.analyzing,
        status: '正在保存检测结果...',
        progress: 0.9,
      );
      await _persistSpectralDataIfAvailable();
      final enrichedResult = _attachExecutionMetadata(result);
      await _storageService.saveDetectionResult(enrichedResult);

      // 发布检测结果到全局状态
      appStateManager.publishDetectionResult(enrichedResult);

      if (mounted) {
        await Future.wait([
          context.read<AppProvider>().refreshStatistics(),
          context.read<HistoryProvider>().loadHistory(),
        ]);
      }

      if (!mounted) return;
      setState(() {
        _detectionResult = enrichedResult;
        _detectionState = DetectionState.completed;
        _statusMessage = '检测完成';
        _progress = 1;
      });

      // 隐藏加载状态并显示成功消息
      appStateManager.hideLoading();
      appStateManager.showMessage('检测完成！', type: MessageType.success);
      Helpers.showSuccessSnackBar(context, '检测完成！');
      
      // 导航到结果页面
      appStateManager.navigateTo(RouteNames.result, arguments: {
        'result': enrichedResult,
        'fromDetection': true,
      });
    } catch (e, stack) {
      _updateDetectionStage(
        state: DetectionState.idle,
        status: '检测失败',
        progress: 0,
      );

      // 处理错误并发布到全局状态
      final error = AppError(
        type: _determineErrorType(e),
        message: e.toString(),
        error: e,
        stackTrace: stack,
      );
      
      appStateManager.hideLoading();
      appStateManager.handleError('检测失败: ${e.toString()}', stackTrace: stack);
      
      ErrorHandlingService().reportError(
        type: error.type,
        message: error.message,
        error: error.error,
        stackTrace: error.stackTrace,
      );
      if (mounted) {
        ErrorHandlingService().showUserFriendlyError(context, error);
      }
    }
  }

  String _getAnalyzingMessage() {
    switch (_analysisMode) {
      case AnalysisMode.import:
        return 'AI分析导入数据中...';
      case AnalysisMode.mock:
        return '模拟分析中...';
      case AnalysisMode.deepLearning:
        return 'AI深度学习分析中...';
      case AnalysisMode.ruleEngine:
        return '规则引擎分析中...';
      case AnalysisMode.hybrid:
        return '混合模式分析中...';
    }
  }

  Future<DetectionResult> _performAnalysis(String sampleName) async {
    final categoryName = _selectedCategory != null
        ? ProduceCategory.getCategoryName(_selectedCategory!)
        : null;

    switch (_analysisMode) {
      case AnalysisMode.import:
        _currentSpectralData = _importedData!.spectralData;
        _lastExecutionSummary = 'Hybrid analysis (imported spectrum)';
        return await _aiService.analyzeWithHybridMode(
          spectralData: _importedData!.spectralData!,
          sampleName: sampleName,
          sampleCategory: categoryName,
        );

      case AnalysisMode.mock:
        final mockSpectralData = _bluetoothService.generateMockSpectralData();
        if (mounted) {
          setState(() {
            _currentSpectralData = mockSpectralData;
          });
        } else {
          _currentSpectralData = mockSpectralData;
        }
        _lastExecutionSummary = 'Mock detection flow';
        return await _aiService.simulateDetection(
          sampleName: sampleName,
          sampleCategory: categoryName,
        );

      case AnalysisMode.deepLearning:
        final spectralData =
            _currentSpectralData ?? await _acquireRealtimeSpectralData();
        final deepLearningSupported =
            await _aiService.isDeepLearningSupported();

        if (!deepLearningSupported) {
          _lastExecutionSummary =
              'Hybrid analysis (live capture, model fallback)';
          if (mounted) {
            Helpers.showSnackBar(
              context,
              'TFLite模型不可用，已切换至混合分析模式。',
            );
          }
          return await _aiService.analyzeWithHybridMode(
            spectralData: spectralData,
            sampleName: sampleName,
            sampleCategory: categoryName,
          );
        }

        _lastExecutionSummary = 'Native TFLite inference';
        return await _aiService.analyzeWithDeepLearning(
          spectralData: spectralData,
          sampleName: sampleName,
          sampleCategory: categoryName,
        );

      case AnalysisMode.ruleEngine:
        final spectralData = _currentSpectralData ??
            _bluetoothService.generateMockSpectralData();
        _lastExecutionSummary = 'Rule engine analysis';
        return await _aiService.analyzeWithHybridMode(
          spectralData: spectralData,
          sampleName: sampleName,
          sampleCategory: categoryName,
        );

      case AnalysisMode.hybrid:
        final spectralData = _currentSpectralData ??
            _bluetoothService.generateMockSpectralData();
        _lastExecutionSummary = 'Hybrid analysis';
        return await _aiService.analyzeWithHybridMode(
          spectralData: spectralData,
          sampleName: sampleName,
          sampleCategory: categoryName,
        );
    }
  }

  Future<void> _analyzeExplainability() async {
    if (_detectionResult == null) {
      return;
    }

    if (_currentSpectralData == null &&
        _detectionResult!.spectralDataId != null) {
      final storedSpectralData = await _storageService
          .getSpectralData(_detectionResult!.spectralDataId!);
      if (!mounted) return;
      if (storedSpectralData != null) {
        setState(() {
          _currentSpectralData = storedSpectralData;
        });
      }
    }

    if (_currentSpectralData == null) {
      final mockData = _bluetoothService.generateMockSpectralData();
      setState(() {
        _currentSpectralData = mockData;
      });
    }

    setState(() {
      _isAnalyzingExplainability = true;
    });

    try {
      final result = await _explainabilityService.analyzeExplainability(
        spectralData: _currentSpectralData!,
        result: _detectionResult!,
      );

      if (!mounted) return;
      setState(() {
        _explainabilityResult = result;
        _isAnalyzingExplainability = false;
      });

      Helpers.showSuccessSnackBar(context, 'Explainability analysis complete');
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingExplainability = false;
      });
      final error = AppError(
        type: _determineErrorType(e),
        message: e.toString(),
        error: e,
        stackTrace: stack,
      );
      ErrorHandlingService().showUserFriendlyError(context, error);
    }
  }

  bool _isGeneratingPdf = false;

  Future<void> _generatePdfReport() async {
    if (_isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);
    Helpers.showLoadingDialog(context, message: '正在生成PDF报告，请稍候...');

    try {
      final filePath = await _pdfService.saveReport(
        result: _detectionResult!,
        explainability: _explainabilityResult,
      );

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        _showPdfSuccessDialog(filePath);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Helpers.showErrorSnackBar(
          context,
          'PDF生成失败: ${e.toString()}',
          duration: const Duration(seconds: 5),
          actionLabel: '重试',
          onAction: _generatePdfReport,
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showPdfSuccessDialog(String filePath) {
    // 提取文件名用于显示
    final fileName = filePath.split('/').last;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('PDF报告已生成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: $fileName'),
            const SizedBox(height: 8),
            Text(
              '存储路径: $filePath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openPdfFile(filePath);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开/分享'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfFile(String filePath) async {
    try {
      await _pdfService.openPdfFile(filePath);
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackBar(context, '无法打开PDF文件: $e');
      }
    }
  }

  Future<void> _printReport() async {
    try {
      Helpers.showLoadingDialog(context, message: '正在准备打印预览...');

      await _pdfService.printPreview(
        result: _detectionResult!,
        explainability: _explainabilityResult,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Helpers.showErrorSnackBar(
          context,
          '打印预览失败，请重试',
          duration: const Duration(seconds: 5),
          actionLabel: '重试',
          onAction: _printReport,
        );
      }
    }
  }

  Future<void> _shareReport() async {
    try {
      Helpers.showLoadingDialog(context, message: '正在准备分享...');

      await _pdfService.shareReport(
        result: _detectionResult!,
        explainability: _explainabilityResult,
      );

      if (mounted) Navigator.of(context).pop();
      if (mounted) Helpers.showSuccessSnackBar(context, '分享完成');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Helpers.showErrorSnackBar(
          context,
          '分享失败，请重试',
          duration: const Duration(seconds: 5),
          actionLabel: '重试',
          onAction: _shareReport,
        );
      }
    }
  }

  /// 确定错误类型
  AppErrorType _determineErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('http') ||
        errorString.contains('socket')) {
      return AppErrorType.network;
    } else if (errorString.contains('bluetooth') ||
        errorString.contains('ble')) {
      return AppErrorType.bluetooth;
    } else if (errorString.contains('hive') ||
        errorString.contains('storage')) {
      return AppErrorType.storage;
    } else if (errorString.contains('model') ||
        errorString.contains('tflite')) {
      return AppErrorType.ai_model;
    } else if (errorString.contains('device') ||
        errorString.contains('sensor')) {
      return AppErrorType.device;
    } else {
      return AppErrorType.general;
    }
  }

  void _showFullExplainabilityDialog() {
    if (_explainabilityResult == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('AI可解释性分析详情',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentSpectralData != null)
                        SpectralHighlightChart(
                          wavelengths: _currentSpectralData!.wavelengths,
                          intensities: _currentSpectralData!.intensities,
                          shapContributions:
                              _explainabilityResult!.shapValues.spectral,
                          criticalWavelengths:
                              _explainabilityResult!.criticalWavelengths,
                        ),
                      const SizedBox(height: 16),
                      FeatureImportanceChart(
                        importance: _explainabilityResult!.featureImportance,
                      ),
                      const SizedBox(height: 16),
                      ShapWaterfallChart(
                        shapValues: _explainabilityResult!.shapValues,
                        predictedClass: _detectionResult!
                                .detectedPesticides.isNotEmpty
                            ? _detectionResult!.detectedPesticides.first.name
                            : '无农药',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('检测说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '使用步骤：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. 确保检测设备已通过蓝牙连接'),
              Text('2. 输入待检测样品的名称'),
              Text('3. 选择样品类别（可选）'),
              Text('4. 将样品放置在检测区域'),
              Text('5. 点击"开始检测"按钮'),
              Text('6. 等待检测完成，查看结果'),
              SizedBox(height: 16),
              Text(
                '注意事项：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('- 检测前请清洁样品表面'),
              Text('- 保持检测环境稳定'),
              Text('- 每次检测约需30秒'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}

/// 检测状态枚举
enum DetectionState {
  idle, // 空闲
  acquiring, // 数据采集中
  analyzing, // 分析中
  completed, // 已完成
}
