import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/service/message_type_constants.dart';

/// W1-A（chat_multi_select_v1）：多选可选性纯函数全类型矩阵测试。
///
/// 冻结合同 §4.4 类型矩阵：
/// - text/image/imageMulti/voice/audio/video/file/location/expression/quote
///   → 可选；
/// - 系统/控制、WebRTC、E2EE 失败占位、发送中/发送失败、阅后即焚、红包、
///   转账、业务卡片 → 不可选且必须给出稳定 reason code。
void main() {
  MessageSelectionTraits traits(
    String? msgType, {
    MessageStatus status = MessageStatus.delivered,
    bool e2eeFailed = false,
    int burnReadAt = 0,
  }) => MessageSelectionTraits(
    msgType: msgType,
    status: status,
    e2eeFailed: e2eeFailed,
    burnReadAt: burnReadAt,
  );

  group('可选类型白名单（§4.4 支持逐条/合并/导出的基础类型）', () {
    test(
      'text/image/imageMulti/voice/video/file/location/expression/quote 可选',
      () {
        const selectable = <String>[
          MessageType.text,
          MessageType.image,
          MessageType.imageMulti,
          MessageType.voice,
          MessageType.video,
          MessageType.file,
          MessageType.location,
          MessageType.expression,
          MessageType.quote,
        ];
        for (final type in selectable) {
          final decision = evaluateMessageSelectability(traits(type));
          expect(decision.selectable, true, reason: '$type 应可选');
          expect(decision.reasonCode, isNull, reason: '$type 可选时无 reason');
        }
      },
    );

    test("audio 是 voice 的协议别称，同样可选（normalizer audio→voice）", () {
      final decision = evaluateMessageSelectability(traits(MessageType.audio));
      expect(decision.selectable, true);
      expect(decision.reasonCode, isNull);
    });
  });

  group('状态标志（优先于类型判定）', () {
    test('E2EE 解密失败占位（metadata _e2ee_failed==true）不可选：e2ee_failed', () {
      final decision = evaluateMessageSelectability(
        traits(MessageType.text, e2eeFailed: true),
      );
      expect(decision.selectable, false);
      expect(decision.reasonCode, MessageSelectionReason.e2eeFailed);
    });

    test('E2EE 失败占位优先级最高（同时 sending 也返回 e2ee_failed）', () {
      final decision = evaluateMessageSelectability(
        traits(
          MessageType.text,
          e2eeFailed: true,
          status: MessageStatus.sending,
        ),
      );
      expect(decision.reasonCode, MessageSelectionReason.e2eeFailed);
    });

    test('发送中（status=sending）不可选：status_sending', () {
      final decision = evaluateMessageSelectability(
        traits(MessageType.text, status: MessageStatus.sending),
      );
      expect(decision.selectable, false);
      expect(decision.reasonCode, MessageSelectionReason.statusSending);
    });

    test('发送失败（status=error）不可选：status_failed', () {
      final decision = evaluateMessageSelectability(
        traits(MessageType.image, status: MessageStatus.error),
      );
      expect(decision.selectable, false);
      expect(decision.reasonCode, MessageSelectionReason.statusFailed);
    });

    test('已撤回（status=revoked）不可选：revoked（正文已不可转发）', () {
      final decision = evaluateMessageSelectability(
        traits(MessageType.text, status: MessageStatus.revoked),
      );
      expect(decision.selectable, false);
      expect(decision.reasonCode, MessageSelectionReason.revoked);
    });

    test('完成态 sent/delivered/seen 均可选', () {
      for (final status in [
        MessageStatus.sent,
        MessageStatus.delivered,
        MessageStatus.seen,
      ]) {
        final decision = evaluateMessageSelectability(
          traits(MessageType.text, status: status),
        );
        expect(decision.selectable, true, reason: '$status 完成态应可选');
      }
    });

    test('阅后即焚（burn_read_at>0）不可选：burn_after_read', () {
      final decision = evaluateMessageSelectability(
        traits(MessageType.text, burnReadAt: 1710000000000),
      );
      expect(decision.selectable, false);
      expect(decision.reasonCode, MessageSelectionReason.burnAfterRead);
    });

    test('burn_read_at<=0 不影响可选性', () {
      for (final burn in [0, -1]) {
        final decision = evaluateMessageSelectability(
          traits(MessageType.text, burnReadAt: burn),
        );
        expect(decision.selectable, true, reason: 'burn_read_at=$burn 应可选');
      }
    });

    test('状态/焚毁标志优先于类型（sending 的 redPacket 报 status_sending）', () {
      final decision = evaluateMessageSelectability(
        traits(MessageType.redPacket, status: MessageStatus.sending),
      );
      expect(decision.reasonCode, MessageSelectionReason.statusSending);
    });
  });

  group('不可选类型（§4.4 默认不可选集合）', () {
    test('WebRTC 音频/视频信令不可选：webrtc_call', () {
      for (final type in [MessageType.webrtcAudio, MessageType.webrtcVideo]) {
        final decision = evaluateMessageSelectability(traits(type));
        expect(decision.selectable, false, reason: '$type 不可选');
        expect(decision.reasonCode, MessageSelectionReason.webrtcCall);
      }
    });

    test('红包/转账不可选：payment_message', () {
      for (final type in [MessageType.redPacket, MessageType.transfer]) {
        final decision = evaluateMessageSelectability(traits(type));
        expect(decision.selectable, false, reason: '$type 不可选');
        expect(decision.reasonCode, MessageSelectionReason.paymentMessage);
      }
    });

    test('业务卡片 v1 不承诺批量，不可选：business_card', () {
      const cards = <String>[
        MessageType.businessActionCard,
        MessageType.linkCard,
        MessageType.channelCard,
        MessageType.legacyChannelMessage,
        MessageType.talkRecordCard,
        MessageType.visitCard,
        MessageType.groupSchedule,
        MessageType.groupVote,
        MessageType.groupTask,
        MessageType.groupNotice,
      ];
      for (final type in cards) {
        final decision = evaluateMessageSelectability(traits(type));
        expect(decision.selectable, false, reason: '$type 业务卡片 v1 不可选');
        expect(decision.reasonCode, MessageSelectionReason.businessCard);
      }
    });

    test('textStream（流式分段）/custom/unsupported/null/未知类型：unsupported_type', () {
      const systemish = <String?>[
        MessageType.textStream,
        MessageType.custom,
        MessageType.unsupported,
        null,
        'brand_new_type_from_future',
      ];
      for (final type in systemish) {
        final decision = evaluateMessageSelectability(traits(type));
        expect(decision.selectable, false, reason: '$type 不在白名单');
        expect(decision.reasonCode, MessageSelectionReason.unsupportedType);
      }
    });

    test('S2C 系统/控制 action 行（msg_type 为空）同样 unsupported_type', () {
      final decision = evaluateMessageSelectability(traits(null));
      expect(decision.selectable, false);
      expect(decision.reasonCode, MessageSelectionReason.unsupportedType);
    });
  });

  group('reason code 稳定性（跨版本稳定契约，UI/i18n 映射依赖）', () {
    test('全部 reason code 为 snake_case 字面量', () {
      const codes = <String>[
        MessageSelectionReason.e2eeFailed,
        MessageSelectionReason.statusSending,
        MessageSelectionReason.statusFailed,
        MessageSelectionReason.revoked,
        MessageSelectionReason.burnAfterRead,
        MessageSelectionReason.webrtcCall,
        MessageSelectionReason.paymentMessage,
        MessageSelectionReason.businessCard,
        MessageSelectionReason.unsupportedType,
      ];
      for (final code in codes) {
        expect(
          code,
          matches(r'^[a-z][a-z0-9_]*$'),
          reason: '$code 应为 snake_case',
        );
      }
    });
  });
}
