/// Slice A-1: 钉住 MomentNotifyModel 的解析契约（零外部依赖，可脱离
/// sqflite / win32 插件链单测）。
///
/// 背景：朋友圈通知中心持久化需求源于后端现状 ——
///   - `moment_logic_notify:notify_post_liked/3`   → 模式 `no_save`
///     （点赞只走 S2C 实时推送，后端 s2c_message 表不落库）
///   - `moment_logic_notify:notify_post_commented/4` → 模式 `save`
/// 若完全依赖后端历史回放，点赞通知在重连 / 冷启动时会彻底丢失。
/// 因此客户端必须**本地落库**点赞 + 评论两类通知，才能做通知中心红点与历史列表。
///
/// 设计要点：
///   1. 只接受 `moment_like` / `moment_comment` 两类 action；
///      `moment_new` / `moment_deleted` 属于 timeline 信号（由 event bus
///      广播给朋友圈列表 Notifier 即可），不进通知中心表。
///   2. 返回 sealed `MomentNotifyParseResult`：
///      - `MomentNotifyParseOk(model)`   解析成功
///      - `MomentNotifyParseSkipSelf()`  自赞/自评（防御，后端已过滤）
///      - `MomentNotifyParseInvalid(r)`  非法 payload（带原因）
///   3. id / comment_id / from_uid 接受 int / String 混入（TSID 跨端字符串化）；
///      空白、null、'0' 等空值归一化为空串。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/moment_notify_model.dart';

