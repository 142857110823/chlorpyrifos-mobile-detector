/// 光谱峰实体
class SpectrumPeak {
  /// 峰位波长 (nm)
  final double wavelength;
  
  /// 峰强度
  final double intensity;
  
  /// 峰高（相对于基线）
  final double prominence;
  
  /// 峰宽
  final double width;
  
  /// 峰面积
  final double area;
  
  /// 峰类型（主峰、次峰等）
  final String type;

  SpectrumPeak({
    required this.wavelength,
    required this.intensity,
    required this.prominence,
    required this.width,
    required this.area,
    required this.type,
  });

  @override
  String toString() => 'SpectrumPeak(wavelength: $wavelength, intensity: $intensity, type: $type)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpectrumPeak &&
        other.wavelength == wavelength &&
        other.intensity == intensity &&
        other.type == type;
  }

  @override
  int get hashCode => wavelength.hashCode ^ intensity.hashCode ^ type.hashCode;

  SpectrumPeak copyWith({
    double? wavelength,
    double? intensity,
    double? prominence,
    double? width,
    double? area,
    String? type,
  }) {
    return SpectrumPeak(
      wavelength: wavelength ?? this.wavelength,
      intensity: intensity ?? this.intensity,
      prominence: prominence ?? this.prominence,
      width: width ?? this.width,
      area: area ?? this.area,
      type: type ?? this.type,
    );
  }
}
