// WebSocketService 重初始化自愈回归测试
//
// 背景（2026-08-10 实证）：quitLogin → closeSocket(permanent:true) 销毁单例
// 后，重新登录只调 openSocket——新实例从未 init()，EventBus 发送订阅缺失，
// 上行消息/CLIENT_ACK 全部静默丢弃（客户端乐观日志显示"发送完成"，
// 服务端 pcap 字节级证实零上行字节），Android 双端 B 消息因此永远无 ACK。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/websocket.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebSocketService 重初始化自愈', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      WebSocketService.resetForTest();
    });

    tearDown(() {
      WebSocketService.resetForTest();
    });

    test('新实例 openSocket 后恢复 initialized（订阅重建）', () async {
      final svc = WebSocketService.to;
      expect(svc.isInitializedForTest, isFalse);

      // 未登录态：_preConnectionCheck 会提前返回，但 init 必须先于它执行
      await svc.openSocket(from: 'test');

      expect(svc.isInitializedForTest, isTrue);
    });

    test('permanent 关闭后单例重建，openSocket 仍自愈', () async {
      final svcA = WebSocketService.to;
      svcA.init();
      expect(svcA.isInitializedForTest, isTrue);

      await svcA.closeSocket(permanent: true);

      final svcB = WebSocketService.to;
      expect(identical(svcA, svcB), isFalse);
      expect(svcB.isInitializedForTest, isFalse);

      await svcB.openSocket(from: 'test');
      expect(svcB.isInitializedForTest, isTrue);
    });
  });
}
