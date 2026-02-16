import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/websocket_status_provider.dart';

class NetworkStatusWidget extends ConsumerStatefulWidget {
  const NetworkStatusWidget({super.key});

  @override
  ConsumerState<NetworkStatusWidget> createState() =>
      _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends ConsumerState<NetworkStatusWidget> {
  NetworkType _networkType = NetworkType.unknown;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    // 初始化状态
    _networkType = NetworkMonitorService.to.currentNetworkType;
    _isConnected = NetworkMonitorService.to.isConnected;

    // 添加网络变化监听器
    NetworkMonitorService.to.addNetworkChangeListener((oldType, newType) {
      if (mounted) {
        setState(() {
          _networkType = newType;
          _isConnected = newType != NetworkType.none;
        });
      }
    });
  }

  @override
  void dispose() {
    // 移除监听器
    NetworkMonitorService.to.removeNetworkChangeListener((oldType, newType) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 Provider 监听 WebSocket 状态（响应式）
    final wsStatusAsync = ref.watch(webSocketStatusProvider);

    // 处理 AsyncValue，提供默认值
    final wsStatus = wsStatusAsync.value ?? WebSocketConnectionState.disconnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(
          _networkType,
          _isConnected,
          wsStatus,
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(
            _networkType,
            _isConnected,
            wsStatus,
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
            color: _getStatusColor(_networkType, _isConnected, wsStatus),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(_networkType, _isConnected, wsStatus),
            style: TextStyle(
              fontSize: 11,
              color: _getStatusColor(_networkType, _isConnected, wsStatus),
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
    WebSocketConnectionState wsStatus,
  ) {
    if (!connected) {
      return '无网络';
    }

    final networkName = NetworkMonitorService.to.getNetworkTypeName(type);
    final wsConnected = wsStatus == WebSocketConnectionState.connected;

    return '$networkName ${wsConnected ? '✓' : '...'}';
  }

  Color _getStatusColor(
    NetworkType type,
    bool connected,
    WebSocketConnectionState wsStatus,
  ) {
    if (!connected) {
      return Colors.red;
    }

    final wsConnected = wsStatus == WebSocketConnectionState.connected;
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
