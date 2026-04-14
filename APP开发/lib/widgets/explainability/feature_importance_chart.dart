import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../ml/explainability/explainability.dart';

/// 特征重要性条形图
/// 展示Top-K重要特征的SHAP贡献值
class FeatureImportanceChart extends StatelessWidget {
  /// 特征重要性数据
  final FeatureImportance importance;

  /// 图表高度
  final double height;

  /// 最多显示的特征数量
  final int maxFeatures;

  /// 标题
  final String? title;

  /// 是否显示数值标签
  final bool showValues;

  const FeatureImportanceChart({
    super.key,
    required this.importance,
    this.height = 300,
    this.maxFeatures = 10,
    this.title,
    this.showValues = true,
  });

  @override
  Widget build(BuildContext context) {
    final features = importance.topFeatures.entries.take(maxFeatures).toList();

    if (features.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('暂无特征重要性数据'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(features),
              minY: _getMinY(features),
              barGroups: _buildBarGroups(features, context),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateInterval(features),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 80,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= features.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: Text(
                            features[index].key,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget:
                      const Text('贡献值', style: TextStyle(fontSize: 12)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(3),
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex >= features.length) return null;
                    final entry = features[groupIndex];
                    return BarTooltipItem(
                      '${entry.key}\n贡献: ${entry.value.toStringAsFixed(4)}\n${entry.value > 0 ? "正向影响" : "负向影响"}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // 图例
        _buildLegend(context),
      ],
    );
  }

  List<BarChartGroupData> _buildBarGroups(
    List<MapEntry<String, double>> features,
    BuildContext context,
  ) {
    return features.asMap().entries.map((entry) {
      final index = entry.key;
      final feature = entry.value;
      final isPositive = feature.value > 0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: feature.value,
            color: isPositive ? Colors.green : Colors.orange,
            width: 20,
            borderRadius: isPositive
                ? const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  )
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
          ),
        ],
        showingTooltipIndicators: showValues ? [0] : [],
      );
    }).toList();
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(Colors.green, '正向贡献（增加预测概率）'),
          const SizedBox(width: 24),
          _legendItem(Colors.orange, '负向贡献（降低预测概率）'),
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
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  double _getMaxY(List<MapEntry<String, double>> features) {
    final maxValue =
        features.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return maxValue > 0 ? maxValue * 1.2 : 0.01;
  }

  double _getMinY(List<MapEntry<String, double>> features) {
    final minValue =
        features.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    return minValue < 0 ? minValue * 1.2 : 0;
  }

  double _calculateInterval(List<MapEntry<String, double>> features) {
    final maxAbs =
        features.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b);
    return maxAbs / 4;
  }
}

/// 波段重要性饼图
/// 展示各光谱波段的相对重要性
class BandImportancePieChart extends StatelessWidget {
  /// 特征重要性数据
  final FeatureImportance importance;

  /// 图表尺寸
  final double size;

  /// 标题
  final String? title;

  const BandImportancePieChart({
    super.key,
    required this.importance,
    this.size = 200,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final bands = importance.spectralBands.entries.toList();

    if (bands.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text('暂无波段数据'),
        ),
      );
    }

    final total = bands.map((e) => e.value).fold(0.0, (a, b) => a + b);

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
          child: PieChart(
            PieChartData(
              sections: bands.asMap().entries.map((entry) {
                final band = entry.value;
                final percentage = total > 0 ? (band.value / total * 100) : 0;

                return PieChartSectionData(
                  value: band.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  color: _getBandColor(band.key),
                  radius: size / 3,
                );
              }).toList(),
              centerSpaceRadius: size / 6,
              sectionsSpace: 2,
            ),
          ),
        ),

        // 图例
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: bands.map((band) {
            return _legendItem(
              _getBandColor(band.key),
              band.key,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Color _getBandColor(String band) {
    if (band.contains('UV')) return const Color(0xFF9C27B0); // 紫色
    if (band.contains('可见光')) return const Color(0xFF4CAF50); // 绿色
    if (band.contains('近红外')) return const Color(0xFFF44336); // 红色
    return Colors.grey;
  }
}
