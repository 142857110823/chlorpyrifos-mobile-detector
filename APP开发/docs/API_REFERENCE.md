# 农药残留检测APP API参考

## 1. 概述

本文档提供了农药残留检测APP的主要API和服务接口参考，旨在帮助开发者理解和使用应用的核心功能。

## 2. 核心服务接口

### 2.1 AIAnalysisService

**功能**：提供AI分析相关的核心功能，包括机器学习分析、混合模式分析。

**Flutter端主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `analyzeWithDeepLearning` | spectralData: SpectralData, sampleName: String, sampleCategory: String? | Future<DetectionResult> | 使用CNN-1D TFLite模型分析光谱数据 |
| `analyzeWithHybridMode` | spectralData: SpectralData, sampleName: String, sampleCategory: String? | Future<DetectionResult> | 使用混合模式（深度学习+规则引擎）分析光谱数据 |
| `getPesticideInfo` | pesticideName: String | PesticideInfo? | 获取农药详细信息 |

**Streamlit Web端主要函数**：

| 函数名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `random_forest_analyze` | spectral_256: np.ndarray, features_64: np.ndarray | Tuple[List[DetectedPesticide], float] | 使用sklearn RandomForest分析光谱（predict_proba真实置信度） |
| `rule_engine_detect` | wavelengths: np.ndarray, processed: np.ndarray, features: np.ndarray | Tuple[List[DetectedPesticide], float] | 基于规则引擎的农药匹配（数据驱动置信度） |
| `hybrid_analyze` | wavelengths, processed, features | Tuple[List[DetectedPesticide], float] | 自适应混合分析（conf^2加权融合） |
| `compute_explainability` | wavelengths, processed, features, confidence, rf_clf | dict | 可解释性分析（扰动SHAP + Gini重要性 + RF树方差CI） |

**使用示例**：

```dart
final service = AIAnalysisService();
final result = await service.analyzeWithDeepLearning(
  spectralData: spectralData,
  sampleName: '苹果',
  sampleCategory: '水果类',
);
```

### 2.2 BluetoothService

**功能**：提供蓝牙设备连接和数据采集功能。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `scanForDevices` | duration: Duration? | Stream<DeviceInfo> | 扫描附近的蓝牙设备 |
| `connectToDevice` | deviceId: String | Future<DeviceConnectionState> | 连接到指定的蓝牙设备 |
| `disconnect` | - | Future<void> | 断开当前蓝牙连接 |
| `startDataCollection` | - | Future<void> | 开始采集光谱数据 |
| `stopDataCollection` | - | Future<void> | 停止采集光谱数据 |
| `generateMockSpectralData` | - | SpectralData | 生成模拟的光谱数据 |

**使用示例**：

```dart
final service = BluetoothService();
final devices = service.scanForDevices();
devices.listen((device) {
  print('发现设备: ${device.name}');
});
```

### 2.3 StorageService

**功能**：提供本地数据存储功能，包括检测结果、用户设置等。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `init` | - | Future<void> | 初始化存储服务 |
| `saveDetectionResult` | result: DetectionResult | Future<void> | 保存检测结果 |
| `getAllDetectionResults` | - | Future<List<DetectionResult>> | 获取所有检测结果 |
| `getDetectionStatsByRisk` | - | Future<Map<RiskLevel, int>> | 获取按风险等级统计的检测结果 |
| `getTodayDetectionCount` | - | Future<int> | 获取今日检测次数 |
| `deleteDetectionResult` | id: String | Future<void> | 删除指定的检测结果 |
| `setThemeMode` | mode: String | Future<void> | 设置主题模式 |
| `getThemeMode` | - | String | 获取当前主题模式 |

**使用示例**：

```dart
final service = StorageService();
await service.init();
await service.saveDetectionResult(result);
final results = await service.getAllDetectionResults();
```

### 2.4 ErrorHandlingService

**功能**：提供错误处理和错误报告功能。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `initialize` | - | void | 初始化错误处理服务 |
| `reportError` | type: AppErrorType, message: String, error: dynamic?, stackTrace: StackTrace? | void | 报告错误 |
| `showUserFriendlyError` | context: BuildContext, error: AppError | void | 显示用户友好的错误信息 |
| `getFriendlyErrorMessage` | error: AppError | String | 获取用户友好的错误信息 |

**使用示例**：

