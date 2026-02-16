/// Web 平台 PWA 服务
///
/// 提供渐进式 Web 应用功能：
/// - 安装提示
/// - 离线状态检测
/// - 缓存管理
/// - 更新通知
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pwa_service.g.dart';

/// PWA 安装状态
enum PWAInstallState {
  /// 可安装
  installable,

  /// 已安装
  installed,

  /// 不支持
  unsupported,
}

/// PWA 服务状态
class PWAState {
  final PWAInstallState installState;
  final bool isOffline;
  final bool hasUpdate;
  final String? version;

  const PWAState({
    this.installState = PWAInstallState.unsupported,
    this.isOffline = false,
    this.hasUpdate = false,
    this.version,
  });

  PWAState copyWith({
    PWAInstallState? installState,
    bool? isOffline,
    bool? hasUpdate,
    String? version,
  }) {
    return PWAState(
      installState: installState ?? this.installState,
      isOffline: isOffline ?? this.isOffline,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      version: version ?? this.version,
    );
  }
}

/// PWA 服务
///
/// 管理 PWA 相关功能
class PWAService extends ChangeNotifier {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();

  PWAState _state = const PWAState();
  PWAState get state => _state;

  /// 安装提示事件（由 Web 端触发）
  void Function()? _installPrompt;

  /// 是否可以安装
  bool get canInstall => _state.installState == PWAInstallState.installable;

  /// 是否已安装
  bool get isInstalled => _state.installState == PWAInstallState.installed;

  /// 是否离线
  bool get isOffline => _state.isOffline;

  /// 是否有更新
  bool get hasUpdate => _state.hasUpdate;

  /// 初始化 PWA 服务
  void initialize() {
    if (!kIsWeb) return;

    _checkInstallState();
    _setupOfflineListener();
    _setupUpdateListener();

    debugPrint('PWAService: 初始化完成');
  }

  /// 检查安装状态
  void _checkInstallState() {
    // 检查是否已安装（standalone 模式）
    final isStandalone = _checkStandaloneMode();

    if (isStandalone) {
      _state = _state.copyWith(installState: PWAInstallState.installed);
    } else {
      // 监听 beforeinstallprompt 事件
      _setupInstallPromptListener();
    }

    notifyListeners();
  }

  /// 检查是否为独立模式（已安装）
  bool _checkStandaloneMode() {
    if (!kIsWeb) return false;

    // 在实际 Web 实现中，检查 display-mode
    // window.matchMedia('(display-mode: standalone)').matches
    return false; // 占位返回
  }

  /// 设置安装提示监听器
  void _setupInstallPromptListener() {
    // 在实际实现中，监听 beforeinstallprompt 事件
    // 并保存事件以便后续触发安装
  }

  /// 设置离线状态监听器
  void _setupOfflineListener() {
    if (!kIsWeb) return;

    // 监听 online/offline 事件
    // 实际实现需要使用 web 包
  }

  /// 设置更新监听器
  void _setupUpdateListener() {
    if (!kIsWeb) return;

    // 监听 Service Worker 更新
    // 实际实现需要使用 web 包
  }

