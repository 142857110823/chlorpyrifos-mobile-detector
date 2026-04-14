import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/detection_result.dart';

/// Risk assessment radar chart
class RiskRadarChart extends StatelessWidget {
  final DetectionResult result;

  const RiskRadarChart({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBorderData: const BorderSide(color: Colors.grey, width: 1),
        gridBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
        tickBorderData: const BorderSide(color: Colors.transparent),
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        titleTextStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        getTitle: (index, angle) => RadarChartTitle(
          text: _getTitleText(index),
          angle: 0,
        ),
        dataSets: [
          RadarDataSet(
            fillColor: Colors.blue.withValues(alpha: 0.2),
            borderColor: Colors.blue,
            borderWidth: 2,
            entryRadius: 3,
            dataEntries: _buildDataEntries(),
          ),
          RadarDataSet(
            fillColor: Colors.transparent,
            borderColor: Colors.red.withValues(alpha: 0.5),
            borderWidth: 1,
            entryRadius: 0,
            dataEntries: List.generate(5, (_) => const RadarEntry(value: 0.8)),
          ),
        ],
      ),
    );
  }

  String _getTitleText(int index) {
    switch (index) {
      case 0:
        return 'Confidence';
      case 1:
        return 'Safety';
      case 2:
        return 'Accuracy';
      case 3:
        return 'Stability';
      case 4:
        return 'Quality';
      default:
        return '';
    }
  }

  List<RadarEntry> _buildDataEntries() {
    final exceededRatio = result.pesticideResults.isEmpty
        ? 0.0
        : result.pesticideResults.where((p) => p.exceedsLimit).length /
            result.pesticideResults.length;
    return [
      RadarEntry(value: result.confidence),
      RadarEntry(value: 1.0 - exceededRatio),
      RadarEntry(value: result.confidence * 0.9 + 0.1),
      RadarEntry(value: 0.85),
      RadarEntry(value: result.isQualified ? 0.95 : 0.4),
    ];
  }
}

/// Overall risk gauge widget
class RiskGaugeWidget extends StatelessWidget {
  final String riskLevel;
  final double confidence;

  const RiskGaugeWidget(
      {super.key, required this.riskLevel, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRiskColor().withValues(alpha: 0.1),
            _getRiskColor().withValues(alpha: 0.3)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getRiskColor(), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getRiskIcon(), size: 48, color: _getRiskColor()),
          const SizedBox(height: 8),
          Text(
            _getRiskText(),
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _getRiskColor()),
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor() {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon() {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning;
      case 'high':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  String _getRiskText() {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return 'Low Risk';
      case 'medium':
        return 'Medium Risk';
      case 'high':
        return 'High Risk';
      default:
        return riskLevel;
    }
  }
}