```dart
final service = ErrorHandlingService();
try {
  // 可能出错的代码
} catch (e, stack) {
  service.reportError(
    type: AppErrorType.general,
    message: '操作失败',
    error: e,
    stackTrace: stack,
  );
}
```

### 2.5 ModelUpdateService

**功能**：提供模型更新服务，包括版本检查、下载和验证。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `checkForUpdates` | currentVersion: String | Future<ModelInfo?> | 检查模型是否有更新 |
| `downloadAndUpdateModel` | modelInfo: ModelInfo, onProgress: Function(UpdateStatus, double)? | Future<File?> | 下载并更新模型 |
| `verifyModel` | modelFile: File, expectedMd5: String | Future<bool> | 验证模型文件 |
| `isModelAvailable` | - | Future<bool> | 检查模型文件是否存在 |
| `getModelPath` | - | Future<String?> | 获取模型文件路径 |

**使用示例**：

```dart
final service = ModelUpdateService();
final updateInfo = await service.checkForUpdates('1.0.0');
if (updateInfo != null) {
  final updatedModel = await service.downloadAndUpdateModel(
    updateInfo,
    (status, progress) {
      print('更新状态: $status, 进度: ${(progress * 100).toStringAsFixed(1)}%');
    },
  );
}
```

### 2.6 BluetoothService

**功能**：提供蓝牙设备连接和数据采集功能。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `scanForDevices` | duration: Duration? | Stream<DeviceInfo> | 扫描附近的蓝牙设备 |
| `connectToDevice` | deviceId: String | Future<DeviceConnectionState> | 连接到指定的蓝牙设备 |
| `disconnect` | - | Future<void> | 断开当前蓝牙连接 |
| `startDataCollection` | - | Future<void> | 开始采集光谱数据 |
| `stopDataCollection` | - | Future<void> | 停止采集光谱数据 |
| `generateMockSpectralData` | - | SpectralData | 生成模拟的光谱数据 |

**使用示例**：

```dart
final service = BluetoothService();
final devices = service.scanForDevices();
devices.listen((device) {
  print('发现设备: ${device.name}');
});
```

### 2.7 ExplainabilityService

**功能**：提供AI可解释性分析功能，解释AI模型的预测结果。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `analyzeExplainability` | spectralData: SpectralData, result: DetectionResult | Future<ExplainabilityResult> | 分析AI模型的可解释性 |
| `calculateFeatureImportance` | spectralData: SpectralData | Future<FeatureImportance> | 计算特征重要性 |
| `calculateShapValues` | spectralData: SpectralData, model: Interpreter | Future<ShapValues> | 计算SHAP值 |

**Streamlit Web端** (`compute_explainability`函数):

| 分析项 | 实现方式 | 描述 |
|--------|----------|------|
| SHAP值 | 基于扰动的确定性SHAP | 16段光谱置零扰动 → RF predict → 概率变化 → 梯度符号分配 |
| 特征重要性 | Gini importance | `rf_clf.feature_importances_`（基于决策树分裂质量） |
| 置信区间 | RF树方差 | 100棵决策树预测方差 → 95%置信区间 |

**使用示例**：

```dart
final service = ExplainabilityService();
final explainabilityResult = await service.analyzeExplainability(
  spectralData: spectralData,
  result: detectionResult,
);
```

### 2.8 DataImportService

**功能**：提供数据导入功能，支持从CSV和Excel文件导入光谱数据。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `pickAndImportFile` | - | Future<ImportResult> | 选择并导入文件 |
| `validateImportedData` | data: ImportedData | ValidationResult | 验证导入的数据 |
| `clearImportedData` | - | void | 清除导入的数据 |

**使用示例**：

```dart
final service = DataImportService();
final result = await service.pickAndImportFile();
if (result.isSuccess && result.data != null) {
  final validation = service.validateImportedData(result.data!);
  if (validation.isValid) {
    // 使用导入的数据
  }
}
```

### 2.9 PdfReportService

**功能**：提供PDF报告生成功能。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `saveReport` | result: DetectionResult, explainability: ExplainabilityResult? | Future<String> | 保存PDF报告到本地 |
| `printPreview` | result: DetectionResult, explainability: ExplainabilityResult? | Future<void> | 打印预览PDF报告 |
| `shareReport` | result: DetectionResult, explainability: ExplainabilityResult? | Future<void> | 分享PDF报告 |

**使用示例**：

