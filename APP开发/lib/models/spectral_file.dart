/// 光谱文件数据模型
/// 支持 JCAMP-DX (.dx) 和 SPC (.spc) 格式

/// 光谱文件格式枚举
enum SpectralFileFormat {
  dx, // JCAMP-DX 格式 (.dx)
  spc, // SPC 格式 (.spc)
}

/// 光谱类型枚举
enum SpectralType {
  uv, // 紫外-可见光谱
  ir, // 红外光谱
  raman, // 拉曼光谱
  unknown,
}

/// 解析后的光谱文件数据
class SpectralFileData {
  /// 文件标题
  final String title;

  /// CAS 注册号 (毒死蜱: 2921-88-2)
  final String? casNumber;

  /// 光谱类型
  final SpectralType spectralType;

  /// 文件格式
  final SpectralFileFormat format;

  /// 波长/波数数组 (X轴)
  final List<double> wavelengths;

  /// 吸光度/强度数组 (Y轴)
  final List<double> intensities;

  /// X轴单位 (nm, 1/CM 等)
  final String xUnits;

  /// Y轴单位 (ABSORBANCE, TRANSMITTANCE 等)
  final String yUnits;

  /// 数据点数
  int get dataPointCount => wavelengths.length;

  /// 文件元数据
  final Map<String, String> metadata;

  /// 毒死蜱特征峰标注
  /// UV: 228nm, 293nm
  /// IR: 1260cm⁻¹, 1040cm⁻¹, 960cm⁻¹, 680cm⁻¹
  /// Raman: 680cm⁻¹, 720cm⁻¹
  List<double> get characteristicPeaks {
    switch (spectralType) {
      case SpectralType.uv:
        return [228.0, 293.0];
      case SpectralType.ir:
        return [1260.0, 1040.0, 960.0, 680.0];
      case SpectralType.raman:
        return [680.0, 720.0];
      case SpectralType.unknown:
        return [];
    }
  }

  SpectralFileData({
    required this.title,
    this.casNumber,
    required this.spectralType,
    required this.format,
    required this.wavelengths,
    required this.intensities,
    this.xUnits = 'nm',
    this.yUnits = 'ABSORBANCE',
    this.metadata = const {},
  });

  /// 验证是否为毒死蜱光谱
  bool get isChlorpyrifos => casNumber == '2921-88-2';
}

/// 光谱文件验证结果
class SpectralFileValidation {
  /// 是否有效
  final bool isValid;

  /// 验证问题列表
  final List<String> issues;

  /// 警告列表
  final List<String> warnings;

  SpectralFileValidation({
    required this.isValid,
    this.issues = const [],
    this.warnings = const [],
  });

  factory SpectralFileValidation.valid({List<String> warnings = const []}) {
    return SpectralFileValidation(isValid: true, warnings: warnings);
  }

  factory SpectralFileValidation.invalid(List<String> issues) {
    return SpectralFileValidation(isValid: false, issues: issues);
  }
}
