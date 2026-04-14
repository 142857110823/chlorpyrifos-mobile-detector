import 'package:flutter/material.dart';
import '../../ml/explainability/explainability.dart';

/// SHAP瀑布图
/// 展示各特征对预测结果的累积贡献
class ShapWaterfallChart extends StatelessWidget {
  /// SHAP值数据
  final ShapValues shapValues;

  /// 预测类别
  final String predictedClass;

  /// 图表高度
  final double height;

  /// 最多显示的特征数量
  final int maxFeatures;

  /// 标题
  final String? title;

  const ShapWaterfallChart({
    super.key,
    required this.shapValues,
    required this.predictedClass,
    this.height = 350,
    this.maxFeatures = 10,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // 准备数据：按绝对值排序取Top-K
    final sortedFeatures = shapValues.features.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final topFeatures = sortedFeatures.take(maxFeatures).toList();

    // 计算累积值
    final cumulativeValues = <double>[shapValues.baseline];
    for (final feature in topFeatures) {
      cumulativeValues.add(cumulativeValues.last + feature.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

        // 基准值
        _buildBaselineRow(context),

        // 特征贡献
        SizedBox(
          height: height - 100,
          child: ListView.builder(
            itemCount: topFeatures.length,
            itemBuilder: (context, index) {
              return _buildFeatureRow(
                context,
                topFeatures[index],
                cumulativeValues[index],
                cumulativeValues[index + 1],
                index,
              );
            },
          ),
        ),

        // 最终预测
        _buildFinalRow(context, cumulativeValues.last),

        // 图例
        _buildLegend(context),
      ],
    );
  }

  Widget _buildBaselineRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('基准值', style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shapValues.baseline.toStringAsFixed(3),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    MapEntry<String, double> feature,
    double startValue,
    double endValue,
    int index,
  ) {
    final isPositive = feature.value > 0;
    final color = isPositive ? Colors.green : Colors.orange;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    // 计算条形宽度（基于贡献值的绝对大小）
    final maxAbs = shapValues.features.values
        .map((v) => v.abs())
        .fold(0.0, (a, b) => a > b ? a : b);
    final barWidthPercent = maxAbs > 0 ? feature.value.abs() / maxAbs : 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          // 特征名称
          SizedBox(
            width: 100,
            child: Text(
              feature.key,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 贡献条形
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Positioned(
                  left: isPositive ? null : 0,
                  right: isPositive ? 0 : null,
                  child: Container(
                    height: 24,
                    width: 150 * barWidthPercent + 20,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: isPositive
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isPositive) const SizedBox(width: 4),
                        Icon(icon, size: 14, color: Colors.white),
                        if (isPositive) const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 贡献值
          SizedBox(
            width: 70,
            child: Text(
              '${isPositive ? "+" : ""}${feature.value.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRow(BuildContext context, double finalValue) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics,
              size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            '最终预测 ($predictedClass)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              finalValue.toStringAsFixed(3),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(Colors.green, '正向贡献'),
          const SizedBox(width: 24),
          _legendItem(Colors.orange, '负向贡献'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// 置信度仪表盘
class ConfidenceGauge extends StatelessWidget {
  /// 置信区间数据
  final ConfidenceInterval confidence;

  /// 预测值
  final double prediction;

  /// 尺寸
  final double size;

  /// 标题
  final String? title;

  const ConfidenceGauge({
    super.key,
    required this.confidence,
    required this.prediction,
    this.size = 180,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              value: prediction,
              lower: confidence.lower,
              upper: confidence.upper,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(prediction * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: size / 5,
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(confidence.width),
                    ),
                  ),
                  Text(
                    confidence.confidenceLevel,
                    style: TextStyle(
                      fontSize: size / 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 置信区间信息
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _infoRow('95%置信区间',
                  '[${(confidence.lower * 100).toStringAsFixed(1)}%, ${(confidence.upper * 100).toStringAsFixed(1)}%]'),
              _infoRow('均值', '${(confidence.mean * 100).toStringAsFixed(1)}%'),
              _infoRow('标准差', '${(confidence.std * 100).toStringAsFixed(2)}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double width) {
    if (width < 0.1) return Colors.green;
    if (width < 0.2) return Colors.blue;
    if (width < 0.3) return Colors.orange;
    return Colors.red;
  }
}

/// 仪表盘绘制器
class _GaugePainter extends CustomPainter {
  final double value;
  final double lower;
  final double upper;

  _GaugePainter({
    required this.value,
    required this.lower,
    required this.upper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // 背景圆弧
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.4, // 起始角度
      4.9, // 弧度范围
      false,
      bgPaint,
    );

    // 置信区间弧
    final intervalPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    final startAngle = 2.4 + lower * 4.9;
    final sweepAngle = (upper - lower) * 4.9;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      intervalPaint,
    );

    // 值指示弧
    final valuePaint = Paint()
      ..color = _getValueColor(value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.4,
      value * 4.9,
      false,
      valuePaint,
    );

    // 指针
    final pointerAngle = 2.4 + value * 4.9;
    final pointerLength = radius - 5;
    final pointerEnd = Offset(
      center.dx + pointerLength * _cos(pointerAngle),
      center.dy + pointerLength * _sin(pointerAngle),
    );

    final pointerPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, pointerEnd, pointerPaint);

    // 中心点
    final centerPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 5, centerPaint);
  }

  double _cos(double radians) => radians < 3.14159
      ? -1 + (radians - 2.4) / 2.45
      : 1 - (radians - 4.85) / 2.45;

  double _sin(double radians) => radians < 4.85
      ? -_sqrt(1 - _pow(_cos(radians), 2))
      : _sqrt(1 - _pow(_cos(radians), 2));

  double _sqrt(double x) => x > 0 ? x * 0.5 + 0.5 : 0;
  double _pow(double x, int n) => x * x;

  Color _getValueColor(double val) {
    if (val < 0.3) return Colors.red;
    if (val < 0.5) return Colors.orange;
    if (val < 0.7) return Colors.yellow.shade700;
    return Colors.green;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
