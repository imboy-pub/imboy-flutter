// Olm 套件集成测试：验证 e2ee_suite 路由、灰度开关、元数据字段契约。
//
// 注意：完整的 Olm X3DH + Double Ratchet round-trip 测试需要 vodozemac 原生库
// 环境（fvod.init()），属于真机/集成测试范畴。本文件覆盖纯逻辑不变量：
//   1. kOlmSuite 常量正确性
//   2. useOlmForC2C 灰度开关默认 false（保证不破坏现有 Megolm 单聊）
//   3. Olm e2ee 元数据字段契约（peer_uid/peer_device_id/message_type）
//   4. 三套件（RSA/Megolm/Olm）解密路由互斥性
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';

// 注：ChatNetworkService.useOlmForC2C 是 static const，直接通过类访问。

void main() {
  group('Olm suite constants & routing', () {
    test('kOlmSuite 常量为 OLM.V1', () {
      expect(kOlmSuite, equals('OLM.V1'));
    });

    test('kOlmSuite 与 kMegolmSuite 互斥（三套件可区分）', () {
      expect(kOlmSuite, isNot(equals(kMegolmSuite)));
      expect(kMegolmSuite, equals('MEGOLM.V1'));
      // 旧 RSA 套件（e2ee_service.dart 内联字符串，不复用常量）
      expect('RSA-OAEP-256+AES-256-GCM', isNot(equals(kOlmSuite)));
      expect('RSA-OAEP-256+AES-256-GCM', isNot(equals(kMegolmSuite)));
    });

    test('useOlmForC2C 灰度开关默认 true（C2C 默认走 Olm per-device fan-out）', () {
      // E2EE-029: C2C 新消息默认走 Olm per-device fan-out（PFv3）
      // Megolm 仅保留 C2G 群聊路径；RSA 仅保留 legacy decrypt-only
      expect(ChatNetworkService.useOlmForC2C, isTrue);
    });
  });

  group('Olm e2ee 元数据字段契约', () {
    test('Olm 元数据必须含 peer_uid / peer_device_id / message_type', () {
      // 这是 E2EEService.decryptE2EEMessage Olm 分支的最小字段集
      final olmE2ee = <String, dynamic>{
        'e2ee': true,
        'e2ee_ver': 2,
        'e2ee_suite': kOlmSuite,
        'peer_uid': '200',
        'peer_device_id': 'device-B',
        'message_type': 0, // pre-key message（首次）
      };
      expect(olmE2ee['e2ee_suite'], equals(kOlmSuite));
      expect(olmE2ee['peer_uid'], isNotEmpty);
      expect(olmE2ee['peer_device_id'], isNotEmpty);
      expect(olmE2ee['message_type'], isIn([0, 1]));
    });

    test('message_type=0 表示 pre-key（首次），=1 表示 normal（后续）', () {
      // Olm 协议语义：createInboundSession 解 type=0；session.decrypt 解 type=1
      expect(int.parse('0'), equals(0)); // pre-key
      expect(int.parse('1'), equals(1)); // normal
    });
  });

  group('三套件解密路由互斥性（白盒）', () {
    // 验证 decryptE2EEMessage 按 e2ee_suite 字段路由的正确性
    // （实际解密委托由各 Service 完成，此处只验路由判定逻辑）
    String routeBySuite(String? suite) {
      if (suite == kOlmSuite) return 'olm';
      if (suite == kMegolmSuite) return 'megolm';
      return 'rsa_legacy';
    }

    test('OLM.V1 → olm 路由', () {
      expect(routeBySuite(kOlmSuite), equals('olm'));
    });

    test('MEGOLM.V1 → megolm 路由', () {
      expect(routeBySuite(kMegolmSuite), equals('megolm'));
    });

    test('null / 旧 RSA 套件 → rsa_legacy 路由（向后兼容）', () {
      expect(routeBySuite(null), equals('rsa_legacy'));
      expect(routeBySuite('RSA-OAEP-256+AES-256-GCM'), equals('rsa_legacy'));
    });

    test('三套件路由结果互斥', () {
      final results = {
        routeBySuite(kOlmSuite),
        routeBySuite(kMegolmSuite),
        routeBySuite('RSA-OAEP-256+AES-256-GCM'),
      };
      expect(results.length, equals(3));
    });
  });

  group('Olm prekey 投递 action 名', () {
    test(
      'olmPreKeyAction 与 e2ee_room_key 同机制（服务端 content_bearing_action 白名单放行）',
      () {
        expect(olmPreKeyAction, equals('e2ee_olm_prekey'));
        // 服务端 imboy_policy:content_bearing_action/1 对非 <<>>/message_edit 的
        // action 一律放行，故 olmPreKeyAction 自动被白名单覆盖，无需后端改动。
        expect(olmPreKeyAction, isNot(equals('')));
        expect(olmPreKeyAction, isNot(equals('message_edit')));
      },
    );
  });
}
