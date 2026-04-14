import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/detection_result.dart';

/// Historical detection trend line chart
class DetectionTrendChart extends StatelessWidget {
  final List<DetectionResult> history;

  const DetectionTrendChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No historical data'));
    }
    final sortedHistory = List<DetectionResult>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 0.2,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < sortedHistory.length) {
                  final date = sortedHistory[idx].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${date.month}/${date.day}',
                        style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 0.2,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 0,
        maxX: (sortedHistory.length - 1).toDouble(),
        minY: 0,
        maxY: 1,
        lineBarsData: [
          LineChartBarData(
            spots: sortedHistory
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.confidence))
                .toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final result = sortedHistory[index];
                return FlDotCirclePainter(
                  radius: 5,
                  color: result.isQualified ? Colors.green : Colors.red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final result = sortedHistory[spot.spotIndex];
                return LineTooltipItem(
                  '${result.sampleName}\n${(result.confidence * 100).toStringAsFixed(1)}%\n${result.isQualified ? "Pass" : "Fail"}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

/// Pass/fail statistics pie chart
class PassFailPieChart extends StatelessWidget {
  final int passCount;
  final int failCount;

  const PassFailPieChart(
      {super.key, required this.passCount, required this.failCount});

  @override
  Widget build(BuildContext context) {
    final total = passCount + failCount;
    if (total == 0) {
      return const Center(child: Text('No data'));
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: Colors.green,
            value: passCount.toDouble(),
            title: '${(passCount / total * 100).toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            color: Colors.red,
            value: failCount.toDouble(),
            title: '${(failCount / total * 100).toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
