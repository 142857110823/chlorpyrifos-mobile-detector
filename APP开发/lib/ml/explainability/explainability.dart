/// AI可解释性模块
/// 提供模型预测的可解释性分析功能
/// 
/// 核心组件:
/// - [ModelExplainer] - 主解释器，整合所有分析功能
/// - [ShapApproximator] - SHAP值近似计算
/// - [FeatureImportanceAnalyzer] - 特征重要性分析
/// - [ExplainabilityResult] - 分析结果数据结构

library explainability;

export 'explainability_result.dart';
export 'feature_importance_analyzer.dart';
export 'shap_approximator.dart';
export 'model_explainer.dart';
