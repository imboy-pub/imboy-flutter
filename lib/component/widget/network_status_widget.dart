import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/websocket.dart';

class NetworkStatusWidget extends StatelessWidget {
  const NetworkStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final networkType = NetworkMonitorService.to.currentNetworkType.value;
      final isConnected = NetworkMonitorService.to.isConnected.value;
      final wsStatus = WebSocketService.to.status.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(networkType, isConnected, wsStatus).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(networkType, isConnected, wsStatus).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getNetworkIcon(networkType, isConnected),
              size: 14,
              color: _getStatusColor(networkType, isConnected, wsStatus),
            ),
            const SizedBox(width: 4),
            Text(
              _getStatusText(networkType, isConnected, wsStatus),
              style: TextStyle(
                fontSize: 11,
                color: _getStatusColor(networkType, isConnected, wsStatus),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    });
  }

  IconData _getNetworkIcon(NetworkType type, bool connected) {
    if (!connected) {
      return Icons.wifi_off;
    }

    switch (type) {
      case NetworkType.wifi:
        return Icons.wifi;
      case NetworkType.mobile:
        return Icons.signal_cellular_alt;
      case NetworkType.ethernet:
        return Icons.lan;
      case NetworkType.none:
        return Icons.wifi_off;
      case NetworkType.unknown:
        return Icons.help_outline;
    }
  }

  String _getStatusText(NetworkType type, bool connected, SocketStatus wsStatus) {
    if (!connected) {
      return '无网络';
    }

    final networkName = NetworkMonitorService.to.getNetworkTypeName(type);
    final wsConnected = wsStatus == SocketStatus.connected;

    return '$networkName ${wsConnected ? '✓' : '...'}';
  }

  Color _getStatusColor(NetworkType type, bool connected, SocketStatus wsStatus) {
    if (!connected) {
      return Colors.red;
    }

    final wsConnected = wsStatus == SocketStatus.connected;
    if (!wsConnected) {
      return Colors.orange;
    }

    switch (type) {
      case NetworkType.wifi:
        return Colors.green;
      case NetworkType.mobile:
        return Colors.blue;
      case NetworkType.ethernet:
        return Colors.purple;
      case NetworkType.none:
        return Colors.red;
      case NetworkType.unknown:
        return Colors.grey;
    }
  }
}