```dart
final service = PdfReportService();
final filePath = await service.saveReport(
  result: detectionResult,
  explainability: explainabilityResult,
);
print('PDF报告已保存到: $filePath');
```

### 2.10 StorageService

**功能**：提供本地数据存储功能，包括检测结果、用户设置等。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `init` | - | Future<void> | 初始化存储服务 |
| `saveDetectionResult` | result: DetectionResult | Future<void> | 保存检测结果 |
| `getAllDetectionResults` | - | Future<List<DetectionResult>> | 获取所有检测结果 |
| `getDetectionStatsByRisk` | - | Future<Map<RiskLevel, int>> | 获取按风险等级统计的检测结果 |
| `getTodayDetectionCount` | - | Future<int> | 获取今日检测次数 |
| `deleteDetectionResult` | id: String | Future<void> | 删除指定的检测结果 |
| `setThemeMode` | mode: String | Future<void> | 设置主题模式 |
| `getThemeMode` | - | String | 获取当前主题模式 |

**使用示例**：

```dart
final service = StorageService();
await service.init();
await service.saveDetectionResult(result);
final results = await service.getAllDetectionResults();
```

## 3. 数据模型

### 3.1 DetectionResult

**功能**：表示检测结果的数据模型。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `id` | String | 检测结果ID |
| `timestamp` | DateTime | 检测时间戳 |
| `sampleName` | String | 样品名称 |
| `sampleCategory` | String? | 样品类别 |
| `riskLevel` | RiskLevel | 风险等级 |
| `confidence` | double | 置信度 |
| `detectedPesticides` | List<DetectedPesticide> | 检测到的农药列表 |
| `hasPesticides` | bool | 是否检测到农药 |

**方法**：

| 方法名 | 返回值 | 描述 |
|--------|--------|------|
| `toJson` | Map<String, dynamic> | 转换为JSON格式 |
| `fromJson` | DetectionResult | 从JSON格式创建实例 |

### 3.2 SpectralData

**功能**：表示光谱数据的数据模型。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `id` | String | 光谱数据ID |
| `timestamp` | DateTime | 采集时间戳 |
| `wavelengths` | List<double> | 波长列表 |
| `intensities` | List<double> | 强度列表 |
| `deviceId` | String | 设备ID |
| `dataPointCount` | int | 数据点数量 |
| `wavelengthRange` | (double, double) | 波长范围 |
| `maxIntensity` | double | 最大强度 |
| `minIntensity` | double | 最小强度 |
| `normalizedIntensities` | List<double> | 归一化后的强度列表 |

### 3.3 DetectedPesticide

**功能**：表示检测到的农药的数据模型。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `name` | String | 农药名称 |
| `type` | PesticideType | 农药类型 |
| `concentration` | double | 浓度 |
| `maxResidueLimit` | double | 最大残留限量 |
| `isOverLimit` | bool | 是否超标 |
| `overLimitRatio` | double | 超标倍数 |

### 3.4 ExplainabilityResult

**功能**：表示AI可解释性分析结果的数据模型。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `confidenceInterval` | (double, double) | 置信区间 |
| `featureImportance` | FeatureImportance | 特征重要性 |
| `shapValues` | ShapValues | SHAP值 |
| `criticalWavelengths` | List<CriticalWavelength> | 关键波长 |
| `modelExplanation` | String | 模型解释 |

## 4. 状态管理

### 4.1 AppProvider

**功能**：管理应用的全局状态，如主题模式、语言等。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `themeMode` | String | 当前主题模式 |
| `language` | String | 当前语言 |
| `isDarkMode` | bool | 是否为暗黑模式 |

**方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `setThemeMode` | mode: String | void | 设置主题模式 |
| `setLanguage` | language: String | void | 设置语言 |

### 4.2 DetectionProvider

**功能**：管理检测相关的状态。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `currentResult` | DetectionResult? | 当前检测结果 |
| `isDetecting` | bool | 是否正在检测 |
| `detectionProgress` | double | 检测进度 |

**方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `startDetection` | - | void | 开始检测 |
| `updateProgress` | progress: double | void | 更新检测进度 |
| `setResult` | result: DetectionResult | void | 设置检测结果 |
| `clearResult` | - | void | 清除检测结果 |

### 4.3 HistoryProvider

**功能**：管理历史记录相关的状态。

**主要属性**：

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `history` | List<DetectionResult> | 历史记录列表 |
| `isLoading` | bool | 是否正在加载 |
| `filter` | String? | 过滤条件 |

