import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/e2ee/capability_guard.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/olm_session_service.dart' show kOlmSuite;
import 'package:imboy/store/api/e2ee_api.dart' show E2EEGroupHistoryGrant;
import 'package:vodozemac/vodozemac.dart' as vod;

import '../../vodozemac_native_lib.dart';

/// C08 / AC-17 客户端撤销语义负例矩阵：
///
/// 四个场景本地均不得解密撤销后消息（fail-closed 或触发 rotate/拒发）：
/// 1. 撤销与发送/分发并发：stale 标记消费 → 强刷快照 → rotate 原子闭环，
///    被踢设备不在新 room key 分发列表，旧 inbound 解不开新 session 密文。
/// 2. 漏 S2C（服务器漏推撤销事件）：本地快照缓存未感知时不 rotate（现状），
///    policy_violation 兜底（_handlePolicyViolation 同款 markGroupStale 语义）
///    后下一次发送强制绕过缓存刷新 → 设备集合变化 → rotate。
/// 3. 离线旧会话（本地持有旧 room key 未收到轮换）：无新 session key →
///    no key found；旧 inbound 直解新密文被 vodozemac 拒绝；即使 key 经
///    备份恢复，恢复授权区间（grant end_seq）不放行撤销后消息。
/// 4. 重连后旧 recipient（已踢成员的设备重新上线拉取）：误投/重放的
///    room key 在群域必须先通过服务器权威 grant 验证，denied → 拒存。
///
/// 以及 AC-17 C2G 固定套件门（C07 enforcePeerSupportsRequired(scope:'c2g')
/// 生产接线）：不支持 Megolm 套件的 recipient 设备 → 显式拒发 + 计数，
/// 不降级、不静默跳过、不产出半份密文。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final store = <String, String?>{};

  setUpAll(() {
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

  setUp(() {
    store.clear();
    GroupSessionService.to.clearMemory();
    GroupSessionService.c2gSuiteIncompatibleCount = 0;
    GroupSessionService.to.debugHistoryGrantLoader = null;
    GroupSessionService.to.debugGroupSuiteDeviceListLoader = null;
  });

  tearDown(() {
    GroupSessionService.to.clearMemory();
    GroupSessionService.to.debugHistoryGrantLoader = null;
    GroupSessionService.to.debugGroupSuiteDeviceListLoader = null;
    GroupSessionService.to.debugRoomKeySender = null;
    GroupSessionService.to.debugOlmWrap = null;
    GroupSessionService.to.debugOlmUnwrap = null;
    E2EEService.clearKeyCacheForTest();
    E2EEService.debugGroupMemberKeysLoader = null;
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
  });

  bool hasLib() => hasVodozemacTestLib();
  Future<void> ensureVod() async {
    await ensureVodozemac();
    GroupSessionService.debugMarkVodReady();
  }

  /// 标准三设备编排：sender（本机）+ peer1 + peer2（将被撤销）。
  /// 返回捕获 room key 分发的记录器（同时注入套件门 loader：三台默认
  /// 设备全部具备 Olm 身份；需要"旧端设备"负例时由用例自行覆盖 loader）。
  (List<Map<String, dynamic>>, void Function()) wireRoomKeyCapture() {
    final sentPayloads = <Map<String, dynamic>>[];
    GroupSessionService.to.debugRoomKeySender = (chatType, to, payload) {
      sentPayloads.add(payload);
    };
    GroupSessionService.to.debugOlmWrap = (did, exportedKey) async =>
        (type: 0, body: 'olm-for-$did');
    // 成员 uid 映射：权威快照用 9001/9002/9003；
    // setGroupDeviceKeyCacheForTest 注入的缓存生成 uid_<did> 形态。
    // 两种 uid 都按成员回查到设备（全部具备 Olm 身份 = 支持 Megolm）。
    const memberDids = ['sender_did', 'peer1_did', 'peer2_did'];
    GroupSessionService.to.debugGroupSuiteDeviceListLoader = (uid) async => [
      for (final (i, did) in memberDids.indexed)
        if (uid == 'uid_$did' || uid == '900${i + 1}') {'device_id': did},
    ];
    return (sentPayloads, () {});
  }

  group('AC-17 场景1：撤销与发送/分发并发 → 下一条消息 rotate 且旧设备出局', () {
    test('stale 后发送必须 rotate，被踢设备不在新 room key，旧 inbound 解不开新密文', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9201';
      const senderDid = 'sender_did';
      const peer1Did = 'peer1_did';
      const peer2Did = 'peer2_did';
      deviceId = senderDid;
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );

      // 服务器权威快照：sender + peer1 + peer2（可强刷拉取）
      E2EEService.debugGroupMemberKeysLoader = (_) async => [
        {
          'uid': '9001',
          'devices': [
            {'device_id': senderDid, 'public_key': 'sender-pem'},
          ],
        },
        {
          'uid': '9002',
          'devices': [
            {'device_id': peer1Did, 'public_key': 'peer1-pem'},
          ],
        },
        {
          'uid': '9003',
          'devices': [
            {'device_id': peer2Did, 'public_key': 'peer2-pem'},
          ],
        },
      ];
      final (sentPayloads, _) = wireRoomKeyCapture();

      // 撤销前：msg1 走 session1，room key 分发给 peer1 + peer2
      final msg1 = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: '撤销前消息',
      );
      final session1Keys = (sentPayloads.last['keys'] as List)
          .map((e) => (e as Map)['did'].toString())
          .toSet();
      expect(session1Keys, {peer1Did, peer2Did});

      // 撤销事件到达（group_member_leave S2C → markGroupStale），与发送并发：
      // 服务器权威快照已剔除 peer2
      GroupSessionService.to.markGroupStale(gid);
      E2EEService.debugGroupMemberKeysLoader = (_) async => [
        {
          'uid': '9001',
          'devices': [
            {'device_id': senderDid, 'public_key': 'sender-pem'},
          ],
        },
        {
          'uid': '9002',
          'devices': [
            {'device_id': peer1Did, 'public_key': 'peer1-pem'},
          ],
        },
      ];

      // 下一条消息：stale 消费 → forceRefresh → 设备集合变化 → rotate
      final msg2 = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: '撤销后消息',
      );
      expect(msg2.sessionId, isNot(msg1.sessionId), reason: '撤销后必须 rotate');
      final session2Keys = (sentPayloads.last['keys'] as List)
          .map((e) => (e as Map)['did'].toString())
          .toSet();
      expect(session2Keys, {peer1Did}, reason: '被撤销设备不得出现在新 room key 分发列表');

      // 被撤销设备视角：本地持有 session1 的 inbound（离线前收到），
      // 解密撤销后消息必须失败（vodozemac 层拒绝，fail-closed）
      final p2Inbound1 = vod.InboundGroupSession.import(
        store['megolm_inbound_$gid:${msg1.sessionId}']!,
      );
      expect(
        () => p2Inbound1.decrypt(msg2.ciphertext),
        throwsA(anything),
        reason: '旧 room key 必须解不开 rotate 后的密文',
      );

      // 合法成员视角：发送端自持 inbound 可解密撤销后消息
      expect(
        await GroupSessionService.to.decryptGroupMessage(
          gid: gid,
          sessionId: msg2.sessionId,
          ciphertext: msg2.ciphertext,
        ),
        '撤销后消息',
      );
    });
  });

  group('AC-17 场景2：漏 S2C → 策略兜底后下一次发送前强制校验并 rotate', () {
    test('漏收 leave 时不误 rotate（缓存内），markGroupStale 兜底后强刷快照 rotate', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9202';
      const senderDid = 'sender_did';
      const peer1Did = 'peer1_did';
      const peer2Did = 'peer2_did';
      deviceId = senderDid;
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );

      // 服务器已踢 peer2，但 S2C leave 漏推：本地缓存（未过期）仍是三设备
      E2EEService.setGroupDeviceKeyCacheForTest(gid, {
        senderDid: 'sender-pem',
        peer1Did: 'peer1-pem',
        peer2Did: 'peer2-pem',
      });
      E2EEService.debugGroupMemberKeysLoader = (_) async => [
        {
          'uid': '9001',
          'devices': [
            {'device_id': senderDid, 'public_key': 'sender-pem'},
          ],
        },
        {
          'uid': '9002',
          'devices': [
            {'device_id': peer1Did, 'public_key': 'peer1-pem'},
          ],
        },
      ];
      final (sentPayloads, _) = wireRoomKeyCapture();

      // 漏 S2C 期间发送：消费缓存快照（设备集合未变）→ 不 rotate。
      // 服务端 attestation gate 会拒收该条（e2ee_session_generation_mismatch，
      // 由后端 EUnit 守护），客户端不降级明文（retry_plaintext_guard 守护）。
      final msg1 = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: '漏 S2C 窗口消息',
      );
      final cachedKeys = (sentPayloads.last['keys'] as List)
          .map((e) => (e as Map)['did'].toString())
          .toSet();
      expect(cachedKeys, {peer1Did, peer2Did}, reason: '缓存窗口内不感知撤销');

      // 兜底到达：policy_violation S2C（reason=e2ee_session_generation_mismatch）
      // → _handlePolicyViolation → markGroupStale（可恢复 policy error 触发
      // 下次发送前 rotate）
      GroupSessionService.to.markGroupStale(gid);

      final msg2 = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: '兜底 rotate 后消息',
      );
      expect(msg2.sessionId, isNot(msg1.sessionId));
      final rotatedKeys = (sentPayloads.last['keys'] as List)
          .map((e) => (e as Map)['did'].toString())
          .toSet();
      expect(rotatedKeys, {peer1Did}, reason: 'stale 消费 → 强刷快照 → 被踢设备出局');
      // 被踢设备旧 inbound 解不开撤销后密文
      final p2Inbound1 = vod.InboundGroupSession.import(
        store['megolm_inbound_$gid:${msg1.sessionId}']!,
      );
      expect(() => p2Inbound1.decrypt(msg2.ciphertext), throwsA(anything));
    });
  });

  group('AC-17 场景3：离线旧会话 → 本地旧 room key 不得解密轮换后消息', () {
    test('无新 key fail-closed + 旧 inbound 被拒 + 恢复授权区间不放行撤销后消息', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9203';
      const senderDid = 'sender_did';
      const peer1Did = 'peer1_did';
      const peer2Did = 'peer2_did';
      deviceId = senderDid;
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      E2EEService.setGroupDeviceKeyCacheForTest(gid, {
        senderDid: 'sender-pem',
        peer1Did: 'peer1-pem',
        peer2Did: 'peer2-pem',
      });
      final (_, _) = wireRoomKeyCapture();

      // peer2 离线前：session1（其设备持有 inbound）
      final msg1 = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: 'peer2 离线前消息',
      );
      final session1Exported = store['megolm_inbound_$gid:${msg1.sessionId}']!;

      // peer2 离线期间被撤销并 rotate
      GroupSessionService.to.markGroupStale(gid);
      E2EEService.debugGroupMemberKeysLoader = (_) async => [
        {
          'uid': '9001',
          'devices': [
            {'device_id': senderDid, 'public_key': 'sender-pem'},
          ],
        },
        {
          'uid': '9002',
          'devices': [
            {'device_id': peer1Did, 'public_key': 'peer1-pem'},
          ],
        },
      ];
      final msg2 = await GroupSessionService.to.encryptGroupMessage(
        gid: gid,
        plaintext: 'peer2 离线期间消息',
      );

      // peer2 重新上线（本地仅 session1）：
      // ① 无 session2 key → no key found（fail-closed）
      final p2Store = <String, String?>{
        'megolm_inbound_$gid:${msg1.sessionId}': session1Exported,
      };
      // 模拟 peer2 的本地存储：仅包含 session1 的 inbound
      store
        ..clear()
        ..addAll(p2Store);
      GroupSessionService.to.clearMemory();
      deviceId = peer2Did;
      await expectLater(
        GroupSessionService.to.decryptGroupMessage(
          gid: gid,
          sessionId: msg2.sessionId,
          ciphertext: msg2.ciphertext,
        ),
        throwsA(anything),
        reason: '被踢设备无新 session key，必须 no key found',
      );

      // ② 旧 inbound 直解新密文 → vodozemac 拒绝
      final p2Inbound1 = vod.InboundGroupSession.import(session1Exported);
      expect(() => p2Inbound1.decrypt(msg2.ciphertext), throwsA(anything));

      // ③ 即使 session2 key 经备份泄露/恢复到 peer2（攻击上界），恢复授权
      // 区间（restored grant end_seq）也不放行撤销后消息（AC-18 D3 语义）
      final grant = MegolmHistoryGrant(
        scope: gid,
        sessionId: msg2.sessionId,
        generationNo: 1,
        startSeq: 1,
        endSeq: 500,
      );
      store['$kMegolmRestoredGrantPrefix$gid:${msg2.sessionId}'] = jsonEncode(
        grant.toJson(),
      );
      // 模拟重启/重连：清内存缓存后重新从安全存储读 restored grant
      // （lookups 一次性缓存与备份恢复先于解密的生产时序一致）
      GroupSessionService.to.clearMemory();
      // grant 加载器不可用/拒绝（被撤销成员的服务端查询 → denied）
      GroupSessionService.to.debugHistoryGrantLoader = (_, _) async =>
          throw StateError('denied');
      await expectLater(
        GroupSessionService.to.debugEnforceRestoredHistoryGrant(
          gid,
          msg2.sessionId,
          501, // 撤销后消息的 conv_seq 超出授权区间
        ),
        throwsA(isA<StateError>()),
        reason: '恢复授权区间外必须 historical_room_key_scope_denied',
      );
      // 区间内（服务端曾授权的历史）不受影响
      await GroupSessionService.to.debugEnforceRestoredHistoryGrant(
        gid,
        msg2.sessionId,
        500,
      );
    });
  });

  group('AC-17 场景4：重连后旧 recipient → 误投 room key 必须过权威 grant 验证', () {
    test('grant denied 时拒存 room key，被踢设备重连后仍无法解密', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9204';
      const peer2Did = 'peer2_did';
      deviceId = peer2Did;

      // 攻击/误投路径：已踢设备收到撤销后 session 的 room key（C2G 帧，
      // 域字段一致——模拟服务端误投或网络重放）
      final outbound = vod.GroupSession();
      final sessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0)!;
      final payload = GroupSessionService.buildRoomKeyPayload(
        gid: gid,
        sessionId: sessionId,
        exportedKey: exported,
        didToPem: {peer2Did: 'peer2-pem'},
        didToKid: {peer2Did: 'kid2'},
      );
      // v3 Olm-only：直接构造带 olm 子对象的条目（绕开发送侧生产编排）
      ((payload['keys'] as List).single as Map)['olm'] = {
        'v': kOlmSuite,
        'type': 0,
        'sid': 'sender_dev',
        'body': 'OLM_CT',
      };
      GroupSessionService.to.debugOlmUnwrap = (a, b, c, d) async => exported;

      // 服务器权威 grant 查询 → 被撤销成员 denied（authorize_group_history
      // 的 {error, denied} 在客户端表现为 API 失败）
      GroupSessionService.to.debugHistoryGrantLoader = (_, _) async =>
          throw StateError('denied');

      final accepted = await GroupSessionService.to.handleRoomKeyMessage({
        'from': 'sender_uid',
        'to': gid,
        'type': 'C2G',
        'payload': payload,
      });
      expect(accepted, isTrue, reason: '消息本身被正常消费（不重投）');

      // 关键断言：room key 被拒存（无 inbound 落地、无内存缓存）
      expect(
        store.containsKey('megolm_inbound_$gid:$sessionId'),
        isFalse,
        reason: 'grant denied → 群 room key 不得落地（AC-18 fail-closed）',
      );
      // 被踢设备重连后解密撤销后消息 → no key found
      final ct = outbound.encrypt('撤销后消息');
      await expectLater(
        GroupSessionService.to.decryptGroupMessage(
          gid: gid,
          sessionId: sessionId,
          ciphertext: ct,
        ),
        throwsA(anything),
      );
    });

    test('合法成员 grant 通过时 room key 正常落地（对照组，不误伤）', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9205';
      const memberDid = 'member_did';
      deviceId = memberDid;

      final outbound = vod.GroupSession();
      final sessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0)!;
      final payload = GroupSessionService.buildRoomKeyPayload(
        gid: gid,
        sessionId: sessionId,
        exportedKey: exported,
        didToPem: {memberDid: 'member-pem'},
        didToKid: {memberDid: 'kid_m'},
      );
      ((payload['keys'] as List).single as Map)['olm'] = {
        'v': kOlmSuite,
        'type': 0,
        'sid': 'sender_dev',
        'body': 'OLM_CT',
      };
      GroupSessionService.to.debugOlmUnwrap = (a, b, c, d) async => exported;
      GroupSessionService.to.debugHistoryGrantLoader = (g, sid) async =>
          E2EEGroupHistoryGrant(
            gid: g,
            sessionId: sid,
            generationNo: 1,
            startSeq: 1,
            endSeq: 100,
          );

      await GroupSessionService.to.handleRoomKeyMessage({
        'from': 'sender_uid',
        'to': gid,
        'type': 'C2G',
        'payload': payload,
      });
      expect(store.containsKey('megolm_inbound_$gid:$sessionId'), isTrue);
      expect(
        await GroupSessionService.to.decryptGroupMessage(
          gid: gid,
          sessionId: sessionId,
          ciphertext: outbound.encrypt('合法成员可解'),
        ),
        '合法成员可解',
      );
    });
  });

  group('AC-17 C2G 固定套件门（C07 enforcePeerSupportsRequired scope:c2g）', () {
    test('全部 recipient 具备 Olm 身份 → 通过（不抛、不计数）', () async {
      GroupSessionService.to.debugGroupSuiteDeviceListLoader = (uid) async => [
        {'device_id': 'did_a'},
        {'device_id': 'did_b'},
      ];
      await GroupSessionService.enforceGroupFanoutSuitePolicy(
        gid: '9206',
        recipientDidToPem: {'did_a': 'pem', 'did_b': 'pem'},
        didToUid: {'did_a': '1001', 'did_b': '1002'},
      );
      expect(GroupSessionService.c2gSuiteIncompatibleCount, 0);
    });

    test('任一设备无 Olm 身份（旧端仅 RSA）→ 拒发 + 计数，不降级', () async {
      GroupSessionService.to.debugGroupSuiteDeviceListLoader = (uid) async =>
          uid == '1001'
          ? [
              {'device_id': 'did_a'},
            ]
          : <Map<String, dynamic>>[];
      await expectLater(
        GroupSessionService.enforceGroupFanoutSuitePolicy(
          gid: '9207',
          recipientDidToPem: {'did_a': 'pem', 'legacy_did': 'pem'},
          didToUid: {'did_a': '1001', 'legacy_did': '1002'},
        ),
        throwsA(
          isA<FixedSuiteIncompatibleException>()
              .having((e) => e.scope, 'scope', 'c2g')
              .having((e) => e.peerDeviceId, 'peerDeviceId', 'legacy_did'),
        ),
      );
      expect(
        GroupSessionService.c2gSuiteIncompatibleCount,
        1,
        reason: '拒发必须计数（rollout 可观测）',
      );
    });

    test('服务端能力列表查询失败（空表语义）→ 全部设备视为不支持 → 拒发', () async {
      GroupSessionService.to.debugGroupSuiteDeviceListLoader = (_) async =>
          const <Map<String, dynamic>>[];
      await expectLater(
        GroupSessionService.enforceGroupFanoutSuitePolicy(
          gid: '9208',
          recipientDidToPem: {'did_a': 'pem'},
          didToUid: {'did_a': '1001'},
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );
    });

    test('设备归属未知（didToUid 无映射）→ fail-closed 拒发，不猜测', () async {
      await expectLater(
        GroupSessionService.enforceGroupFanoutSuitePolicy(
          gid: '9209',
          recipientDidToPem: {'orphan_did': 'pem'},
          didToUid: const {},
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
      );
      expect(GroupSessionService.c2gSuiteIncompatibleCount, 1);
    });

    test('无远端 recipient（单人自持会话）→ 直接通过', () async {
      await GroupSessionService.enforceGroupFanoutSuitePolicy(
        gid: '9210',
        recipientDidToPem: const {},
        didToUid: const {},
      );
      expect(GroupSessionService.c2gSuiteIncompatibleCount, 0);
    });

    test('发送链集成：群成员设备不支持 Megolm → encryptGroupMessage 显式失败', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9211';
      const senderDid = 'sender_did';
      const legacyDid = 'legacy_did';
      deviceId = senderDid;
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
      E2EEService.setGroupDeviceKeyCacheForTest(gid, {
        senderDid: 'sender-pem',
        legacyDid: 'legacy-pem',
      });
      // legacy 设备不在任何 Olm 列表（旧客户端只有 RSA 身份）
      GroupSessionService.to.debugGroupSuiteDeviceListLoader = (_) async =>
          const <Map<String, dynamic>>[];

      await expectLater(
        GroupSessionService.to.encryptGroupMessage(
          gid: gid,
          plaintext: '不应被加密',
        ),
        throwsA(isA<FixedSuiteIncompatibleException>()),
        reason: '套件门在 rotate/分发前拒发，不产出半份 room key',
      );
      expect(GroupSessionService.c2gSuiteIncompatibleCount, 1);
      // 无 room key 分发发生（fail-closed，不产出半份密文）
      // （debugRoomKeySender 未注入，若被调用会走 WebSocket 真发路径并抛错）
    });
  });

  group('AC-18 伪造负例：room key / grant 篡改全部拒绝', () {
    test('伪造 session_id（payload 声明与密钥实际 session 不一致）→ 丢弃', () async {
      if (!hasLib()) {
        markTestSkipped('vodozemac 测试原生库缺失');
        return;
      }
      await ensureVod();

      const gid = '9212';
      const memberDid = 'member_did';
      deviceId = memberDid;

      final outbound = vod.GroupSession();
      final realSessionId = outbound.sessionId;
      final exported = outbound.toInbound().exportAt(0)!;
      // 攻击者把 session_id 改写为另一个值（伪造跨 session 绑定）
      final payload = GroupSessionService.buildRoomKeyPayload(
        gid: gid,
        sessionId: 'forged_session_id',
        exportedKey: exported,
        didToPem: {memberDid: 'member-pem'},
        didToKid: {memberDid: 'kid_m'},
      );
      ((payload['keys'] as List).single as Map)['olm'] = {
        'v': kOlmSuite,
        'type': 0,
        'sid': 'sender_dev',
        'body': 'OLM_CT',
      };
      GroupSessionService.to.debugOlmUnwrap = (a, b, c, d) async => exported;
      GroupSessionService.to.debugHistoryGrantLoader = (g, sid) async =>
          E2EEGroupHistoryGrant(
            gid: g,
            sessionId: sid,
            generationNo: 1,
            startSeq: 1,
            endSeq: 100,
          );

      await GroupSessionService.to.handleRoomKeyMessage({
        'from': 'sender_uid',
        'to': gid,
        'type': 'C2G',
        'payload': payload,
      });

      expect(
        store.containsKey('megolm_inbound_$gid:forged_session_id'),
        isFalse,
        reason: 'session_id 与密钥不匹配必须丢弃',
      );
      expect(
        store.containsKey('megolm_inbound_$gid:$realSessionId'),
        isFalse,
        reason: '也不得以真实 session id 落地未验证的 key',
      );
    });

    test(
      '伪造恢复 grant（epoch/scope/version/source 篡改）→ parse 失败 → 解密 fail-closed',
      () async {
        // 篡改 epoch_id（≠ session_id）：MegolmHistoryGrant.parse 拒绝
        const base = MegolmHistoryGrant(
          scope: '9213',
          sessionId: 'session-x',
          generationNo: 2,
          startSeq: 1,
          endSeq: 100,
        );
        final json = base.toJson();
        expect(
          MegolmHistoryGrant.parse(
            jsonEncode({...json, 'epoch_id': 'other-session'}),
            expectedScope: '9213',
            expectedSessionId: 'session-x',
          ),
          isNull,
          reason: 'epoch_id 伪造必须拒绝',
        );
        // 篡改 scope（跨群重放）
        expect(
          MegolmHistoryGrant.parse(
            jsonEncode({...json, 'scope': '9999'}),
            expectedScope: '9213',
            expectedSessionId: 'session-x',
          ),
          isNull,
          reason: '跨群 scope 必须拒绝',
        );
        // 篡改版本与来源
        expect(
          MegolmHistoryGrant.parse(
            jsonEncode({...json, 'version': 2}),
            expectedScope: '9213',
            expectedSessionId: 'session-x',
          ),
          isNull,
        );
        expect(
          MegolmHistoryGrant.parse(
            jsonEncode({...json, 'source': 'local_guess'}),
            expectedScope: '9213',
            expectedSessionId: 'session-x',
          ),
          isNull,
        );
        // 扩大区间（end_seq < start_seq 的畸形"扩大"）直接拒绝
        expect(
          MegolmHistoryGrant.parse(
            jsonEncode({...json, 'start_seq': 200, 'end_seq': 100}),
            expectedScope: '9213',
            expectedSessionId: 'session-x',
          ),
          isNull,
        );

        // 篡改 grant 落地后解密路径 fail-closed：parse null → 视为无有效
        // restored grant 时密钥已恢复的会话必须拒绝解密（StateError）
        store['${kMegolmRestoredGrantPrefix}9213:session-x'] = jsonEncode({
          ...json,
          'epoch_id': 'other-session',
        });
        await expectLater(
          GroupSessionService.to.debugEnforceRestoredHistoryGrant(
            '9213',
            'session-x',
            50,
          ),
          throwsA(isA<StateError>()),
          reason: '恢复 grant 解析失败 = fail-closed，不得静默放行',
        );
      },
    );

    test('跨 generation 重放：恢复 grant 世代与服务器当前世代不一致 → 拒绝', () async {
      const restored = MegolmHistoryGrant(
        scope: '9214',
        sessionId: 'session-g',
        generationNo: 1,
        startSeq: 1,
        endSeq: 100,
      );
      store['${kMegolmRestoredGrantPrefix}9214:session-g'] = jsonEncode(
        restored.toJson(),
      );
      // 成员被撤销后重入（服务器侧已是 generation 2）→ 在线刷新返回新世代
      GroupSessionService.to.debugHistoryGrantLoader = (g, sid) async =>
          E2EEGroupHistoryGrant(
            gid: g,
            sessionId: sid,
            generationNo: 2,
            startSeq: 1,
            endSeq: 150,
          );
      await expectLater(
        GroupSessionService.to.debugEnforceRestoredHistoryGrant(
          '9214',
          'session-g',
          101, // 触发在线刷新（超出本地 end_seq）
        ),
        throwsA(isA<StateError>()),
        reason: '跨 generation 重放必须拒绝（世代变更 = 授权根基失效）',
      );
    });
  });
}
