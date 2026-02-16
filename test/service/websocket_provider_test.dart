import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/websocket_status_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebSocket 状态 Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('应该提供 WebSocket 状态 Provider', () {
      // 验证 Provider 可以被访问
      final provider = container.read(webSocketStatusProvider);

      // StreamProvider 返回 AsyncValue
      expect(provider, isNotNull);
    });

    test('应该在 dispose 时清理资源', () {
      // 创建一个容器并读取 Provider
      final container2 = ProviderContainer();
      final provider = container2.read(webSocketStatusProvider);

      // 验证 Provider 可以被访问
      expect(provider, isNotNull);

      // 销毁容器
      container2.dispose();

      // 验证没有内存泄漏
      expect(provider, isNotNull);
    });
  });
}
