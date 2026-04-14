import 'candidate_match_result.dart';
import 'spectrum_point.dart';

/// 最终农药识别结果实体
class PesticideIdentificationResult {
  /// 最终标签
  final String finalLabel;
  
  /// 置信度
  final double confidence;
  
  /// 是否可靠
  final bool isReliable;
  
  /// 候选排名
  final List<CandidateMatchResult> ranking;
  
  /// 图像质量评分
  final double imageQualityScore;
  
  /// 警告信息
  final List<String> warnings;
  
  /// 解释
  final String explanation;
  
  /// 叠加数据（用于可视化）
  final Map<String, List<SpectrumPoint>> overlayData;

  PesticideIdentificationResult({
    required this.finalLabel,
    required this.confidence,
    required this.isReliable,
    required this.ranking,
    required this.imageQualityScore,
    required this.warnings,
    required this.explanation,
    required this.overlayData,
  });

  @override
  String toString() => 'PesticideIdentificationResult(finalLabel: $finalLabel, confidence: $confidence, isReliable: $isReliable)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PesticideIdentificationResult &&
        other.finalLabel == finalLabel &&
        other.confidence == confidence &&
        other.isReliable == isReliable;
  }

  @override
  int get hashCode => finalLabel.hashCode ^ confidence.hashCode ^ isReliable.hashCode;

  PesticideIdentificationResult copyWith({
    String? finalLabel,
    double? confidence,
    bool? isReliable,
    List<CandidateMatchResult>? ranking,
    double? imageQualityScore,
    List<String>? warnings,
    String? explanation,
    Map<String, List<SpectrumPoint>>? overlayData,
  }) {
    return PesticideIdentificationResult(
      finalLabel: finalLabel ?? this.finalLabel,
      confidence: confidence ?? this.confidence,
      isReliable: isReliable ?? this.isReliable,
      ranking: ranking ?? this.ranking,
      imageQualityScore: imageQualityScore ?? this.imageQualityScore,
      warnings: warnings ?? this.warnings,
      explanation: explanation ?? this.explanation,
      overlayData: overlayData ?? this.overlayData,
    );
  }
}
