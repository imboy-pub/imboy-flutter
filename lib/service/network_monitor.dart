import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

enum NetworkType { wifi, mobile, ethernet, none, unknown }

class NetworkMonitorService extends GetxService {
  static NetworkMonitorService get to => Get.find();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final Rx<NetworkType> currentNetworkType = NetworkType.unknown.obs;
  final RxBool isConnected = false.obs;

  // 网络类型改变回调
  final List<void Function(NetworkType oldType, NetworkType newType)> _networkChangeCallbacks = [];

  @override
  void onInit() {
    super.onInit();
    _initializeNetworkMonitoring();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  void _initializeNetworkMonitoring() {
    // 初始化网络状态
    _checkCurrentNetworkStatus();

    // 监听网络变化
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
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

    final oldType = currentNetworkType.value;
    final newType = _convertToNetworkType(results);
    final newConnected = newType != NetworkType.none;

    // 检查网络类型是否发生变化
    if (oldType != newType) {
      iPrint('网络类型变化: ${oldType.name} -> ${newType.name}');

      // 更新状态
      currentNetworkType.value = newType;
      isConnected.value = newConnected;

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
      
      // 检查WebSocket服务是否已注册
      if (!Get.isRegistered<WebSocketService>()) {
        iPrint('WebSocket服务未注册，跳过重连');
        return;
      }
      
      try {
        if (WebSocketService.to.status.value.name != 'connected') {
          WebSocketService.to.openSocket(from: 'network-type-change');
          iPrint('因网络类型变化触发WebSocket重连');
        }
      } catch (e) {
        iPrint('WebSocket重连失败: $e');
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

  void addNetworkChangeListener(void Function(NetworkType oldType, NetworkType newType) callback) {
    if (!_networkChangeCallbacks.contains(callback)) {
      _networkChangeCallbacks.add(callback);
    }
  }

  void removeNetworkChangeListener(void Function(NetworkType oldType, NetworkType newType) callback) {
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

  bool get isWifi => currentNetworkType.value == NetworkType.wifi;
  bool get isMobile => currentNetworkType.value == NetworkType.mobile;
  bool get isEthernet => currentNetworkType.value == NetworkType.ethernet;
  bool get hasNetwork => currentNetworkType.value != NetworkType.none;
}