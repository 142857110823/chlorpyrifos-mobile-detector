import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/detection_result.dart';

/// Pesticide concentration comparison chart
class PesticideConcentrationChart extends StatelessWidget {
  final List<PesticideResult> pesticideResults;

  const PesticideConcentrationChart(
      {super.key, required this.pesticideResults});

  @override
  Widget build(BuildContext context) {
    if (pesticideResults.isEmpty) {
      return const Center(child: Text('暂无检测数据'));
    }
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = pesticideResults[groupIndex];
              return BarTooltipItem(
                '${p.name}\n${rodIndex == 0 ? "检出值" : "限量"}: ${rod.toY.toStringAsFixed(4)} mg/kg',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < pesticideResults.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      pesticideResults[idx].name.length > 6
                          ? '${pesticideResults[idx].name.substring(0, 6)}...'
                          : pesticideResults[idx].name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(3),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _buildBarGroups(),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  double _getMaxY() {
    double maxConc = 0;
    double maxLimit = 0;
    for (final p in pesticideResults) {
      if (p.concentration > maxConc) maxConc = p.concentration;
      if (p.limit > maxLimit) maxLimit = p.limit;
    }
    return (maxConc > maxLimit ? maxConc : maxLimit) * 1.2;
  }

  List<BarChartGroupData> _buildBarGroups() {
    return pesticideResults.asMap().entries.map((entry) {
      final idx = entry.key;
      final p = entry.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: p.concentration,
            color: p.exceedsLimit ? Colors.red : Colors.green,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: p.limit,
            color: Colors.orange.withValues(alpha: 0.7),
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }
}