void main() {
  const nowMs = 1_700_000_000_000; // 2023-11-14T22:13:20Z

  group('MomentNotifyModel.fromS2CPayload — action 白名单', () {
    test('moment_like 合法 payload → ParseOk', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{
          'moment_id': '1838294017982464',
          'from_uid': '1838294017982465',
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseOk>());
      final ok = result as MomentNotifyParseOk;
      expect(ok.model.action, 'moment_like');
      expect(ok.model.momentId, '1838294017982464');
      expect(ok.model.fromUid, '1838294017982465');
      expect(ok.model.userId, '1000');
      expect(ok.model.commentId, isNull);
      expect(ok.model.isRead, isFalse);
      expect(ok.model.createdAt, nowMs);
    });

    test('moment_comment 合法 payload（含 comment_id）→ ParseOk', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_comment',
        payload: <String, dynamic>{
          'moment_id': '111',
          'from_uid': '222',
          'comment_id': '333',
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseOk>());
      final ok = result as MomentNotifyParseOk;
      expect(ok.model.action, 'moment_comment');
      expect(ok.model.commentId, '333');
    });

    test('moment_new → ParseInvalid(invalid_action)（不进通知中心）', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_new',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseInvalid>());
      expect(
        (result as MomentNotifyParseInvalid).reason,
        'invalid_action',
      );
    });

    test('moment_deleted → ParseInvalid(invalid_action)', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_deleted',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseInvalid>());
    });

    test('空 action → ParseInvalid(invalid_action)', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: '',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseInvalid>());
    });

    test('未知 action → ParseInvalid(invalid_action)', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_share',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseInvalid>());
    });
  });

  group('MomentNotifyModel.fromS2CPayload — 字段归一化', () {
    test('moment_id 为数字 → 自动 toString()（对齐 TSID BIGINT）', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{
          'moment_id': 1838294017982464,
          'from_uid': 1838294017982465,
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseOk>());
      final ok = result as MomentNotifyParseOk;
      expect(ok.model.momentId, '1838294017982464');
      expect(ok.model.fromUid, '1838294017982465');
    });

    test('comment_id 为数字 → toString()', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_comment',
        payload: <String, dynamic>{
          'moment_id': '1',
          'from_uid': '2',
          'comment_id': 333,
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      final ok = result as MomentNotifyParseOk;
      expect(ok.model.commentId, '333');
    });

    test('moment_like 忽略 comment_id（即使后端误发也不污染）', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{
          'moment_id': '1',
          'from_uid': '2',
          'comment_id': '999',
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      final ok = result as MomentNotifyParseOk;
      expect(ok.model.commentId, isNull);
    });

    test('moment_comment 缺失 comment_id → 允许 null（非强制）', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_comment',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseOk>());
      expect((result as MomentNotifyParseOk).model.commentId, isNull);
    });
  });

  group('MomentNotifyModel.fromS2CPayload — 必填字段校验', () {
    test('moment_id 缺失 → ParseInvalid(missing_moment_id)', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseInvalid>());
      expect(
        (result as MomentNotifyParseInvalid).reason,
        'missing_moment_id',
      );
    });

    test('moment_id 为空串 → ParseInvalid', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'moment_id': '', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(
        (result as MomentNotifyParseInvalid).reason,
        'missing_moment_id',
      );
    });

    test('moment_id 为 0 / "0" → ParseInvalid（防 TSID 无效值）', () {
      final r1 = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'moment_id': 0, 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );
      final r2 = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'moment_id': '0', 'from_uid': '2'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect((r1 as MomentNotifyParseInvalid).reason, 'missing_moment_id');
      expect((r2 as MomentNotifyParseInvalid).reason, 'missing_moment_id');
    });

    test('from_uid 缺失 → ParseInvalid(missing_from_uid)', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'moment_id': '1'},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(
        (result as MomentNotifyParseInvalid).reason,
        'missing_from_uid',
      );
    });

    test('from_uid 空白 → ParseInvalid', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '   '},
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(
        (result as MomentNotifyParseInvalid).reason,
        'missing_from_uid',
      );
    });

    test('currentUid 为空 → ParseInvalid(missing_current_uid)', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{'moment_id': '1', 'from_uid': '2'},
        currentUid: '',
        nowMs: nowMs,
      );

      expect(
        (result as MomentNotifyParseInvalid).reason,
        'missing_current_uid',
      );
    });
  });

  group('MomentNotifyModel.fromS2CPayload — 自赞/自评过滤', () {
    test('from_uid == currentUid → ParseSkipSelf', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_like',
        payload: <String, dynamic>{
          'moment_id': '1',
          'from_uid': '1000',
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseSkipSelf>());
    });

    test('from_uid 数字等同 currentUid 字符串 → ParseSkipSelf', () {
      final result = MomentNotifyModel.fromS2CPayload(
        action: 'moment_comment',
        payload: <String, dynamic>{
          'moment_id': '1',
          'from_uid': 1000,
        },
        currentUid: '1000',
        nowMs: nowMs,
      );

      expect(result, isA<MomentNotifyParseSkipSelf>());
    });
  });

  group('MomentNotifyModel 序列化', () {
    test('toInsertMap → fromRow 往返一致', () {
      const original = MomentNotifyModel(
        userId: '1000',
        action: 'moment_comment',
        momentId: '111',
        fromUid: '222',
        commentId: '333',
        isRead: false,
        createdAt: nowMs,
      );

      final map = original.toInsertMap();
      // id 由 SQLite 自增，insert map 不应带上
      expect(map.containsKey('id'), isFalse);
      expect(map['user_id'], '1000');
      expect(map['action'], 'moment_comment');
      expect(map['moment_id'], '111');
      expect(map['from_uid'], '222');
      expect(map['comment_id'], '333');
      expect(map['is_read'], 0);
      expect(map['created_at'], nowMs);

      // 模拟 SQLite 读回（带 id + is_read=0）
      final row = <String, dynamic>{
        'id': 42,
        ...map,
      };
      final roundTrip = MomentNotifyModel.fromRow(row);
      expect(roundTrip.id, 42);
      expect(roundTrip.userId, original.userId);
      expect(roundTrip.action, original.action);
      expect(roundTrip.momentId, original.momentId);
      expect(roundTrip.fromUid, original.fromUid);
      expect(roundTrip.commentId, original.commentId);
      expect(roundTrip.isRead, original.isRead);
      expect(roundTrip.createdAt, original.createdAt);
    });

    test('fromRow：is_read=1 → bool true', () {
      final row = <String, dynamic>{
        'id': 1,
        'user_id': '1000',
        'action': 'moment_like',
        'moment_id': '1',
        'from_uid': '2',
        'comment_id': null,
        'is_read': 1,
        'created_at': nowMs,
      };

      expect(MomentNotifyModel.fromRow(row).isRead, isTrue);
    });

    test('copyWith(isRead: true) 生成新实例，原实例不变', () {
      const original = MomentNotifyModel(
        id: 1,
        userId: '1000',
        action: 'moment_like',
        momentId: '1',
        fromUid: '2',
        createdAt: nowMs,
      );

      final marked = original.copyWith(isRead: true);

      expect(marked.isRead, isTrue);
      expect(original.isRead, isFalse);
      expect(marked.id, 1);
      expect(marked.momentId, '1');
    });
  });
}
