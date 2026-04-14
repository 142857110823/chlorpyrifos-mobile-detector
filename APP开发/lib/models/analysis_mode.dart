/// 分析模式枚举
enum AnalysisMode {
  import, // 文件导入模式
  mock, // 模拟模式
  deepLearning, // 实时采集模式（深度学习）
  ruleEngine, // 仅规则引擎
  hybrid, // 混合模式（推荐）
}

/// 分析模式扩展
extension AnalysisModeExtension on AnalysisMode {
  /// 获取分析模式的显示名称
  String get displayName {
    switch (this) {
      case AnalysisMode.import:
        return '文件导入';
      case AnalysisMode.mock:
        return '模拟数据';
      case AnalysisMode.deepLearning:
        return '深度学习';
      case AnalysisMode.ruleEngine:
        return '规则引擎';
      case AnalysisMode.hybrid:
        return '混合模式';
    }
  }

  /// 获取分析模式的描述
  String get description {
    switch (this) {
      case AnalysisMode.import:
        return '从CSV/Excel文件导入光谱数据进行分析';
      case AnalysisMode.mock:
        return '使用模拟数据进行演示，适合开发测试和功能展示';
      case AnalysisMode.deepLearning:
        return '使用深度学习模型进行分析，精度更高';
      case AnalysisMode.ruleEngine:
        return '使用规则引擎进行分析，速度更快';
      case AnalysisMode.hybrid:
        return '同时使用深度学习和规则引擎，平衡精度和速度';
    }
  }
}
