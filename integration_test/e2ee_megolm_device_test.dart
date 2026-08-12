/// S14：真机 Megolm 群级密码学验收。
///
/// 只验证设备上的原生 vodozemac GroupSession，不登录、不访问后端、
/// 不创建群、不写入业务消息；业务群聊闭环仍需双账号真机测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:integration_test/integration_test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(fvod.init);

  test('Megolm GroupSession 导出/导入、双消息解密和轮换隔离', () {
    final outbound = vod.GroupSession();
    final sessionId = outbound.sessionId;
    final exported = outbound.toInbound().exportAt(0);

    expect(exported, isNotNull);
    expect(exported, isNotEmpty);

    final inbound = vod.InboundGroupSession.import(exported!);
    expect(inbound.sessionId, sessionId);

    final first = outbound.encrypt('group-device-message-1');
    final second = outbound.encrypt('group-device-message-2');
    expect(inbound.decrypt(first).plaintext, 'group-device-message-1');
    expect(inbound.decrypt(second).plaintext, 'group-device-message-2');

    final rotated = vod.GroupSession();
    expect(rotated.sessionId, isNot(sessionId));
    final rotatedCiphertext = rotated.encrypt('after-rotation');
    expect(() => inbound.decrypt(rotatedCiphertext), throwsA(anything));
  });
}
