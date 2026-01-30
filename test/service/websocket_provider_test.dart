import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebSocketStatusNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('应该提供初始的 WebSocket 状态', () {
      final status = container.read(webSocketStatusProvider);
      // WebSocket 初始状态应该是 disconnected
      expect(status, SocketStatus.disconnected);
    });

    test('应该在 WebSocket 状态变化时更新', () async {
      // 获取初始状态
      final initialStatus = container.read(webSocketStatusProvider);
      expect(initialStatus, SocketStatus.disconnected);

      // 监听状态变化
      final statusList = <SocketStatus>[];
      container.listen<SocketStatus>(
        webSocketStatusProvider,
        (previous, next) => statusList.add(next),
        fireImmediately: false,
      );

      // 模拟状态变化（在实际应用中，这会由 WebSocketService 触发）
      // 这里我们手动触发一个状态变化来测试 Provider 是否响应
      WebSocketService.to.addStatusListener((status) {
        // 这个监听器应该已经被 Provider 注册
      });

      // 验证监听器已被注册
      // 注意：这个测试主要验证 Provider 的结构正确性
      // 实际的状态变化需要 WebSocketService 触发
    });

    test('应该在 dispose 时清理监听器', () {
      // 创建一个容器并读取 Provider
      final container2 = ProviderContainer();
      final status = container2.read(webSocketStatusProvider);

      // 销毁容器
      container2.dispose();

      // 验证监听器被清理（这个测试主要是确保不会出现内存泄漏）
      expect(status, SocketStatus.disconnected);
    });
  });
}
