import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/service/websocket.dart'
    show SocketStatus, WebSocketService;

part 'websocket_provider.g.dart';

/// WebSocket 状态提供者
///
/// 提供 WebSocket 连接状态的响应式访问
/// 自动监听 WebSocketService 的状态变化并更新
@riverpod
class WebSocketStatusNotifier extends _$WebSocketStatusNotifier {
  /// 状态变化监听器
  void Function(SocketStatus)? _statusListener;

  @override
  SocketStatus build() {
    // 初始化状态
    final initialStatus = WebSocketService.to.status;

    // 监听 WebSocket 状态变化
    _statusListener = (status) {
      // 检查 provider 是否仍然 mounted
      if (ref.mounted) {
        state = status;
      }
    };

    WebSocketService.to.addStatusListener(_statusListener!);

    // 当 provider 被销毁时移除监听器
    ref.onDispose(() {
      if (_statusListener != null) {
        WebSocketService.to.removeStatusListener(_statusListener!);
      }
    });

    return initialStatus;
  }
}
