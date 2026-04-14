/// 原始光谱点实体
class SpectrumPoint {
  /// 波长 (nm)
  final double wavelength;
  
  /// 强度 (吸光度/反射率)
  final double intensity;

  SpectrumPoint({
    required this.wavelength,
    required this.intensity,
  });

  @override
  String toString() => 'SpectrumPoint(wavelength: $wavelength, intensity: $intensity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpectrumPoint &&
        other.wavelength == wavelength &&
        other.intensity == intensity;
  }

  @override
  int get hashCode => wavelength.hashCode ^ intensity.hashCode;

  SpectrumPoint copyWith({
    double? wavelength,
    double? intensity,
  }) {
    return SpectrumPoint(
      wavelength: wavelength ?? this.wavelength,
      intensity: intensity ?? this.intensity,
    );
  }
}
