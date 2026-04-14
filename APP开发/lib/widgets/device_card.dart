import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../utils/constants.dart';

/// 设备卡片组件
class DeviceCard extends StatelessWidget {
  final String name;
  final String? macAddress;
  final int? rssi;
  final DeviceConnectionState connectionState;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  const DeviceCard({
    super.key,
    required this.name,
    this.macAddress,
    this.rssi,
    this.connectionState = DeviceConnectionState.disconnected,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(child: _buildInfo()),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    Color iconColor;
    IconData iconData;

    switch (connectionState) {
      case DeviceConnectionState.connected:
        iconColor = AppConstants.successColor;
        iconData = Icons.bluetooth_connected;
        break;
      case DeviceConnectionState.connecting:
        iconColor = AppConstants.warningColor;
        iconData = Icons.bluetooth_searching;
        break;
      case DeviceConnectionState.error:
        iconColor = AppConstants.errorColor;
        iconData = Icons.bluetooth_disabled;
        break;
      default:
        iconColor = Colors.grey;
        iconData = Icons.bluetooth;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isNotEmpty ? name : '未知设备',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        if (macAddress != null)
          Text(
            macAddress!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStatusChip(),
            if (rssi != null) ...[
              const SizedBox(width: 8),
              _buildSignalStrength(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    String text;
    Color color;

    switch (connectionState) {
      case DeviceConnectionState.connected:
        text = '已连接';
        color = AppConstants.successColor;
        break;
      case DeviceConnectionState.connecting:
        text = '连接中...';
        color = AppConstants.warningColor;
        break;
      case DeviceConnectionState.error:
        text = '连接失败';
        color = AppConstants.errorColor;
        break;
      default:
        text = '未连接';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSignalStrength() {
    final strength = rssi ?? -100;
    Color color;
    int bars;

    if (strength > -60) {
      color = AppConstants.successColor;
      bars = 4;
    } else if (strength > -70) {
      color = AppConstants.primaryColor;
      bars = 3;
    } else if (strength > -80) {
      color = AppConstants.warningColor;
      bars = 2;
    } else {
      color = AppConstants.errorColor;
      bars = 1;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          '$rssi dBm',
          style: TextStyle(
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onFavoriteToggle != null)
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: onFavoriteToggle,
          ),
        if (connectionState == DeviceConnectionState.connecting)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }
}

/// 设备连接状态指示器
class ConnectionStatusIndicator extends StatelessWidget {
  final DeviceConnectionState state;
  final String? deviceName;
  final VoidCallback? onTap;

  const ConnectionStatusIndicator({
    super.key,
    required this.state,
    this.deviceName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getBackgroundColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getBackgroundColor().withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIndicator(),
            const SizedBox(width: 8),
            Text(
              _getStatusText(),
              style: TextStyle(
                color: _getBackgroundColor(),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    if (state == DeviceConnectionState.connecting) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_getBackgroundColor()),
        ),
      );
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (state) {
      case DeviceConnectionState.connected:
        return AppConstants.successColor;
      case DeviceConnectionState.connecting:
        return AppConstants.warningColor;
      case DeviceConnectionState.error:
        return AppConstants.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (state) {
      case DeviceConnectionState.connected:
        return deviceName != null ? '已连接: $deviceName' : '已连接';
      case DeviceConnectionState.connecting:
        return '连接中...';
      case DeviceConnectionState.error:
        return '连接失败';
      default:
        return '未连接设备';
    }
  }
}
