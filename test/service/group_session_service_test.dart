import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/compliance_key_service.dart'
    show ComplianceKeyInfo;
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

/// 生成本设备真实 E2EE 密钥对（生产同款入口，范式同 e2ee_service_test.dart）
Future<Map<String, dynamic>> _setupDeviceKey() async {
  final keyInfo = await E2EEKeyService.generateKeyPair();
  final publicKey = await StorageSecureService.to.getPublicKey();
  return {...keyInfo, 'public_key': publicKey};
}

/// spike 已构建的 vodozemac 宿主动态库（存在才跑 Megolm 全链路用例）
const String _spikeLibDir = '../spikes/e2ee-group/rust/target/release/';

/// vod.init 全进程只能调一次（RustLib 重复初始化会抛错）
bool _vodInited = false;
Future<void> _ensureVod() async {
  if (_vodInited) return;
  await vod.init(libraryPath: _spikeLibDir);
  GroupSessionService.debugMarkVodReady();
  _vodInited = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final store = <String, String?>{};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              store[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return store[call.arguments['key'] as String];
            case 'delete':
              store.remove(call.arguments['key'] as String);
              return null;
            case 'deleteAll':
              store.clear();
              return null;
            case 'readAll':
              return Map<String, String?>.from(store);
            case 'containsKey':
              return store.containsKey(call.arguments['key'] as String);
          }
          return null;
        });
  });

  group('room key 包裹/解包（纯 Dart，不依赖原生库）', () {
    test(
      'buildRoomKeyPayload → pickMyKeyEntry → unwrapSessionKey 逐字节往返',
      () async {
        final keyInfo = await _setupDeviceKey();
        final did = keyInfo['device_id'] as String;
        final kid = keyInfo['key_id'] as String;
        final pem = keyInfo['public_key'] as String;

        // 模拟导出的 Megolm session key：~165 字节随机、unpadded base64
        final rnd = Random.secure();
        final keyBytes = List<int>.generate(165, (_) => rnd.nextInt(256));
        final exported = base64.encode(keyBytes).replaceAll('=', '');

        final payload = GroupSessionService.buildRoomKeyPayload(
          gid: 'g100',
          sessionId: 'sess_abc',
          exportedKey: exported,
          didToPem: {did: pem, 'other_did': pem},
          didToKid: {did: kid},
        );

        expect(payload['msg_type'], 'e2ee_room_key');
        expect(payload['gid'], 'g100');
        expect(payload['session_id'], 'sess_abc');
        expect((payload['keys'] as List).length, 2);

        final entry = GroupSessionService.pickMyKeyEntry(
          payload['keys'] as List,
          did,
        );
        expect(entry, isNotNull);
        expect(entry!['kid'], kid);
        expect(entry['wrap_alg'], 'RSA-OAEP-256');

        final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(
          kid,
        );
        expect(privateKeyPem, isNotNull);

        final restored = GroupSessionService.unwrapSessionKey(
          ek: entry['ek'] as String,
          privateKeyPem: privateKeyPem!,
        );
        expect(restored, exported, reason: '解包后必须与导出 key 逐字节一致（unpadded）');
      },
    );

    test('pickMyKeyEntry 对不在分发列表的设备返回 null', () {
      final entry = GroupSessionService.pickMyKeyEntry([
        {'did': 'a', 'ek': 'x'},
        {'did': 'b', 'ek': 'y'},
      ], 'not_exist');
      expect(entry, isNull);
    });
  });

  group('Megolm 全链路（需要 spike 动态库，缺失自动 skip）', () {
    final hasLib = Directory(_spikeLibDir).existsSync();

    test('建群会话 → 导出 → RSA 包裹分发 → 解包 → import → 加解密往返', () async {
      if (!hasLib) {
        markTestSkipped('spike 动态库缺失：$_spikeLibDir（cargo build --release 后可跑）');
        return;
      }
      await _ensureVod();

      final keyInfo = await _setupDeviceKey();
      final did = keyInfo['device_id'] as String;
      final kid = keyInfo['key_id'] as String;
      final pem = keyInfo['public_key'] as String;

      // 发送端：建 outbound，encrypt 之前导出（棘轮语义）
      final outbound = vod.GroupSession();
      final sessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0);
      expect(exported, isNotNull);

      final payload = GroupSessionService.buildRoomKeyPayload(
        gid: 'g200',
        sessionId: sessionId,
        exportedKey: exported!,
        didToPem: {did: pem},
        didToKid: {did: kid},
      );

      // 接收端：解包 → import → 解密
      final entry = GroupSessionService.pickMyKeyEntry(
        payload['keys'] as List,
        did,
      )!;
      final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(
        kid,
      );
      final restored = GroupSessionService.unwrapSessionKey(
        ek: entry['ek'] as String,
        privateKeyPem: privateKeyPem!,
      );

      final inbound = vod.InboundGroupSession.import(restored);
      expect(inbound.sessionId, sessionId);

      final ct1 = outbound.encrypt('群消息一');
      final ct2 = outbound.encrypt('群消息二');
      expect(inbound.decrypt(ct1).plaintext, '群消息一');
      expect(inbound.decrypt(ct2).plaintext, '群消息二');

      // rotate 语义：新建 session 后旧 inbound 解不开新密文
      final rotated = vod.GroupSession();
      expect(rotated.sessionId, isNot(sessionId));
      final ct3 = rotated.encrypt('rotate 后的消息');
      expect(() => inbound.decrypt(ct3), throwsA(anything));
    });

    // H1 回归守护：收到 e2ee_room_key 只存 inbound 供解密，绝不翻转群策略旗标。
    // （e2ee_room_key 是任意成员可发的具名 action，据此翻旗标 = 越权 + 不可逆 DoS）
    test('handleRoomKeyMessage 存 inbound 可解密，但不翻转 e2ee 旗标', () async {
      if (!hasLib) {
        markTestSkipped('spike 动态库缺失：$_spikeLibDir');
        return;
      }
      await _ensureVod();

      final keyInfo = await _setupDeviceKey();
      final did = keyInfo['device_id'] as String;
      final kid = keyInfo['key_id'] as String;
      final pem = keyInfo['public_key'] as String;
      deviceId = did; // handleRoomKeyMessage 按全局 deviceId 找本设备条目

      const gid = 'g_h1_regression';
      final outbound = vod.GroupSession();
      final sessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0)!;
      final payload = GroupSessionService.buildRoomKeyPayload(
        gid: gid,
        sessionId: sessionId,
        exportedKey: exported,
        didToPem: {did: pem},
        didToKid: {did: kid},
      );

      // 旗标处理前为 false
      expect(await GroupSessionService.to.isGroupE2EE(gid), isFalse);

      await GroupSessionService.to.handleRoomKeyMessage({
        'from': 'attacker_uid',
        'to': gid,
        'type': 'C2G',
        'payload': payload,
      });

      // 断言①：旗标未被非法翻转（H1）
      expect(
        await GroupSessionService.to.isGroupE2EE(gid),
        isFalse,
        reason: '收 room key 不得据此开启群 E2EE 强制加密（越权 + 不可逆）',
      );
      // 断言②：inbound 已正确存储，收到的群密文能解开
      final ct = outbound.encrypt('攻击者也能合法分发 key，但只能解密不能改策略');
      final plain = await GroupSessionService.to.decryptGroupMessage(
        gid: gid,
        sessionId: sessionId,
        ciphertext: ct,
      );
      expect(plain, '攻击者也能合法分发 key，但只能解密不能改策略');
    });
  });

  group('C2C 单聊 Megolm（发送路径全量新方案）', () {
    test(
      'buildRoomKeyPayload 无 gid → C2C 形态（scope=c2c）+ extraKeys 追加',
      () async {
        final keyInfo = await _setupDeviceKey();
        final did = keyInfo['device_id'] as String;
        final kid = keyInfo['key_id'] as String;
        final pem = keyInfo['public_key'] as String;

        final rnd = Random.secure();
        final exported = base64
            .encode(List<int>.generate(165, (_) => rnd.nextInt(256)))
            .replaceAll('=', '');

        final compliance = GroupSessionService.complianceEntryFor(
          exportedKey: exported,
          key: ComplianceKeyInfo(
            keyId: 'ck_v1',
            publicKey: pem, // 用设备公钥充当合规公钥，便于用配对私钥验证往返
            fetchedAt: DateTime.now(),
          ),
        );
        final payload = GroupSessionService.buildRoomKeyPayload(
          sessionId: 'sess_c2c',
          exportedKey: exported,
          didToPem: {did: pem},
          didToKid: {did: kid},
          extraKeys: [compliance],
        );

        expect(payload.containsKey('gid'), isFalse);
        expect(payload['scope'], 'c2c');
        expect((payload['keys'] as List).length, 2);

        // 合规条目可用合规私钥解包出同一 session key（审计侧可导入解密）
        final auditEntry = GroupSessionService.pickMyKeyEntry(
          payload['keys'] as List,
          'compliance-audit',
        );
        expect(auditEntry, isNotNull);
        expect(auditEntry!['kid'], 'ck_v1');
        final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(
          kid,
        );
        final restored = GroupSessionService.unwrapSessionKey(
          ek: auditEntry['ek'] as String,
          privateKeyPem: privateKeyPem!,
        );
        expect(restored, exported);
      },
    );

    test(
      'C2C room key → handleRoomKeyMessage → decryptC2CMessage 全链路往返',
      () async {
        final hasLib = Directory(_spikeLibDir).existsSync();
        if (!hasLib) {
          markTestSkipped('spike 动态库缺失：$_spikeLibDir');
          return;
        }
        await _ensureVod();

        final keyInfo = await _setupDeviceKey();
        final did = keyInfo['device_id'] as String;
        final kid = keyInfo['key_id'] as String;
        final pem = keyInfo['public_key'] as String;
        deviceId = did;

        // 发送端（对端 uid=peer_1）：建二人会话，encrypt 前导出
        final outbound = vod.GroupSession();
        final sessionId = outbound.sessionId;
        final exported = outbound.toInbound().exportAt(0)!;
        final payload = GroupSessionService.buildRoomKeyPayload(
          sessionId: sessionId,
          exportedKey: exported,
          didToPem: {did: pem},
          didToKid: {did: kid},
        );

        // 接收端：C2C 消息 data['to'] 是本端 uid，严禁被当作会话域
        await GroupSessionService.to.handleRoomKeyMessage({
          'from': 'peer_1',
          'to': 'my_uid_should_not_be_scope',
          'type': 'C2C',
          'payload': payload,
        });

        final ct = outbound.encrypt('单聊 Megolm 消息');
        final plain = await GroupSessionService.to.decryptC2CMessage(
          sessionId: sessionId,
          ciphertext: ct,
        );
        expect(plain, '单聊 Megolm 消息');

        // 域隔离：同 sessionId 的群域查不到（未污染群存储命名空间）
        await expectLater(
          GroupSessionService.to.decryptGroupMessage(
            gid: 'my_uid_should_not_be_scope',
            sessionId: sessionId,
            ciphertext: ct,
          ),
          throwsA(anything),
        );
      },
    );

    // 安全回归（发现1 HIGH）：域混淆注入必须被拒——攻击者以 type=C2G,to=群A
    // 发送，但 payload.gid=群B，不得写入群 B 的 Megolm 命名空间。
    test('域混淆：type/to 与 payload.gid 不一致的群 room key 被丢弃', () async {
      final hasLib = Directory(_spikeLibDir).existsSync();
      if (!hasLib) {
        markTestSkipped('spike 动态库缺失：$_spikeLibDir');
        return;
      }
      await _ensureVod();

      final keyInfo = await _setupDeviceKey();
      final did = keyInfo['device_id'] as String;
      final kid = keyInfo['key_id'] as String;
      final pem = keyInfo['public_key'] as String;
      deviceId = did;

      const victimGid = 'g_victim_B';
      final outbound = vod.GroupSession();
      final sessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0)!;
      // payload 声明目标群 B，但传输层 to=群 A（攻击者有权限的群）
      final payload = GroupSessionService.buildRoomKeyPayload(
        gid: victimGid,
        sessionId: sessionId,
        exportedKey: exported,
        didToPem: {did: pem},
        didToKid: {did: kid},
      );

      await GroupSessionService.to.handleRoomKeyMessage({
        'from': 'attacker_uid',
        'to': 'g_attacker_A', // ≠ payload.gid
        'type': 'C2G',
        'payload': payload,
      });

      // 断言：群 B 命名空间未被写入伪造 session（解密应失败）
      final ct = outbound.encrypt('注入的伪造消息');
      await expectLater(
        GroupSessionService.to.decryptGroupMessage(
          gid: victimGid,
          sessionId: sessionId,
          ciphertext: ct,
        ),
        throwsA(anything),
        reason: '域不匹配的 room key 不得写入声明群的存储命名空间',
      );
    });

    // C2C key 若从 C2G 通道到达（通道混淆）必须被拒
    test('通道混淆：scope=c2c 的 room key 从 C2G 通道到达被丢弃', () async {
      final hasLib = Directory(_spikeLibDir).existsSync();
      if (!hasLib) {
        markTestSkipped('spike 动态库缺失：$_spikeLibDir');
        return;
      }
      await _ensureVod();

      final keyInfo = await _setupDeviceKey();
      final did = keyInfo['device_id'] as String;
      final kid = keyInfo['key_id'] as String;
      final pem = keyInfo['public_key'] as String;
      deviceId = did;

      final outbound = vod.GroupSession();
      final sessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0)!;
      final payload = GroupSessionService.buildRoomKeyPayload(
        sessionId: sessionId, // 无 gid → scope=c2c
        exportedKey: exported,
        didToPem: {did: pem},
        didToKid: {did: kid},
      );

      await GroupSessionService.to.handleRoomKeyMessage({
        'from': 'attacker_uid',
        'to': 'some_group',
        'type': 'C2G', // c2c payload 走群通道 → 拒
        'payload': payload,
      });

      final ct = outbound.encrypt('通道混淆消息');
      await expectLater(
        GroupSessionService.to.decryptC2CMessage(
          sessionId: sessionId,
          ciphertext: ct,
        ),
        throwsA(anything),
        reason: 'c2c room key 只能从 C2C 通道到达',
      );
    });
  });
}
