import 'package:flutter/material.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/websocket.dart';

class NetworkStatusWidget extends StatefulWidget {
  const NetworkStatusWidget({super.key});

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  NetworkType _networkType = NetworkType.unknown;
  bool _isConnected = false;
  SocketStatus _wsStatus = SocketStatus.disconnected;

  @override
  void initState() {
    super.initState();
    // 初始化状态
    _networkType = NetworkMonitorService.to.currentNetworkType;
    _isConnected = NetworkMonitorService.to.isConnected;
    _wsStatus = WebSocketService.to.status;

    // 添加网络变化监听器
    NetworkMonitorService.to.addNetworkChangeListener((oldType, newType) {
      if (mounted) {
        setState(() {
          _networkType = newType;
          _isConnected = newType != NetworkType.none;
        });
      }
    });

    // 添加 WebSocket 状态监听器
    WebSocketService.to.addStatusListener((status) {
      if (mounted) {
        setState(() {
          _wsStatus = status;
        });
      }
    });
  }

  @override
  void dispose() {
    // 移除监听器
    NetworkMonitorService.to.removeNetworkChangeListener((oldType, newType) {});
    WebSocketService.to.removeStatusListener((status) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(
          _networkType,
          _isConnected,
          _wsStatus,
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(
            _networkType,
            _isConnected,
            _wsStatus,
          ).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getNetworkIcon(_networkType, _isConnected),
            size: 14,
            color: _getStatusColor(_networkType, _isConnected, _wsStatus),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(_networkType, _isConnected, _wsStatus),
            style: TextStyle(
              fontSize: 11,
              color: _getStatusColor(_networkType, _isConnected, _wsStatus),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

  String _getStatusText(
    NetworkType type,
    bool connected,
    SocketStatus wsStatus,
  ) {
    if (!connected) {
      return '无网络';
    }

    final networkName = NetworkMonitorService.to.getNetworkTypeName(type);
    final wsConnected = wsStatus == SocketStatus.connected;

    return '$networkName ${wsConnected ? '✓' : '...'}';
  }

  Color _getStatusColor(
    NetworkType type,
    bool connected,
    SocketStatus wsStatus,
  ) {
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
