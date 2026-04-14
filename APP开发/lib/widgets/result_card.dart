import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// 检测结果卡片组件
class ResultCard extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showSpectralPreview;
  final bool compact;

  const ResultCard({
    super.key,
    required this.result,
    this.onTap,
    this.onLongPress,
    this.showSpectralPreview = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 8 : AppConstants.paddingMedium,
        vertical: compact ? 4 : AppConstants.paddingSmall,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : AppConstants.paddingMedium),
          child: compact ? _buildCompactContent() : _buildFullContent(),
        ),
      ),
    );
  }

  Widget _buildFullContent() {
    final executionLabel = _extractExecutionLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (executionLabel != null) ...[
          const SizedBox(height: 8),
          _buildExecutionBadge(executionLabel),
        ],
        const SizedBox(height: 12),
        _buildRiskIndicator(),
        if (result.hasPesticides) ...[
          const SizedBox(height: 12),
          _buildPesticideList(),
        ],
        const SizedBox(height: 8),
        _buildFooter(),
      ],
    );
  }

  Widget _buildCompactContent() {
    final executionLabel = _extractExecutionLabel();

    return Row(
      children: [
        _buildRiskBadge(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.sampleName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                Helpers.formatRelativeTime(result.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              if (executionLabel != null) ...[
                const SizedBox(height: 6),
                _buildExecutionBadge(executionLabel, compact: true),
              ],
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.sampleName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (result.sampleCategory != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.sampleCategory!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildConfidenceBadge(),
      ],
    );
  }

  Widget _buildRiskIndicator() {
    final color = Helpers.getRiskLevelColor(result.riskLevel);
    final icon = Helpers.getRiskLevelIcon(result.riskLevel);
    final description = Helpers.getRiskLevelDescription(result.riskLevel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.hasPesticides
                      ? '检出毒死蜱 ${result.detectedPesticides.length} 项'
                      : '未检出毒死蜱残留',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (result.hasOverLimitPesticides)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.errorColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${result.overLimitCount} over limit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge() {
    final color = Helpers.getRiskLevelColor(result.riskLevel);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Helpers.getRiskLevelIcon(result.riskLevel),
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified,
            size: 14,
            color: AppConstants.accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${(result.confidence * 100).toInt()}%',
            style: const TextStyle(
              color: AppConstants.accentColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPesticideList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '检出毒死蜱详情',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...result.detectedPesticides.take(3).map((p) => _buildPesticideItem(p)),
        if (result.detectedPesticides.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '还有 ${result.detectedPesticides.length - 3} 项...',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPesticideItem(DetectedPesticide pesticide) {
    final isOverLimit = pesticide.isOverLimit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOverLimit
                  ? AppConstants.errorColor
                  : AppConstants.successColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pesticide.name,
              style: TextStyle(
                fontSize: 13,
                color: isOverLimit ? AppConstants.errorColor : null,
              ),
            ),
          ),
          Text(
            Helpers.formatConcentration(pesticide.concentration),
            style: TextStyle(
              fontSize: 12,
              color: isOverLimit ? AppConstants.errorColor : Colors.grey,
              fontWeight: isOverLimit ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isOverLimit) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: AppConstants.errorColor,
            ),
          ],
        ],
      ),
    );
  }

  String? _extractExecutionLabel() {
    final notes = result.notes?.trim();
    if (notes == null || notes.isEmpty) {
      return null;
    }

    for (final line in notes.split('\n')) {
      if (line.startsWith('Execution mode:')) {
        return line.substring('Execution mode:'.length).trim();
      }
    }

    return notes.split('\n').first.trim();
  }

  Widget _buildExecutionBadge(String label, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          color: Colors.blueGrey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          Helpers.formatDateTime(result.timestamp),
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        if (result.isSynced)
          Row(
            children: [
              Icon(Icons.cloud_done, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '已同步',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 检测结果摘要卡片
class ResultSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const ResultSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppConstants.primaryColor;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: cardColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
