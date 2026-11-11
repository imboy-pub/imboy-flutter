/// W1-C 导出类型准入验收测试：允许/拒绝类型矩阵全量钉死 + reason code
/// 稳定性 + 多重命中优先级。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

ChatExportEntry _entry(
  String type, {
  MessageStatus status = MessageStatus.sent,
  bool e2eeFailed = false,
  bool burn = false,
}) {
  return ChatExportEntry(
    msgType: type,
    senderName: '测试者',
    createdAt: DateTime(2026, 11, 11, 10, 0, 0),
    status: status,
    text: '正文',
    e2eeFailedPlaceholder: e2eeFailed,
    burnAfterRead: burn,
  );
}

void main() {
  final t = DateTime(2026, 11, 11, 10, 0, 0);

  test('reason code 常量稳定（机器契约，禁止改动）', () {
    expect(ChatExportAdmission.ok.reasonCode, 'ok');
    expect(
      ChatExportAdmission.rejectedSystemOrControl.reasonCode,
      'rejected_system_or_control',
    );
    expect(ChatExportAdmission.rejectedWebrtc.reasonCode, 'rejected_webrtc');
    expect(
      ChatExportAdmission.rejectedE2eeFailed.reasonCode,
      'rejected_e2ee_failed',
    );
    expect(
      ChatExportAdmission.rejectedStatusSending.reasonCode,
      'rejected_status_sending',
    );
    expect(
      ChatExportAdmission.rejectedStatusFailed.reasonCode,
      'rejected_status_failed',
    );
    expect(
      ChatExportAdmission.rejectedBurnAfterRead.reasonCode,
      'rejected_burn_after_read',
    );
    expect(ChatExportAdmission.rejectedPayment.reasonCode, 'rejected_payment');
    expect(
      ChatExportAdmission.rejectedRealtimeAclCard.reasonCode,
      'rejected_realtime_acl_card',
    );
  });

  test('允许矩阵：text/textStream/媒体/quote/其余用户类型 → ok', () {
    const allowed = <String>[
      MessageType.text,
      MessageType.textStream,
      MessageType.image,
      MessageType.imageMulti,
      MessageType.voice,
      MessageType.audio, // 协议别称 → voice
      MessageType.video,
      MessageType.file,
      MessageType.location,
      MessageType.expression,
      MessageType.quote,
      MessageType.visitCard,
      MessageType.channelCard,
      MessageType.legacyChannelMessage, // 历史别称 → channel_card
      MessageType.talkRecordCard,
      MessageType.linkCard,
      MessageType.groupSchedule,
      MessageType.groupVote,
      MessageType.groupTask,
      MessageType.groupNotice,
      MessageType.custom,
      MessageType.unsupported, // 脏值：按描述导出（无内容时占位）
      'future_unknown_type', // 未知新类型：按描述导出
    ];
    for (final type in allowed) {
      final r = evaluateChatExportAdmission(_entry(type));
      expect(r.allowed, isTrue, reason: '类型 $type 应允许导出');
      expect(r.reasonCode, 'ok', reason: '类型 $type reason code 应为 ok');
    }
  });

  test('拒绝矩阵：系统/控制（含 revoked/下划线脏值）→ rejected_system_or_control', () {
    const systemTypes = <String>{
      C2SAction.messageRead,
      C2SAction.messageRevoke,
      C2SAction.messageEdit,
      C2SAction.messageInput,
      C2SAction.e2eeRoomKey,
      C2SAction.messageReaction,
      S2CAction.pullOfflineMsg,
      S2CAction.c2cRevoke,
      S2CAction.c2gDelEveryone,
      S2CAction.groupMemberJoin,
      S2CAction.groupDissolve,
      S2CAction.groupMemberLeave,
      S2CAction.groupMemberAlias,
      S2CAction.applyFriend,
      S2CAction.userCancel,
      S2CAction.inDenylist,
      S2CAction.online,
      S2CAction.offline,
      S2CAction.loggedAnotherDevice,
      S2CAction.deviceForceOffline,
      S2CAction.appUpgrade,
      S2CAction.momentNew,
      S2CAction.momentDeleted,
      'revoked',
    };
    for (final type in systemTypes) {
      final r = evaluateChatExportAdmission(_entry(type));
      expect(r.allowed, isFalse, reason: '系统类型 $type 应拒绝');
      expect(
        r.reasonCode,
        'rejected_system_or_control',
        reason: '系统类型 $type reason code 错误',
      );
    }
  });

  test('拒绝矩阵：WebRTC / 红包 / 转账 / 实时 ACL 卡', () {
    expect(
      evaluateChatExportAdmission(_entry(MessageType.webrtcAudio)).reasonCode,
      'rejected_webrtc',
    );
    expect(
      evaluateChatExportAdmission(_entry(MessageType.webrtcVideo)).reasonCode,
      'rejected_webrtc',
    );
    // 历史下划线脏值同样拒绝
    expect(
      evaluateChatExportAdmission(_entry('webrtc_audio')).reasonCode,
      'rejected_webrtc',
    );
    expect(
      evaluateChatExportAdmission(_entry('webrtc_video')).reasonCode,
      'rejected_webrtc',
    );
    expect(
      evaluateChatExportAdmission(_entry(MessageType.redPacket)).reasonCode,
      'rejected_payment',
    );
    expect(
      evaluateChatExportAdmission(_entry(MessageType.transfer)).reasonCode,
      'rejected_payment',
    );
    expect(
      evaluateChatExportAdmission(_entry(MessageType.businessActionCard))
          .reasonCode,
      'rejected_realtime_acl_card',
    );
  });

  test('拒绝矩阵：状态与标志（E2EE 失败/发送中/失败/阅后即焚）', () {
    expect(
      evaluateChatExportAdmission(_entry(MessageType.text, e2eeFailed: true))
          .reasonCode,
      'rejected_e2ee_failed',
    );
    expect(
      evaluateChatExportAdmission(
        _entry(MessageType.text, status: MessageStatus.sending),
      ).reasonCode,
      'rejected_status_sending',
    );
    expect(
      evaluateChatExportAdmission(
        _entry(MessageType.text, status: MessageStatus.error),
      ).reasonCode,
      'rejected_status_failed',
    );
    expect(
      evaluateChatExportAdmission(_entry(MessageType.text, burn: true))
          .reasonCode,
      'rejected_burn_after_read',
    );
    // delivered / seen / revoked(状态) 中 sent 系可导出；revoked 状态消息
    // 类型侧无内容也走类型桶，此处只验证终态可导出
    expect(
      evaluateChatExportAdmission(
        _entry(MessageType.text, status: MessageStatus.delivered),
      ).allowed,
      isTrue,
    );
    expect(
      evaluateChatExportAdmission(
        _entry(MessageType.text, status: MessageStatus.seen),
      ).allowed,
      isTrue,
    );
  });

  test('多重命中优先级：E2EE失败 > 发送状态 > 阅后即焚 > 类型桶', () {
    // E2EE 失败 + sending + redPacket → e2ee 优先
    expect(
      evaluateChatExportAdmission(
        _entry(
          MessageType.redPacket,
          status: MessageStatus.sending,
          e2eeFailed: true,
        ),
      ).reasonCode,
      'rejected_e2ee_failed',
    );
    // sending + burn + redPacket → 状态优先
    expect(
      evaluateChatExportAdmission(
        _entry(
          MessageType.redPacket,
          status: MessageStatus.sending,
          burn: true,
        ),
      ).reasonCode,
      'rejected_status_sending',
    );
    // burn + redPacket（终态）→ 阅后即焚优先于类型
    expect(
      evaluateChatExportAdmission(_entry(MessageType.redPacket, burn: true))
          .reasonCode,
      'rejected_burn_after_read',
    );
  });

  test('归一化：trim + 协议别称（audio→voice、channel_message→channel_card）', () {
    expect(normalizeChatExportMsgType(' audio '), MessageType.voice);
    expect(
      normalizeChatExportMsgType(MessageType.legacyChannelMessage),
      MessageType.channelCard,
    );
    expect(normalizeChatExportMsgType(' redPacket '), MessageType.redPacket);
    // 归一后保持拒绝语义
    expect(evaluateChatExportAdmission(_entry(' audio ')).reasonCode, 'ok');
    expect(
      evaluateChatExportAdmission(_entry(' redPacket ')).reasonCode,
      'rejected_payment',
    );
  });

  test('时间字段排序比较用 createdAt（防字段误用回归）', () {
    // 仅验证 DTO 携带 createdAt 且为本地 DateTime（契约钉死）
    final e = ChatExportEntry(
      msgType: MessageType.text,
      senderName: 'a',
      createdAt: t,
      status: MessageStatus.sent,
    );
    expect(e.createdAt, t);
    expect(e.createdAt.isUtc, isFalse);
  });
}
