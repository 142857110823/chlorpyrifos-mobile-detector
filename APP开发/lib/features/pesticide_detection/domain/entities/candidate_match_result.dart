import 'spectrum_peak.dart';

/// 单个候选匹配结果实体
class CandidateMatchResult {
  /// 农药ID
  final String pesticideId;
  
  /// 农药名称
  final String pesticideName;
  
  /// 皮尔逊相关系数得分
  final double pearsonScore;
  
  /// 余弦相似度得分
  final double cosineScore;
  
  /// 欧氏距离得分
  final double euclideanScore;
  
  /// DTW相似度得分
  final double dtwScore;
  
  /// 峰值匹配得分
  final double peakMatchScore;
  
  /// 导数谱相似度得分
  final double derivativeScore;
  
  /// 综合得分
  final double compositeScore;
  
  /// 匹配的峰
  final List<SpectrumPeak> matchedPeaks;
  
  /// 不匹配的原因
  final List<String> mismatchReasons;

  CandidateMatchResult({
    required this.pesticideId,
    required this.pesticideName,
    required this.pearsonScore,
    required this.cosineScore,
    required this.euclideanScore,
    required this.dtwScore,
    required this.peakMatchScore,
    required this.derivativeScore,
    required this.compositeScore,
    required this.matchedPeaks,
    required this.mismatchReasons,
  });

  @override
  String toString() => 'CandidateMatchResult(pesticideName: $pesticideName, compositeScore: $compositeScore)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CandidateMatchResult &&
        other.pesticideId == pesticideId &&
        other.compositeScore == compositeScore;
  }

  @override
  int get hashCode => pesticideId.hashCode ^ compositeScore.hashCode;

  CandidateMatchResult copyWith({
    String? pesticideId,
    String? pesticideName,
    double? pearsonScore,
    double? cosineScore,
    double? euclideanScore,
    double? dtwScore,
    double? peakMatchScore,
    double? derivativeScore,
    double? compositeScore,
    List<SpectrumPeak>? matchedPeaks,
    List<String>? mismatchReasons,
  }) {
    return CandidateMatchResult(
      pesticideId: pesticideId ?? this.pesticideId,
      pesticideName: pesticideName ?? this.pesticideName,
      pearsonScore: pearsonScore ?? this.pearsonScore,
      cosineScore: cosineScore ?? this.cosineScore,
      euclideanScore: euclideanScore ?? this.euclideanScore,
      dtwScore: dtwScore ?? this.dtwScore,
      peakMatchScore: peakMatchScore ?? this.peakMatchScore,
      derivativeScore: derivativeScore ?? this.derivativeScore,
      compositeScore: compositeScore ?? this.compositeScore,
      matchedPeaks: matchedPeaks ?? this.matchedPeaks,
      mismatchReasons: mismatchReasons ?? this.mismatchReasons,
    );
  }
}