**方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `loadHistory` | - | Future<void> | 加载历史记录 |
| `refreshHistory` | - | Future<void> | 刷新历史记录 |
| `filterHistory` | filter: String? | void | 过滤历史记录 |
| `deleteRecord` | id: String | Future<void> | 删除记录 |

## 5. 工具类

### 5.1 Helpers

**功能**：提供通用的工具方法。

**主要方法**：

| 方法名 | 参数 | 返回值 | 描述 |
|--------|------|--------|------|
| `generateId` | - | String | 生成唯一ID |
| `formatPercentage` | value: double | String | 格式化百分比 |
| `formatConcentration` | value: double | String | 格式化浓度 |
| `getRiskLevelColor` | level: RiskLevel | Color | 获取风险等级对应的颜色 |
| `calculateMean` | values: List<double> | double | 计算平均值 |
| `calculateStdDev` | values: List<double> | double | 计算标准差 |
| `showSnackBar` | context: BuildContext, message: String, isError: bool | void | 显示提示信息 |
| `showSuccessSnackBar` | context: BuildContext, message: String | void | 显示成功提示信息 |

### 5.2 AppConstants

**功能**：提供应用常量。

**主要常量**：

| 常量名 | 类型 | 描述 |
|--------|------|------|
| `appName` | String | 应用名称 |
| `appVersion` | String | 应用版本 |
| `primaryColor` | Color | 主颜色 |
| `accentColor` | Color | 强调色 |
| `successColor` | Color | 成功颜色 |
| `warningColor` | Color | 警告颜色 |
| `errorColor` | Color | 错误颜色 |
| `paddingSmall` | double | 小间距 |
| `paddingMedium` | double | 中间距 |
| `paddingLarge` | double | 大间距 |
| `borderRadius` | double | 边框半径 |

### 5.3 RouteNames

**功能**：提供路由名称常量。

**主要常量**：

| 常量名 | 类型 | 描述 |
|--------|------|------|
| `home` | String | 首页路由 |
| `detection` | String | 检测页面路由 |
| `history` | String | 历史记录页面路由 |
| `settings` | String | 设置页面路由 |
| `deviceConnection` | String | 设备连接页面路由 |
| `login` | String | 登录页面路由 |
| `register` | String | 注册页面路由 |

## 6. 枚举类型

### 6.1 RiskLevel

**功能**：表示风险等级的枚举。

**值**：

| 值 | 描述 |
|-----|------|
| `safe` | 安全 |
| `low` | 低风险 |
| `medium` | 中等风险 |
| `high` | 高风险 |
| `critical` | 严重超标 |

### 6.2 PesticideType

**功能**：表示农药类型的枚举。

**值**：

| 值 | 描述 |
|-----|------|
| `organophosphate` | 有机磷类 |
| `carbamate` | 氨基甲酸酯类 |
| `pyrethroid` | 拟除虫菊酯类 |
| `neonicotinoid` | 新烟碱类 |
| `other` | 其他类型 |

### 6.3 AppErrorType

**功能**：表示错误类型的枚举。

**值**：

| 值 | 描述 |
|-----|------|
| `general` | 通用错误 |
| `network` | 网络错误 |
| `bluetooth` | 蓝牙错误 |
| `storage` | 存储错误 |
| `ai_model` | AI模型错误 |
| `device` | 设备错误 |

### 6.4 AnalysisMode

**功能**：表示分析模式的枚举。

**值**：

| 值 | 描述 |
|-----|------|
| `import` | 导入模式 |
| `deepLearning` | 深度学习模式（Flutter端CNN-1D） |
| `randomForest` | 随机森林模式（Streamlit Web端sklearn RF） |
| `ruleEngine` | 规则引擎模式（降级方案） |
| `hybrid` | 混合模式（ML模型 + 规则引擎自适应融合） |

### 6.5 DeviceConnectionState

**功能**：表示设备连接状态的枚举。

**值**：

| 值 | 描述 |
|-----|------|
| `disconnected` | 未连接 |
| `connecting` | 连接中 |
| `connected` | 已连接 |
| `disconnecting` | 断开连接中 |

## 7. 服务初始化和依赖注入

### 7.1 服务初始化

