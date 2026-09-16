/// CSM-02（§12.5.1）— 坐席会话动作纯函数与运行状态机单测
///
/// 覆盖：
/// - 转接目标过滤：只列同 Org active customer_service identity，排除自己；
/// - 关闭原因白名单/限长（控制字符剥离、空→null、200 字截断）；
/// - sender-actor 展示映射（visitor=左客户掩码名 / seat=右业务身份名）；
/// - CsSeatSessionMachine 降级语义：403 → 清写入口+停轮询；offboarding
///   409 → 只读终态；close → 输入禁用等待评分；rating 回显 → 终态；
///   suspend 只读可恢复、offboarding 不可恢复。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_actions.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

BusinessIdentity _identity(String id, String orgId, String fn, String status) =>
    BusinessIdentity(
      id: id,
      organizationId: orgId,
      displayName: '坐席$id',
      functionKey: fn,
      status: status,
    );

void main() {
  const orgA = '7266418340025468901';
  const orgB = '7266418340025468999';

  group('CSM-02 转接目标过滤（csTransferTargets）', () {
    test('只列同 Org active customer_service identity，排除自己', () {
      final identities = [
        _identity('me', orgA, kCsFunctionKey, 'active'),
        _identity('peer1', orgA, kCsFunctionKey, 'active'),
        _identity('peer2', orgA, kCsFunctionKey, 'disabled'),
        _identity('peer3', orgA, 'sales', 'active'),
        _identity('peer4', orgB, kCsFunctionKey, 'active'),
      ];
      final targets = csTransferTargets(
        identities,
        organizationId: orgA,
        excludeIdentityId: 'me',
      );
      expect(targets.map((t) => t.id).toList(), [
        'peer1',
      ], reason: 'disabled/错职能/跨 Org/自己 一律排除');
    });

    test('无候选 → 空列表（UI 显示不可转接空态）', () {
      expect(
        csTransferTargets(
          [_identity('me', orgA, kCsFunctionKey, 'active')],
          organizationId: orgA,
          excludeIdentityId: 'me',
        ),
        isEmpty,
      );
    });
  });

  group('CSM-02 关闭原因清洗（csSanitizeCloseReason）', () {
    test('null / 空白 → null（按无 reason 提交）', () {
      expect(csSanitizeCloseReason(null), isNull);
      expect(csSanitizeCloseReason(''), isNull);
      expect(csSanitizeCloseReason('   '), isNull);
      expect(csSanitizeCloseReason('\n\t'), isNull);
    });

    test('控制字符剥离 + trim；正常文本原样保留', () {
      expect(csSanitizeCloseReason('  已解决\n'), '已解决');
      expect(csSanitizeCloseReason('问\x00题已处理'), '问 题已处理');
    });

    test('限长：默认 200 字截断', () {
      final long = 'a' * 300;
      final out = csSanitizeCloseReason(long);
      expect(out, isNotNull);
      expect(out!.length, 200);
      // 自定义限长
      expect(csSanitizeCloseReason('abcdef', maxLength: 3), 'abc');
    });
  });

  group('CSM-02 sender-actor 展示映射（csSenderActorView）', () {
    EnterpriseMessage msg(EnterpriseSenderType type, {String seatName = ''}) =>
        EnterpriseMessage(
          id: '7266418340025468960',
          conversationId: '7266418340025468950',
          organizationId: orgA,
          senderType: type,
          senderContactId: type == EnterpriseSenderType.contact ? 'c1' : '',
          senderBusinessIdentityId:
              type == EnterpriseSenderType.businessIdentity ? 'i1' : '',
          senderBusinessIdentityName: seatName,
          content: 'hello',
        );

    test('访客入站：左侧 + 客户掩码名', () {
      final view = csSenderActorView(
        msg(EnterpriseSenderType.contact),
        contactMaskedName: '张**',
      );
      expect(view.isSeat, isFalse);
      expect(view.label, '张**');
    });

    test('坐席出站：右侧 + 业务身份名（不是自然人好友）', () {
      final view = csSenderActorView(
        msg(EnterpriseSenderType.businessIdentity, seatName: '售后小张'),
        contactMaskedName: '张**',
      );
      expect(view.isSeat, isTrue);
      expect(view.label, '售后小张');
    });

    test('坐席名缺失：回落 wire 名（不回落客户名/自然人）', () {
      final view = csSenderActorView(
        msg(EnterpriseSenderType.businessIdentity),
        contactMaskedName: '张**',
      );
      expect(view.isSeat, isTrue);
      expect(view.label, EnterpriseSenderType.businessIdentity.wireName);
    });
  });

  group('CSM-02 坐席会话运行状态机（CsSeatSessionMachine）', () {
    test('初始可写：canSend/shouldPoll 为真，无解释键', () {
      final m = CsSeatSessionMachine();
      expect(m.phase, CsSeatSessionPhase.writable);
      expect(m.canSend, isTrue);
      expect(m.shouldPoll, isTrue);
      expect(m.explainKey, '');
    });

    test('403 suspend：清写入口 + 停后台发送 + 可解释只读；可恢复', () {
      final m = CsSeatSessionMachine();
      expect(m.markSuspended(), isTrue);
      expect(m.canSend, isFalse, reason: '写入口被清');
      expect(m.shouldPoll, isFalse, reason: '停后台发送/轮询');
      expect(m.explainKey, 'readOnlySuspended');

      // 恢复：后续读成功 → 回 writable
      expect(m.restoreFromSuspension(), isTrue);
      expect(m.canSend, isTrue);
      expect(m.shouldPoll, isTrue);
    });

    test('offboarding 409：只读终态，不可恢复、不可再被 suspend 覆盖', () {
      final m = CsSeatSessionMachine();
      expect(m.markOffboarding(), isTrue);
      expect(m.canSend, isFalse);
      expect(m.shouldPoll, isFalse);
      expect(m.explainKey, 'offboardingRequired');

      expect(m.restoreFromSuspension(), isFalse);
      expect(m.markSuspended(), isFalse);
      expect(m.phase, CsSeatSessionPhase.offboardingRequired);
    });

    test('closed：输入禁用但轮询保持（可继续收尾读）；rating 回显 → 终态', () {
      final m = CsSeatSessionMachine();
      expect(m.markClosed(), isTrue);
      expect(m.canSend, isFalse, reason: '关闭后输入禁用');
      expect(m.shouldPoll, isTrue, reason: 'closed 仍允许增量读');
      expect(m.explainKey, 'closed');

      expect(m.markRated(), isTrue);
      expect(m.canSend, isFalse);
      expect(m.explainKey, 'rated');
      expect(m.markClosed(), isFalse, reason: 'rated 为终态');
    });

    test('suspend 之后 close 仍可达（暂停只读不吞关闭回显）', () {
      final m = CsSeatSessionMachine()..markSuspended();
      expect(m.markClosed(), isTrue);
      expect(m.phase, CsSeatSessionPhase.closed);
    });
  });
}
