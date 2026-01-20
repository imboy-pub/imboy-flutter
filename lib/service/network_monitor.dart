import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

enum NetworkType { wifi, mobile, ethernet, none, unknown }

class NetworkMonitorService {
  // 单例模式
  static NetworkMonitorService? _instance;
  static NetworkMonitorService get to =>
      _instance ??= NetworkMonitorService._internal();
  NetworkMonitorService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // 状态管理
  NetworkType _currentNetworkType = NetworkType.unknown;
  NetworkType get currentNetworkType => _currentNetworkType;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 网络类型改变回调
  final List<void Function(NetworkType oldType, NetworkType newType)>
  _networkChangeCallbacks = [];

  /// 初始化服务
  void init() {
    _initializeNetworkMonitoring();
  }

  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  void _initializeNetworkMonitoring() {
    // 初始化网络状态
    _checkCurrentNetworkStatus();

    // 监听网络变化
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _handleConnectivityChange(results);
    });
  }

  Future<void> _checkCurrentNetworkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      iPrint('网络状态检查失败: $e');
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty) return;

    final oldType = _currentNetworkType;
    final newType = _convertToNetworkType(results);
    final newConnected = newType != NetworkType.none;

    // 检查网络类型是否发生变化
    if (oldType != newType) {
      iPrint('网络类型变化: ${oldType.name} -> ${newType.name}');

      // 更新状态
      _currentNetworkType = newType;
      _isConnected = newConnected;

      // 通知所有监听器
      _notifyNetworkTypeChange(oldType, newType);

      // 如果是从无网络到有网络，或者网络类型变化，触发重连
      if (oldType == NetworkType.none || newType != NetworkType.none) {
        _triggerReconnection(oldType, newType);
      }
    }
  }

  NetworkType _convertToNetworkType(List<ConnectivityResult> results) {
    if (results.any((result) => result == ConnectivityResult.wifi)) {
      return NetworkType.wifi;
    } else if (results.any((result) => result == ConnectivityResult.mobile)) {
      return NetworkType.mobile;
    } else if (results.any((result) => result == ConnectivityResult.ethernet)) {
      return NetworkType.ethernet;
    } else if (results.any((result) => result == ConnectivityResult.none)) {
      return NetworkType.none;
    } else {
      return NetworkType.unknown;
    }
  }

  void _triggerReconnection(NetworkType oldType, NetworkType newType) {
    iPrint('检测到网络变化，准备重连WebSocket: $oldType -> $newType');

    // 延迟一小段时间确保网络稳定
    Future.delayed(const Duration(milliseconds: 500), () {
      // 检查用户是否已登录
      if (!UserRepoLocal.to.isLoggedIn) {
        iPrint('用户未登录，取消WebSocket重连');
        return;
      }

      // 【解耦】通过事件总线发布 WebSocket 重连请求，而不是直接调用 WebSocketService
      // Decoupling: publish WebSocket reconnect request via event bus instead of directly calling WebSocketService
      try {
        AppEventBus.fire(
          WebSocketReconnectRequestEvent(source: 'network-type-change'),
        );
        iPrint('因网络类型变化触发WebSocket重连请求');
      } catch (e) {
        iPrint('发布WebSocket重连请求失败: $e');
      }
    });
  }

  void _notifyNetworkTypeChange(NetworkType oldType, NetworkType newType) {
    for (final callback in _networkChangeCallbacks) {
      try {
        callback(oldType, newType);
      } catch (e) {
        iPrint('网络变化回调执行失败: $e');
      }
    }
  }

  void addNetworkChangeListener(
    void Function(NetworkType oldType, NetworkType newType) callback,
  ) {
    if (!_networkChangeCallbacks.contains(callback)) {
      _networkChangeCallbacks.add(callback);
    }
  }

  void removeNetworkChangeListener(
    void Function(NetworkType oldType, NetworkType newType) callback,
  ) {
    _networkChangeCallbacks.remove(callback);
  }

  String getNetworkTypeName(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'Wi-Fi';
      case NetworkType.mobile:
        return '4G/5G';
      case NetworkType.ethernet:
        return '以太网';
      case NetworkType.none:
        return '无网络';
      case NetworkType.unknown:
        return '未知';
    }
  }

  bool get isWifi => _currentNetworkType == NetworkType.wifi;
  bool get isMobile => _currentNetworkType == NetworkType.mobile;
  bool get isEthernet => _currentNetworkType == NetworkType.ethernet;
  bool get hasNetwork => _currentNetworkType != NetworkType.none;
}