应用在启动时会初始化以下服务：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 初始化存储服务
    await StorageService().init();

    // 初始化错误处理服务
    ErrorHandlingService().initialize();

    // 初始化性能监控服务
    PerformanceMonitorService().initialize();

    // 初始化安全服务
    await SecurityService().initialize();

    // 初始化日志服务
    await LoggingService().initialize();
  } catch (e, stackTrace) {
    print('服务初始化失败: $e');
    print(stackTrace);
  }

  runApp(const PesticideDetectorApp());
}
```

### 7.2 依赖注入

应用使用Provider进行状态管理和依赖注入：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AppProvider()),
    ChangeNotifierProvider(create: (_) => DetectionProvider()),
    ChangeNotifierProvider(create: (_) => HistoryProvider()),
  ],
  child: Consumer<AppProvider>(
    builder: (context, appProvider, _) {
      return MaterialApp(
        // 应用配置
      );
    },
  ),
);
```

## 8. 调用示例

### 8.1 完整的检测流程

```dart
// 1. 初始化服务
final bluetoothService = BluetoothService();
final aiService = AIAnalysisService();
final storageService = StorageService();
await storageService.init();

// 2. 连接设备
await bluetoothService.connectToDevice('device_id');

// 3. 开始数据采集
await bluetoothService.startDataCollection();

// 4. 监听光谱数据
StreamSubscription<SpectralData>? subscription;
SpectralData? spectralData;

subscription = bluetoothService.spectralDataStream.listen((data) {
  spectralData = data;
  // 可以在这里实时显示光谱数据
});

// 5. 停止数据采集
await bluetoothService.stopDataCollection();
await subscription?.cancel();

// 6. 分析数据
if (spectralData != null) {
  final result = await aiService.analyzeWithDeepLearning(
    spectralData: spectralData!,
    sampleName: '苹果',
    sampleCategory: '水果类',
  );

  // 7. 保存结果
  await storageService.saveDetectionResult(result);

  // 8. 显示结果
  print('检测完成，风险等级: ${result.riskLevel}');
}

// 9. 断开设备
await bluetoothService.disconnect();
```

### 8.2 数据导入和分析

```dart
// 1. 初始化服务
final importService = DataImportService();
final aiService = AIAnalysisService();

// 2. 选择并导入文件
final importResult = await importService.pickAndImportFile();

if (importResult.isSuccess && importResult.data != null) {
  // 3. 验证数据
  final validation = importService.validateImportedData(importResult.data!);
  
  if (validation.isValid && importResult.data!.hasValidSpectralData) {
    // 4. 分析数据
    final result = await aiService.analyzeWithHybridMode(
      spectralData: importResult.data!.spectralData!,
      sampleName: '导入样品',
      sampleCategory: '未知',
    );

    // 5. 显示结果
    print('分析完成，风险等级: ${result.riskLevel}');
  } else {
    // 显示验证错误
    print('数据验证失败: ${validation.issues.join(', ')}');
  }
} else {
  // 显示导入错误
  print('文件导入失败: ${importResult.error}');
}
```

## 9. 最佳实践

### 9.1 错误处理

始终使用try-catch块捕获可能的错误，并使用ErrorHandlingService报告错误：

```dart
try {
  // 可能出错的代码
} catch (e, stack) {
  ErrorHandlingService().reportError(
    type: AppErrorType.general,
    message: '操作失败',
    error: e,
    stackTrace: stack,
  );
  Helpers.showSnackBar(context, '操作失败，请重试', isError: true);
}
```

### 9.2 服务使用

- 对于频繁使用的服务，考虑在类级别创建实例，而不是每次使用时都创建新实例
- 对于需要初始化的服务，确保在使用前完成初始化
- 对于有 dispose 方法的服务，确保在适当的时候调用 dispose 方法释放资源

### 9.3 性能优化

- 使用 async/await 进行异步操作，避免阻塞UI线程
- 使用 Future.wait 并行执行多个异步操作
- 对于大数据集，考虑使用分页或流式处理
- 对于频繁更新的UI，使用 const 构造函数和 const 变量

### 9.4 代码规范

- 遵循Dart语言规范和Flutter最佳实践
- 使用清晰、一致的命名规则
- 为关键代码添加详细注释
- 保持代码结构清晰，模块化设计

## 10. 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.0.0 | 2024-01-01 | 首次发布 |
| 1.1.0 | 2026-03-29 | Streamlit Web端: CNN替换为sklearn RandomForest, 移除模拟检测, SHAP/特征重要性/CI基于真实模型输出, 进度条与实际计算关联 |

---

© 2024 农药残留检测APP. 保留所有权利。