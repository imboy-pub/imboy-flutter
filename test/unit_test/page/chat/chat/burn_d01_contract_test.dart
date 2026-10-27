/// D01 冻结合同（IMBoy_Timezone_Decisions_V1，2026-10-27）显示层契约测试。
///
/// 合同来源：_task_packages/IMBoy_Timezone_Decisions_V1/state.json decisions.D01
/// ——服务端发送后 TTL 为唯一服务端权威；FL 保留显示层语义：
///   R05F-1 接收方未读不销毁 / 已读起算（payload.burn_read_at）/
///         发送方自己的消息从发送时间起算（fallbackStartMs=createdAt）/
///         非阅后即焚消息不受影响；
///   R05F-2 burn_read_at 是接收端本地显示字段，永不进入发送 payload
///         （withBurnMetadata 不生成；getMsgFromTMsg 各类型分支剥离）。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/page/chat/chat/utils/chat_page_utils.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/store/model/user_collect_model.dart';

void main() {
  const svc = ChatBurnService();
  const nowMs = 1789600000000;
  const burnAfterMs = 30000;

  group('R05F-1 显示层语义（D01 冻结合同）', () {
    test('接收方未读（无 burn_read_at 且不传 fallback）永不销毁', () {
      final payload = {
        'burn': true,
        'burn_after_ms': burnAfterMs,
        'expire_secs': 30,
      };
      expect(
        svc.isBurnExpired(payload, nowMs + burnAfterMs * 10),
        isFalse,
        reason: '未读不销毁是 D01 显示层合同；服务端层权威不依赖本字段',
      );
    });

    test('接收方已读起算：burn_read_at + burn_after_ms 到期即销毁', () {
      final readAt = nowMs;
      final payload = {
        'burn': true,
        'burn_after_ms': burnAfterMs,
        'burn_read_at': readAt,
      };
      expect(svc.isBurnExpired(payload, readAt + burnAfterMs), isTrue);
      expect(svc.isBurnExpired(payload, readAt + burnAfterMs - 1), isFalse);
    });

    test('发送方自己的消息从发送时间起算（fallbackStartMs=createdAt）', () {
      final sentAt = nowMs;
      final payload = {'burn': true, 'burn_after_ms': burnAfterMs};
      // 发送方消息：无 burn_read_at（合同禁止写入），传 fallback
      expect(
        svc.isBurnExpired(
          payload,
          sentAt + burnAfterMs,
          fallbackStartMs: sentAt,
        ),
        isTrue,
      );
      expect(
        svc.isBurnExpired(
          payload,
          sentAt + burnAfterMs - 1,
          fallbackStartMs: sentAt,
        ),
        isFalse,
      );
    });

    test('倒计时起点解析：read_at 优先于 fallback；<=0 表示无起点', () {
      expect(
        ChatBurnService.burnCountdownStartMs({'burn_read_at': nowMs}, 1),
        nowMs,
      );
      expect(ChatBurnService.burnCountdownStartMs({}, 0), 0);
    });

    test('非阅后即焚消息不受影响（无 burn 标志 → 永不过期）', () {
      expect(
        svc.isBurnExpired({'text': 'hi'}, nowMs * 2, fallbackStartMs: 1),
        isFalse,
      );
    });

    test('burn_after_ms 缺失/非法（<=0）→ 不销毁（不伪造时长）', () {
      expect(
        svc.isBurnExpired({'burn': true}, nowMs * 2, fallbackStartMs: 1),
        isFalse,
      );
    });
  });

  group('R05F-2 burn_read_at 永不进入发送 payload（D01 冻结合同）', () {
    test('withBurnMetadata 只生成 burn/burn_after_ms/expire_secs 三键', () {
      final meta = ChatPageUtils.withBurnMetadata(
        base: const {},
        burnEnabled: true,
        burnAfterMs: burnAfterMs,
      );
      expect(meta.keys.toSet(), {'burn', 'burn_after_ms', 'expire_secs'});
      expect(meta.containsKey('burn_read_at'), isFalse);
    });

    test('withBurnMetadata 关闭时不注入任何 burn 键', () {
      final meta = ChatPageUtils.withBurnMetadata(
        base: const {},
        burnEnabled: false,
        burnAfterMs: burnAfterMs,
      );
      expect(meta.isEmpty, isTrue);
    });

    test('getMsgFromTMsg：TextMessage 路径剥离 burn_read_at（含重发场景）', () {
      // 本地已读行重发：metadata 带本地 burn_read_at，出站必须剥离
      final model = ChatNetworkService().getMsgFromTMsg(
        'C2C',
        'uk3',
        TextMessage(
          authorId: 'u_me',
          createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          id: 'm-d01',
          text: 'hi',
          metadata: {
            'burn': true,
            'burn_after_ms': burnAfterMs,
            'burn_read_at': nowMs + 1000,
            'peer_id': '42',
          },
        ),
      );
      final payload = model.payload as Map<String, dynamic>;
      expect(
        payload.containsKey('burn_read_at'),
        isFalse,
        reason: '发送 payload 带 burn_read_at 会让对端提前开烧（合同 R05F-2）',
      );
      expect(payload['burn'], isTrue);
      expect(payload['peer_id'], '42');
    });

    test('getMsgFromTMsg：CustomMessage 路径剥离 burn_read_at', () {
      final model = ChatNetworkService().getMsgFromTMsg(
        'C2C',
        'uk3',
        CustomMessage(
          authorId: 'u_me',
          createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          id: 'm-d01-c',
          metadata: {
            'msg_type': 'location',
            'title': 'x',
            'burn': true,
            'burn_after_ms': burnAfterMs,
            'burn_read_at': nowMs + 1000,
          },
        ),
      );
      final payload = model.payload as Map<String, dynamic>;
      expect(payload.containsKey('burn_read_at'), isFalse);
      expect(payload['title'], 'x');
      expect(
        payload.containsKey('msg_type'),
        isFalse,
        reason: '既有剥离键回归（msg_type 提顶层）',
      );
    });

    test('getMsgFromTMsg：SystemMessage 路径剥离 burn_read_at', () {
      final model = ChatNetworkService().getMsgFromTMsg(
        'C2C',
        'uk3',
        SystemMessage(
          authorId: 'u_me',
          createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          id: 'm-d01-s',
          text: 'sys',
          metadata: {
            'burn': true,
            'burn_after_ms': burnAfterMs,
            'burn_read_at': nowMs + 1000,
          },
        ),
      );
      final payload = model.payload as Map<String, dynamic>;
      expect(payload.containsKey('burn_read_at'), isFalse);
    });
  });

  group('R05F-2 转发与收藏再发链路剥离（P1-1 补面）', () {
    test('转发 payload 剥离 burn_read_at（buildForwardPayload）', () {
      final payload = SendToNotifier.buildForwardPayload(
        sourceMetadata: {
          'msg_type': 'text',
          'burn': true,
          'burn_after_ms': burnAfterMs,
          // 本地 DB 残留的接收方已读时刻（chat_burn_service 写入）
          'burn_read_at': nowMs,
        },
        text: 'fw',
        peerId: 42,
        conversationUk3: 'C2C_1_42',
      );
      expect(
        payload.containsKey('burn_read_at'),
        isFalse,
        reason:
            '转发源 metadata 常带接收方已读时刻；不剥离则新接收方副本'
            '以旧已读时刻提前开烧（R05F-2）',
      );
      expect(payload['burn'], isTrue, reason: '内容键不受剥离影响');
      expect(payload['peer_id'], 42, reason: '目标会话绑定不受影响');
      expect(payload['conversation_uk3'], 'C2C_1_42');
    });

    test('收藏再发 payload 剥离 burn_read_at（collectOutboundPayload）', () {
      final payload = ChatAttachmentHandler.collectOutboundPayload(
        UserCollectModel(
          userId: 50,
          kind: 6,
          kindId: 'c-burn',
          source: '',
          remark: '',
          tag: '',
          updatedAt: 0,
          createdAt: 0,
          info: {
            'payload': {
              'msg_type': 'location',
              'title': 'x',
              'burn': true,
              'burn_after_ms': burnAfterMs,
              'burn_read_at': nowMs,
            },
          },
        ),
        targetPeerId: '777',
      );
      expect(
        payload.containsKey('burn_read_at'),
        isFalse,
        reason: '收藏源数据可能带旧已读时刻；再发副本不得以它起算（R05F-2）',
      );
      expect(payload['title'], 'x', reason: '收藏内容不受剥离影响');
      expect(payload['peer_id'], '777', reason: '目标会话绑定不受影响');
    });
  });
}
