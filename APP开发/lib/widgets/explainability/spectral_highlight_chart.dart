import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../ml/explainability/explainability.dart';

/// 带SHAP贡献高亮的光谱图
/// 在原始光谱曲线上叠加SHAP值热力图
class SpectralHighlightChart extends StatelessWidget {
  /// 波长数据
  final List<double> wavelengths;

  /// 强度数据
  final List<double> intensities;

  /// SHAP贡献值
  final List<double> shapContributions;

  /// 关键波长列表
  final List<CriticalWavelength> criticalWavelengths;

  /// 图表高度
  final double height;

  /// 是否显示关键波长标注
  final bool showMarkers;

  /// 是否显示热力图背景
  final bool showHeatmap;

  /// 标题
  final String? title;

  const SpectralHighlightChart({
    super.key,
    required this.wavelengths,
    required this.intensities,
    required this.shapContributions,
    this.criticalWavelengths = const [],
    this.height = 300,
    this.showMarkers = true,
    this.showHeatmap = true,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
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
          child: Stack(
            children: [
              // 主图表
              _buildMainChart(context),

              // 关键波长标注
              if (showMarkers && criticalWavelengths.isNotEmpty)
                _buildCriticalMarkers(context),
            ],
          ),
        ),

        // 图例
        _buildLegend(context),
      ],
    );
  }

  Widget _buildMainChart(BuildContext context) {
    // 准备光谱数据点
    final spectralSpots = <FlSpot>[];
    for (var i = 0; i < wavelengths.length && i < intensities.length; i++) {
      spectralSpots.add(FlSpot(wavelengths[i], intensities[i]));
    }

    // 准备SHAP数据点（归一化用于显示）
    final maxShap = shapContributions
        .map((v) => v.abs())
        .fold(0.0, (a, b) => a > b ? a : b);
    final normalizedShap =
        shapContributions.map((v) => maxShap > 0 ? v / maxShap : 0.0).toList();

    return LineChart(
      LineChartData(
        minX: wavelengths.isNotEmpty ? wavelengths.first : 200,
        maxX: wavelengths.isNotEmpty ? wavelengths.last : 1100,
        lineBarsData: [
          // 光谱曲线
          LineChartBarData(
            spots: spectralSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Theme.of(context).primaryColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: showHeatmap
                ? BarAreaData(
                    show: true,
                    gradient: _buildShapGradient(normalizedShap),
                  )
                : BarAreaData(show: false),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          horizontalInterval: _calculateInterval(intensities),
          verticalInterval: 100,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget:
                const Text('波长 (nm)', style: TextStyle(fontSize: 12)),
            axisNameSize: 20,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 200,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('强度', style: TextStyle(fontSize: 12)),
            axisNameSize: 20,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = wavelengths.indexOf(spot.x);
                final shapValue = index >= 0 && index < shapContributions.length
                    ? shapContributions[index]
                    : 0.0;
                return LineTooltipItem(
                  '波长: ${spot.x.toInt()}nm\n'
                  '强度: ${spot.y.toStringAsFixed(1)}\n'
                  'SHAP: ${shapValue.toStringAsFixed(4)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalMarkers(BuildContext context) {
    if (wavelengths.isEmpty) return const SizedBox();

    final minWl = wavelengths.first;
    final maxWl = wavelengths.last;
    final wlRange = maxWl - minWl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth - 65; // 减去左侧坐标轴宽度
        final chartLeft = 45.0; // 左侧坐标轴宽度

        return Stack(
          children: criticalWavelengths.take(5).map((cw) {
            final xPos =
                chartLeft + (cw.wavelength - minWl) / wlRange * chartWidth;

            return Positioned(
              left: xPos - 15,
              top: 10,
              child: GestureDetector(
                onTap: () => _showCriticalWavelengthInfo(context, cw),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: cw.isPositive ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        border: Border.all(
                          color: cw.isPositive ? Colors.green : Colors.red,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        '${cw.wavelength.toInt()}nm',
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(context, Colors.blue, '负贡献'),
          const SizedBox(width: 16),
          _legendItem(context, Colors.grey.shade300, '无贡献'),
          const SizedBox(width: 16),
          _legendItem(context, Colors.red, '正贡献'),
          if (showMarkers) ...[
            const SizedBox(width: 16),
            const Icon(Icons.location_on, color: Colors.green, size: 16),
            const Text(' 关键波长', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  LinearGradient _buildShapGradient(List<double> normalizedShap) {
    // 创建基于SHAP值的渐变色
    final colors = <Color>[];
    final stops = <double>[];

    final step = normalizedShap.length > 10 ? normalizedShap.length ~/ 10 : 1;
    for (var i = 0; i < normalizedShap.length; i += step) {
      colors.add(_shapValueToColor(normalizedShap[i]));
      stops.add(i / normalizedShap.length);
    }

    // 确保有结束点
    if (stops.isEmpty || stops.last != 1.0) {
      colors.add(_shapValueToColor(normalizedShap.last));
      stops.add(1.0);
    }

    return LinearGradient(
      colors: colors,
      stops: stops,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  Color _shapValueToColor(double value) {
    // SHAP值映射到颜色：负值蓝色，正值红色
    if (value < 0) {
      return Colors.blue.withValues(alpha: value.abs().clamp(0.0, 0.7));
    } else if (value > 0) {
      return Colors.red.withValues(alpha: value.clamp(0.0, 0.7));
    } else {
      return Colors.grey.withValues(alpha: 0.1);
    }
  }

  double _calculateInterval(List<double> data) {
    if (data.isEmpty) return 100;
    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);
    final range = max - min;
    return range / 5;
  }

  void _showCriticalWavelengthInfo(
      BuildContext context, CriticalWavelength cw) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('关键波长: ${cw.wavelength.toInt()}nm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('贡献值', cw.contribution.toStringAsFixed(4)),
            _infoRow('重要性', '${(cw.importance * 100).toStringAsFixed(1)}%'),
            _infoRow('贡献类型', cw.isPositive ? '正向贡献' : '负向贡献'),
            const Divider(),
            Text(
              '化学意义',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(cw.reason),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