  /// 触发安装提示
  Future<bool> promptInstall() async {
    if (!canInstall) return false;

    try {
      // 调用保存的 beforeinstallprompt 事件
      if (_installPrompt != null) {
        _installPrompt!();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('PWAService: 安装提示失败 - $e');
      return false;
    }
  }

  /// 应用更新
  Future<void> applyUpdate() async {
    if (!hasUpdate) return;

    try {
      // 通知 Service Worker 跳过等待并激活
      // 实际实现需要使用 web 包
      debugPrint('PWAService: 应用更新');

      // 刷新页面
      // window.location.reload();
    } catch (e) {
      debugPrint('PWAService: 应用更新失败 - $e');
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    if (!kIsWeb) return;

    try {
      // 清除 Service Worker 缓存
      // 实际实现需要使用 web 包
      debugPrint('PWAService: 清除缓存');
    } catch (e) {
      debugPrint('PWAService: 清除缓存失败 - $e');
    }
  }

  /// 获取缓存大小
  Future<String> getCacheSize() async {
    if (!kIsWeb) return '0 B';

    try {
      // 获取缓存存储使用量
      // 实际实现需要使用 web 包
      return '计算中...';
    } catch (e) {
      debugPrint('PWAService: 获取缓存大小失败 - $e');
      return '0 B';
    }
  }

  /// 更新离线状态
  void updateOfflineStatus(bool isOffline) {
    if (_state.isOffline != isOffline) {
      _state = _state.copyWith(isOffline: isOffline);
      notifyListeners();
    }
  }

  /// 更新安装状态
  void updateInstallState(PWAInstallState installState) {
    if (_state.installState != installState) {
      _state = _state.copyWith(installState: installState);
      notifyListeners();
    }
  }

  /// 设置有更新
  void setHasUpdate(bool hasUpdate) {
    if (_state.hasUpdate != hasUpdate) {
      _state = _state.copyWith(hasUpdate: hasUpdate);
      notifyListeners();
    }
  }

  /// 设置安装提示回调
  void setInstallPrompt(void Function()? prompt) {
    _installPrompt = prompt;
    if (prompt != null) {
      _state = _state.copyWith(installState: PWAInstallState.installable);
      notifyListeners();
    }
  }
}

/// PWA 服务 Provider
///
/// 使用 Riverpod 的 @riverpod 注解模式
@riverpod
class PWANotifier extends _$PWANotifier {
  @override
  PWAState build() {
    _initialize();
    return const PWAState();
  }

  void _initialize() {
    if (!kIsWeb) return;
    _checkInstallState();
    _setupOfflineListener();
    _setupUpdateListener();
    debugPrint('PWANotifier: 初始化完成');
  }

  void _checkInstallState() {
    final isStandalone = _checkStandaloneMode();
    if (isStandalone) {
      state = state.copyWith(installState: PWAInstallState.installed);
    } else {
      _setupInstallPromptListener();
    }
  }

  bool _checkStandaloneMode() {
    if (!kIsWeb) return false;
    return false;
  }

  void _setupInstallPromptListener() {}
  void _setupOfflineListener() {}
  void _setupUpdateListener() {}

  Future<bool> promptInstall() async {
    if (state.installState != PWAInstallState.installable) return false;
    return false;
  }

  Future<void> applyUpdate() async {
    if (!state.hasUpdate) return;
    debugPrint('PWANotifier: 应用更新');
  }

  Future<void> clearCache() async {
    if (!kIsWeb) return;
    debugPrint('PWANotifier: 清除缓存');
  }

  void updateOfflineStatus(bool isOffline) {
    state = state.copyWith(isOffline: isOffline);
  }

  void updateInstallState(PWAInstallState installState) {
    state = state.copyWith(installState: installState);
  }

  void setHasUpdate(bool hasUpdate) {
    state = state.copyWith(hasUpdate: hasUpdate);
  }

  bool get canInstall => state.installState == PWAInstallState.installable;
  bool get isInstalled => state.installState == PWAInstallState.installed;
  bool get isOffline => state.isOffline;
  bool get hasUpdate => state.hasUpdate;
}

/// 全局实例
final pwaService = PWAService();

/// PWA 安装按钮组件
class PWAInstallButton extends ConsumerWidget {
  final Widget Function(BuildContext context, VoidCallback? onInstall)? builder;
  final String? installText;
  final VoidCallback? onInstalled;

  const PWAInstallButton({
    super.key,
    this.builder,
    this.installText,
    this.onInstalled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pwaState = ref.watch(pwaNotifierProvider);
    final pwaNotifier = ref.read(pwaNotifierProvider.notifier);

    if (!kIsWeb || pwaState.installState != PWAInstallState.installable) {
      return const SizedBox.shrink();
    }

    if (builder != null) {
      return builder!(
        context,
        pwaNotifier.canInstall ? () => _handleInstall(pwaNotifier) : null,
      );
    }

    return ElevatedButton.icon(
      onPressed: pwaNotifier.canInstall ? () => _handleInstall(pwaNotifier) : null,
      icon: const Icon(Icons.install_mobile),
      label: Text(installText ?? '安装应用'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _handleInstall(PWANotifier pwa) async {
    final success = await pwa.promptInstall();
    if (success && onInstalled != null) {
      onInstalled!();
    }
  }
}

/// PWA 更新提示组件
class PWAUpdateBanner extends ConsumerWidget {
  final String? updateText;
  final String? updateButtonText;
  final VoidCallback? onUpdate;

  const PWAUpdateBanner({
    super.key,
    this.updateText,
    this.updateButtonText,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pwaState = ref.watch(pwaNotifierProvider);
    final pwaNotifier = ref.read(pwaNotifierProvider.notifier);

    if (!kIsWeb || !pwaState.hasUpdate) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xFF00A884),
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  updateText ?? '有新版本可用',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (onUpdate != null) {
                    onUpdate!();
                  } else {
                    pwaNotifier.applyUpdate();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: Text(updateButtonText ?? '更新'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PWA 离线提示组件
class PWAOfflineBanner extends ConsumerWidget {
  final String? offlineText;

  const PWAOfflineBanner({
    super.key,
    this.offlineText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pwaState = ref.watch(pwaNotifierProvider);

    if (!kIsWeb || !pwaState.isOffline) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                offlineText ?? '当前处于离线状态',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
