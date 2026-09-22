/// FULL-05 — Application 消息来源事实层测试（硬边界「代发可区分 + 非 E2EE 事实保留」）。
///
/// 本文件是 Gate `FLUTTER_UX_PASS` 对能力项 1 的核心证据：
/// - 「Application 代发」与「Human 直发」在**判定层**就不同值（不是靠文案区分）；
/// - 企业托管消息**恒**非 E2EE，且带 e2ee 载荷时也**不**被改判成加密消息；
/// - 来源形态可疑时 fail-closed，不回落成普通 Human 消息；
/// - 审计/详情面必须保留的事实行逐条齐备。
library;

import 'package:flutter_test/flutter_test.dart';

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
}
