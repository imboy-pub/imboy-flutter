/// FULL-05 — Application 消息来源事实层测试（硬边界「代发可区分 + 非 E2EE 事实保留」）。
///
/// 本文件是 Gate `FLUTTER_UX_PASS` 对能力项 1 的核心证据：
/// - 「Application 代发」与「Human 直发」在**判定层**就不同值（不是靠文案区分）；
/// - 企业托管消息**恒**非 E2EE，且带 e2ee 载荷时也**不**被改判成加密消息；
/// - 来源形态可疑时 fail-closed，不回落成普通 Human 消息；
/// - 审计/详情面必须保留的事实行逐条齐备。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise/public.dart';
import 'package:imboy/modules/enterprise_app/public.dart';

/// 一个自洽的企业托管 origin（后端 `enterprise_message_logic:origin/3` 形状）。
Map<String, dynamic> hostedOrigin({
  required String senderKind,
  String applicationId = '7001',
  String senderUserId = '',
}) => <String, dynamic>{
  'kind': EnterpriseMessageOrigin.wireKind,
  'application_id': applicationId,
  'sender_kind': senderKind,
  if (senderUserId.isNotEmpty) 'sender_user_id': senderUserId,
};

/// 普通 Human-Human 明文 payload（无 origin）。
Map<String, dynamic> humanPayload() => <String, dynamic>{'text': 'hello'};

