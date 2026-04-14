import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/spectral_data.dart';
import '../utils/constants.dart';

/// 光谱图表组件
class SpectralChart extends StatelessWidget {
  final SpectralData? spectralData;
  final List<double>? wavelengths;
  final List<double>? intensities;
  final bool showGrid;
  final bool showLabels;
  final Color lineColor;
  final double lineWidth;
  final bool enableTouch;
  final double? height;

  const SpectralChart({
    super.key,
    this.spectralData,
    this.wavelengths,
    this.intensities,
    this.showGrid = true,
    this.showLabels = true,
    this.lineColor = AppConstants.primaryColor,
    this.lineWidth = 2,
    this.enableTouch = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final wl = wavelengths ?? spectralData?.wavelengths ?? [];
    final it = intensities ?? spectralData?.normalizedIntensities ?? [];

    if (wl.isEmpty || it.isEmpty || wl.length != it.length) {
      return SizedBox(
        height: height ?? 200,
        child: const Center(
          child: Text('暂无光谱数据'),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < wl.length; i++) {
      spots.add(FlSpot(wl[i], it[i]));
    }

    final minX = wl.reduce((a, b) => a < b ? a : b);
    final maxX = wl.reduce((a, b) => a > b ? a : b);
    final maxY = it.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height ?? 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: showGrid,
            drawVerticalLine: true,
            horizontalInterval: 0.2,
            verticalInterval: (maxX - minX) / 5,
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
            show: showLabels,
            bottomTitles: AxisTitles(
              axisNameWidget:
                  const Text('波长 (nm)', style: TextStyle(fontSize: 10)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxX - minX) / 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('强度', style: TextStyle(fontSize: 10)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: maxY / 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: lineColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: 0.3),
                    lineColor.withValues(alpha: 0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // 深度学习模型关注的农药特征峰标记 (示例)
            if (spectralData != null && spectralData!.maxIntensity > 0.8)
              LineChartBarData(
                spots: [spots[spots.length ~/ 2]], // 假设中间是特征峰
                show: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 6,
                    color: Colors.redAccent,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              ),
          ],
          lineTouchData: LineTouchData(
            enabled: enableTouch,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '波长: ${spot.x.toInt()} nm\n强度: ${spot.y.toStringAsFixed(4)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: maxY * 1.1,
        ),
        duration: AppConstants.animationDuration,
      ),
    );
  }
}

/// 实时光谱图组件（支持动画）
class LiveSpectralChart extends StatefulWidget {
  final Stream<SpectralData>? dataStream;
  final Color lineColor;
  final double height;

  const LiveSpectralChart({
    super.key,
    this.dataStream,
    this.lineColor = AppConstants.primaryColor,
    this.height = 200,
  });

  @override
  State<LiveSpectralChart> createState() => _LiveSpectralChartState();
}

class _LiveSpectralChartState extends State<LiveSpectralChart> {
  SpectralData? _currentData;

  @override
  void initState() {
    super.initState();
    widget.dataStream?.listen((data) {
      setState(() {
        _currentData = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppConstants.animationDurationFast,
      child: SpectralChart(
        key: ValueKey(_currentData?.id),
        spectralData: _currentData,
        lineColor: widget.lineColor,
        height: widget.height,
      ),
    );
  }
}

/// 迷你光谱图（用于列表预览）
class MiniSpectralChart extends StatelessWidget {
  final SpectralData spectralData;
  final double width;
  final double height;
  final Color color;

  const MiniSpectralChart({
    super.key,
    required this.spectralData,
    this.width = 80,
    this.height = 40,
    this.color = AppConstants.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final intensities = spectralData.normalizedIntensities;

    if (intensities.isEmpty) {
      return SizedBox(width: width, height: height);
    }

    // 降采样以提高性能
    final sampleRate = (intensities.length / 20).ceil();
    final sampledData = <double>[];
    for (var i = 0; i < intensities.length; i += sampleRate) {
      sampledData.add(intensities[i]);
    }

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MiniChartPainter(
          data: sampledData,
          color: color,
        ),
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final xStep = size.width / (data.length - 1);
    final maxY = data.reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - (data[i] / maxY) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 绘制填充区域
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color;
  }
}