void main() {
  group('origin 解析', () {
    test('application 代发 origin 解析出自洽形态', () {
      final EnterpriseMessageOrigin? origin = EnterpriseMessageOrigin.tryParse(
        hostedOrigin(senderKind: 'application'),
      );
      expect(origin, isNotNull);
      expect(origin!.kind, EnterpriseMessageOrigin.wireKind);
      expect(origin.applicationId, '7001');
      expect(origin.senderKind, HostedSenderKind.application);
      expect(origin.isWellFormed, isTrue);
      expect(origin.senderUserId, isEmpty);
    });

    test('human 代发 origin 必须带 sender_user_id 才自洽', () {
      final EnterpriseMessageOrigin? wellFormed =
          EnterpriseMessageOrigin.tryParse(
            hostedOrigin(senderKind: 'human', senderUserId: '9001'),
          );
      expect(wellFormed!.senderKind, HostedSenderKind.human);
      expect(wellFormed.senderUserId, '9001');
      expect(wellFormed.isWellFormed, isTrue);

      final EnterpriseMessageOrigin? missingSender =
          EnterpriseMessageOrigin.tryParse(hostedOrigin(senderKind: 'human'));
      expect(missingSender!.isWellFormed, isFalse);
    });

    test('未知 sender_kind 不静默当 application 自洽形态', () {
      final EnterpriseMessageOrigin? origin = EnterpriseMessageOrigin.tryParse(
        hostedOrigin(senderKind: 'robot'),
      );
      expect(origin, isNotNull);
      expect(origin!.senderKindKnown, isFalse);
      expect(origin.isWellFormed, isFalse);
    });

    test('非企业托管 kind → tryParse 返回 null', () {
      expect(
        EnterpriseMessageOrigin.tryParse(<String, dynamic>{
          'kind': 'something_else',
          'application_id': '1',
          'sender_kind': 'application',
        }),
        isNull,
      );
      expect(EnterpriseMessageOrigin.tryParse('not a map'), isNull);
    });
  });

  group('分类：Application 代发 vs Human 直发 可区分', () {
    test('sender_kind=application → applicationDelegated（非 humanDirect）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'type': 'text',
          'text': 'hi',
          'origin': hostedOrigin(senderKind: 'application'),
        },
      );
      expect(facts.messageClass, HostedMessageClass.applicationDelegated);
      expect(facts.isApplicationDelegated, isTrue);
      expect(facts.isHumanDelegated, isFalse);
      expect(facts.isHumanDirect, isFalse);
      expect(facts.showsDelegationBadge, isTrue);
    });

    test('sender_kind=human → humanDelegated（与 application 不同值）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'type': 'text',
          'text': 'hi',
          'origin': hostedOrigin(senderKind: 'human', senderUserId: '9001'),
        },
      );
      expect(facts.messageClass, HostedMessageClass.humanDelegated);
      expect(facts.isHumanDelegated, isTrue);
      expect(facts.isApplicationDelegated, isFalse);
      expect(
        facts.messageClass == HostedMessageClass.applicationDelegated,
        isFalse,
        reason: '两种代发必须是不同枚举值，不能只靠文案区分',
      );
    });

    test('无 origin → humanDirect，且不展示任何企业徽标', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: humanPayload(),
      );
      expect(facts.messageClass, HostedMessageClass.humanDirect);
      expect(facts.isHumanDirect, isTrue);
      expect(facts.isEnterpriseHosted, isFalse);
      expect(facts.showsDelegationBadge, isFalse);
    });

    test('三类判定互斥且全覆盖（两两不同值）', () {
      final Set<String> classes = <String>{
        resolveHostedMessageFacts(payload: humanPayload())
            .messageClass
            .wireName,
        resolveHostedMessageFacts(
          payload: <String, dynamic>{
            'origin': hostedOrigin(senderKind: 'application'),
          },
        ).messageClass.wireName,
        resolveHostedMessageFacts(
          payload: <String, dynamic>{
            'origin': hostedOrigin(senderKind: 'human', senderUserId: '9001'),
          },
        ).messageClass.wireName,
      };
      expect(classes.length, 3);
    });
  });

  group('非 E2EE 事实保留（INV-6）', () {
    test('企业托管消息恒非 E2EE（无载荷）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'origin': hostedOrigin(senderKind: 'application'),
        },
      );
      expect(facts.isNonE2ee, isTrue);
      expect(facts.showsNoE2eeMarker, isTrue);
      expect(facts.originContradictsE2ee, isFalse);
    });

    test('企业托管 + e2ee 载荷 → 仍非 E2EE，且标记不一致（不改判为加密消息）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'origin': hostedOrigin(senderKind: 'human', senderUserId: '9001'),
        },
        e2ee: <String, dynamic>{'devices': <String, dynamic>{}},
      );
      // 分类**不因载荷存在而降级**——这是硬边界本身。
      expect(facts.messageClass, HostedMessageClass.humanDelegated);
      expect(facts.isNonE2ee, isTrue, reason: 'INV-6：企业托管永久非 E2EE');
      expect(facts.originContradictsE2ee, isTrue);
      expect(facts.needsOriginWarning, isTrue);
      expect(facts.showsNoE2eeMarker, isTrue);
    });

    test('普通 Human 带 e2ee 载荷 → 不是非 E2EE（E2EE 链语义不变）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: humanPayload(),
        e2ee: <String, dynamic>{'devices': <String, dynamic>{}},
      );
      expect(facts.isHumanDirect, isTrue);
      expect(facts.isNonE2ee, isFalse);
      expect(facts.showsNoE2eeMarker, isFalse);
      expect(facts.originContradictsE2ee, isFalse);
    });

    test('普通 Human 明文 → 非 E2EE，但不打企业标记', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: humanPayload(),
      );
      expect(facts.isNonE2ee, isTrue);
      expect(facts.showsNoE2eeMarker, isFalse, reason: '非托管不打企业非 E2EE 标记');
      expect(facts.showsDelegationBadge, isFalse);
    });
  });

  group('fail-closed：来源形态可疑不回落普通消息', () {
    test('有 kind 但不匹配 → enterpriseOriginUnrecognized（不降级为 humanDirect）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'text': 'hi',
          'origin': <String, dynamic>{
            'kind': 'unknown_origin',
            'application_id': '1',
          },
        },
      );
      expect(
        facts.messageClass,
        HostedMessageClass.enterpriseOriginUnrecognized,
      );
      expect(facts.isHumanDirect, isFalse);
      expect(facts.isEnterpriseHosted, isFalse);
      expect(facts.needsOriginWarning, isTrue);
      expect(facts.showsNoE2eeMarker, isTrue, reason: '不得暗示已加密');
    });

    test('origin 非 Map（字符串）→ 视为无来源', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{'origin': 'garbage'},
      );
      expect(facts.messageClass, HostedMessageClass.humanDirect);
      expect(facts.needsOriginWarning, isFalse);
    });

    test('payload 为 JSON 字符串时同样解析出处（WS 明文帧形态）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload:
            '{"type":"text","origin":{"kind":"enterprise_application",'
            '"application_id":7001,"sender_kind":"application"}}',
      );
      expect(facts.messageClass, HostedMessageClass.applicationDelegated);
      expect(facts.origin!.applicationId, '7001');
    });

    test('payload 为密文字符串 → 无来源、无异常', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: 'ciphertext-blob',
        e2ee: <String, dynamic>{'devices': <String, dynamic>{}},
      );
      expect(facts.messageClass, HostedMessageClass.humanDirect);
      expect(facts.isNonE2ee, isFalse);
    });
  });

  group('审计事实完整性', () {
    test('traceableFields 逐键齐备（代发 + 非 E2EE 事实都在）', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'origin': hostedOrigin(senderKind: 'human', senderUserId: '9001'),
        },
        senderDisplayName: '张三',
      );
      final Map<String, Object?> fields = facts.audit.traceableFields;
      expect(fields.keys.toSet(), <String>{
        'message_class',
        'application_id',
        'sender_kind',
        'sender_user_id',
        'non_e2ee',
        'has_e2ee_payload',
        'origin_contradicts_e2ee',
        'origin_well_formed',
      });
      expect(fields['message_class'], 'humanDelegated');
      expect(fields['application_id'], '7001');
      expect(fields['sender_kind'], 'human');
      expect(fields['sender_user_id'], '9001');
      expect(fields['non_e2ee'], isTrue);
      expect(fields['has_e2ee_payload'], isFalse);
      expect(fields['origin_contradicts_e2ee'], isFalse);
      expect(fields['origin_well_formed'], isTrue);
      expect(facts.audit.senderDisplayName, '张三');
    });

    test('双痕迹冲突在审计事实里如实记录', () {
      final HostedMessageFacts facts = resolveHostedMessageFacts(
        payload: <String, dynamic>{
          'origin': hostedOrigin(senderKind: 'application'),
        },
        e2ee: <String, dynamic>{'x': 1},
      );
      final Map<String, Object?> fields = facts.audit.traceableFields;
      expect(fields['has_e2ee_payload'], isTrue);
      expect(fields['origin_contradicts_e2ee'], isTrue);
      expect(fields['non_e2ee'], isTrue);
    });

    test('toJson 往返保持关键字段', () {
      final EnterpriseMessageOrigin origin = EnterpriseMessageOrigin.tryParse(
        hostedOrigin(senderKind: 'human', senderUserId: '9001'),
      )!;
      final Map<String, dynamic> json = origin.toJson();
      expect(json['kind'], EnterpriseMessageOrigin.wireKind);
      expect(json['application_id'], '7001');
      expect(json['sender_kind'], 'human');
      expect(json['sender_user_id'], '9001');
    });
  });

  // R08-FL：企业/客服消息时间字段的明确单位 adapter。
  //
  // wire 合同（后端 eb_pg_store_sql：ts 列经 to_unix/1 归一为 Unix 秒整数，
  // eb_message_app/public_message 白名单原样透出 HTTP）：
  // `created_at` / `retain_until` = **epoch 秒**；模型统一持有 epoch 毫秒，
  // 0 = 未知（缺失/非法不回填 now——R08-5 / R21-1）。
  group('R08-FL EnterpriseMessage 时间单位（合同秒 → 毫秒）', () {
    // 计划 6.1 T1 瞬间：1789600000 秒 ≡ 1789600000000ms
    // ≡ 2026-09-16T23:06:40.000Z ≡ 2026-09-17T07:06:40+08:00。
    const int t1Seconds = 1789600000;
    const int t1Millis = 1789600000000;

    test('真实 wire 形状（int 秒）→ 模型毫秒', () {
      final msg = EnterpriseMessage.fromJson(const {
        'id': 7266418340025468934,
        'conversation_id': 7266418340025468933,
        'organization_id': 7266418340025468930,
        'sender_type': 'contact',
        'sender_contact_id': 7266418340025468932,
        'body': 'hello',
        'created_at': t1Seconds,
        'retain_until': 2000000000,
      });
      expect(msg.createdAtMs, t1Millis);
      expect(msg.retainUntilMs, 2000000000000);
      // 模型毫秒 → 本地展示：T1 瞬间换算查看者本地年月日。
      final local = DateTime.fromMillisecondsSinceEpoch(t1Millis).toLocal();
      final expectedLocal =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      expect(
        DateTime.fromMillisecondsSinceEpoch(msg.createdAtMs)
            .toUtc()
            .toIso8601String(),
        startsWith('2026-09-16T23:06:40'),
      );
      expect(expectedLocal, isNotEmpty);
    });

    test('秒数字字符串（数字被字符串化的历史形态）同合同', () {
      final msg = EnterpriseMessage.fromJson(const {
        'id': 1,
        'conversation_id': 2,
        'organization_id': 3,
        'sender_type': 'contact',
        'created_at': '1789600000',
      });
      expect(msg.createdAtMs, t1Millis);
    });

    test('R08-5：缺失/非法/垃圾 → 0（未知），不回填当前时间', () {
      for (final raw in [null, '', 'invalid', '0x1f', 3.5, true, <int>[]]) {
        final msg = EnterpriseMessage.fromJson({
          'id': 1,
          'conversation_id': 2,
          'organization_id': 3,
          'sender_type': 'contact',
          'created_at': raw,
        });
        expect(msg.createdAtMs, 0, reason: 'raw=$raw 应为未知(0)而非 now');
      }
      // 0 是合法瞬间（1970 epoch），与"未知"共用 0 哨兵语义——UI 隐藏。
      final zero = EnterpriseMessage.fromJson(const {
        'id': 1,
        'conversation_id': 2,
        'organization_id': 3,
        'sender_type': 'contact',
        'created_at': 0,
      });
      expect(zero.createdAtMs, 0);
    });

    test('toJson 出站保持秒合同（fromJson↔toJson 单位一致）', () {
      final msg = EnterpriseMessage.fromJson(const {
        'id': 1,
        'conversation_id': 2,
        'organization_id': 3,
        'sender_type': 'contact',
        'created_at': t1Seconds,
        'retain_until': 2000000000,
      });
      final out = msg.toJson();
      expect(out['created_at'], t1Seconds);
      expect(out['retain_until'], 2000000000);
      // 未知（0）不出站，避免把哨兵当真实 1970 瞬间写回。
      final unknown = EnterpriseMessage.fromJson(const {
        'id': 1,
        'conversation_id': 2,
        'organization_id': 3,
        'sender_type': 'contact',
      });
      expect(unknown.toJson().containsKey('created_at'), isFalse);
      expect(unknown.toJson().containsKey('retain_until'), isFalse);
    });
  });
}
