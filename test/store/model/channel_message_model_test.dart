/// ChannelMessageModel 解析、持久化、预览、副本语义契约测试（CM-1 ~ CM-4）
///
/// CM-1  ChannelMessageModel.fromJson 字段映射
/// CM-2  ChannelMessageModel.fromMap / toMap SQLite 往返
/// CM-3  contentPreview getter — 全 8 分支 + 截断
/// CM-4  copyWith / == / hashCode 语义
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_message_model.dart';

// ─── 测试工厂 ───────────────────────────────────────────────────────────────

ChannelMessageModel _msg({
  int id = 1,
  int channelId = 10,
  String content = 'hello',
  String msgType = 'channel_text',
  Map<String, dynamic>? payload,
  bool isPinned = false,
  int viewCount = 0,
  Map<String, int>? reactionSummary,
  DateTime? createdAt,
}) {
  return ChannelMessageModel(
    id: id,
    channelId: channelId,
    content: content,
    msgType: msgType,
    payload: payload,
    isPinned: isPinned,
    viewCount: viewCount,
    reactionSummary: reactionSummary,
    createdAt: createdAt ?? DateTime.utc(2025, 1, 1),
  );
}

void main() {
  // ── CM-1  fromJson ─────────────────────────────────────────────────────────
  group('CM-1 ChannelMessageModel.fromJson', () {
    final baseMs = 1_750_000_000_000;

    test('标准字段映射', () {
      final model = ChannelMessageModel.fromJson({
        'id': 42,
        'channel_id': 7,
        'author_id': 100,
        'author_name': 'Alice',
        'author_avatar': 'https://example.com/a.jpg',
        'content': 'Hello world',
        'msg_type': 'channel_text',
        'payload': {'key': 'val'},
        'created_at': baseMs,
        'is_pinned': 1,
        'view_count': 99,
        'reaction_summary': {'like': 5, 'heart': 2},
      });

      expect(model.id, 42);
      expect(model.channelId, 7);
      expect(model.authorId, 100);
      expect(model.authorName, 'Alice');
      expect(model.authorAvatar, 'https://example.com/a.jpg');
      expect(model.content, 'Hello world');
      expect(model.msgType, 'channel_text');
      expect(model.payload, {'key': 'val'});
      expect(model.createdAt.millisecondsSinceEpoch, baseMs);
      expect(model.isPinned, isTrue);
      expect(model.viewCount, 99);
      expect(model.reactionSummary, {'like': 5, 'heart': 2});
    });

    test('nullable 字段缺失时为 null', () {
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
      });

      expect(model.authorId, isNull);
      expect(model.authorName, isNull);
      expect(model.authorAvatar, isNull);
      expect(model.payload, isNull);
      expect(model.reactionSummary, isNull);
    });

    test('msg_type 缺失时默认 channel_text', () {
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
      });
      expect(model.msgType, 'channel_text');
    });

    test('is_pinned 0 → false', () {
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
        'is_pinned': 0,
      });
      expect(model.isPinned, isFalse);
    });

    test('reaction_summary 为 JSON 字符串时正确解析', () {
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
        'reaction_summary': jsonEncode({'fire': 3}),
      });
      expect(model.reactionSummary, {'fire': 3});
    });

    test('reaction_summary 为空字符串时为 null', () {
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
        'reaction_summary': '',
      });
      expect(model.reactionSummary, isNull);
    });

    test('reaction_summary 为无效 JSON 时为 null', () {
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
        'reaction_summary': '{not-json',
      });
      expect(model.reactionSummary, isNull);
    });

    test('created_at 秒级时间戳自动放大为毫秒', () {
      // parseModelDateTime: abs < 1e12 → ×1000
      const secTs = 1_750_000_000; // 秒级
      final model = ChannelMessageModel.fromJson({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': secTs,
      });
      expect(
        model.createdAt.millisecondsSinceEpoch,
        secTs * 1000,
      );
    });

    test('字符串数字兼容（parseModelInt）', () {
      final model = ChannelMessageModel.fromJson({
        'id': '5',
        'channel_id': '3',
        'content': 'x',
        'created_at': baseMs,
        'view_count': '77',
      });
      expect(model.id, 5);
      expect(model.channelId, 3);
      expect(model.viewCount, 77);
    });
  });

  // ── CM-2  fromMap / toMap ──────────────────────────────────────────────────
  group('CM-2 ChannelMessageModel.fromMap / toMap', () {
    final baseMs = 1_750_000_000_000;

    test('toMap → fromMap 可重建（payload 经 JSON 字符串往返）', () {
      final original = _msg(
        id: 99,
        channelId: 8,
        content: 'round-trip',
        msgType: 'channel_text',
        payload: {'text': 'hi', 'count': 3},
        isPinned: true,
        viewCount: 42,
        reactionSummary: {'like': 1},
        createdAt: DateTime.fromMillisecondsSinceEpoch(baseMs),
      );

      final map = original.toMap();
      final rebuilt = ChannelMessageModel.fromMap(map);

      expect(rebuilt.id, original.id);
      expect(rebuilt.channelId, original.channelId);
      expect(rebuilt.content, original.content);
      expect(rebuilt.msgType, original.msgType);
      expect(rebuilt.payload, original.payload);
      expect(rebuilt.isPinned, original.isPinned);
      expect(rebuilt.viewCount, original.viewCount);
      expect(rebuilt.reactionSummary, original.reactionSummary);
      expect(
        rebuilt.createdAt.millisecondsSinceEpoch,
        original.createdAt.millisecondsSinceEpoch,
      );
    });

    test('toMap — is_pinned 编码为 0/1', () {
      expect(_msg(isPinned: true).toMap()['is_pinned'], 1);
      expect(_msg(isPinned: false).toMap()['is_pinned'], 0);
    });

    test('toMap — payload 编码为 JSON 字符串', () {
      final map = _msg(payload: {'k': 'v'}).toMap();
      expect(map['payload'], isA<String>());
      expect(jsonDecode(map['payload'] as String), {'k': 'v'});
    });

    test('toMap — reaction_summary 编码为 JSON 字符串', () {
      final map = _msg(reactionSummary: {'like': 2}).toMap();
      expect(map['reaction_summary'], isA<String>());
      expect(jsonDecode(map['reaction_summary'] as String), {'like': 2});
    });

    test('toMap — null payload / reactionSummary → null', () {
      final map = _msg().toMap();
      expect(map['payload'], isNull);
      expect(map['reaction_summary'], isNull);
    });

    test('fromMap — payload 为 JSON 字符串时正确解析', () {
      final model = ChannelMessageModel.fromMap({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'msg_type': 'channel_text',
        'created_at': baseMs,
        'payload': jsonEncode({'url': 'http://img.png'}),
      });
      expect(model.payload, {'url': 'http://img.png'});
    });

    test('fromMap — nullable 字段为 null 时正确降级', () {
      final model = ChannelMessageModel.fromMap({
        'id': 1,
        'channel_id': 1,
        'content': 'x',
        'created_at': baseMs,
      });
      expect(model.authorId, isNull);
      expect(model.authorName, isNull);
      expect(model.payload, isNull);
      expect(model.reactionSummary, isNull);
    });
  });

  // ── CM-3  contentPreview ───────────────────────────────────────────────────
  group('CM-3 contentPreview getter', () {
    test('channel_text — ≤50 字符 → 原样返回', () {
      final msg = _msg(content: 'Short text', msgType: 'channel_text');
      expect(msg.contentPreview, 'Short text');
    });

    test('channel_text — >50 字符 → 截断 + ...', () {
      final longText = 'A' * 51;
      final msg = _msg(content: longText, msgType: 'channel_text');
      expect(msg.contentPreview, '${'A' * 50}...');
    });

    test('channel_text — 恰好 50 字符 → 不截断', () {
      final exactly50 = 'B' * 50;
      final msg = _msg(content: exactly50, msgType: 'channel_text');
      expect(msg.contentPreview, exactly50);
    });

    test('channel_image → [图片]', () {
      expect(_msg(msgType: 'channel_image').contentPreview, '[图片]');
    });

    test('channel_video → [视频]', () {
      expect(_msg(msgType: 'channel_video').contentPreview, '[视频]');
    });

    test('channel_audio → [语音]', () {
      expect(_msg(msgType: 'channel_audio').contentPreview, '[语音]');
    });

    test('channel_file → [文件]', () {
      expect(_msg(msgType: 'channel_file').contentPreview, '[文件]');
    });

    test('channel_link → [链接]', () {
      expect(_msg(msgType: 'channel_link').contentPreview, '[链接]');
    });

    test('channel_location → [位置]', () {
      expect(_msg(msgType: 'channel_location').contentPreview, '[位置]');
    });

    test('未知类型 + payload[text] 短文本 → 文本原样', () {
      final msg = _msg(
        msgType: 'channel_unknown',
        payload: {'text': 'custom preview'},
      );
      expect(msg.contentPreview, 'custom preview');
    });

    test('未知类型 + payload[text] >50 字符 → 截断', () {
      final longText = 'Z' * 60;
      final msg = _msg(
        msgType: 'channel_unknown',
        payload: {'text': longText},
      );
      expect(msg.contentPreview, '${'Z' * 50}...');
    });

    test('未知类型 + 无 payload → [消息]', () {
      expect(_msg(msgType: 'channel_unknown').contentPreview, '[消息]');
    });

    test('未知类型 + payload 无 text 字段 → [消息]', () {
      final msg = _msg(
        msgType: 'channel_unknown',
        payload: {'url': 'https://img.png'},
      );
      expect(msg.contentPreview, '[消息]');
    });
  });

  // ── CM-4  copyWith / == / hashCode ────────────────────────────────────────
  group('CM-4 copyWith / == / hashCode', () {
    test('copyWith — 不传参数时返回等价副本', () {
      final original = _msg(id: 10, content: 'hi', viewCount: 5);
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.content, original.content);
      expect(copy.viewCount, original.viewCount);
    });

    test('copyWith — 覆盖指定字段', () {
      final original = _msg(id: 10, content: 'old', isPinned: false);
      final updated = original.copyWith(content: 'new', isPinned: true);

      expect(updated.id, 10);
      expect(updated.content, 'new');
      expect(updated.isPinned, isTrue);
    });

    test('copyWith — 未覆盖的字段保持不变', () {
      final original = _msg(id: 10, channelId: 99, viewCount: 7);
      final copy = original.copyWith(content: 'changed');

      expect(copy.channelId, 99);
      expect(copy.viewCount, 7);
    });

    test('== — 同 id 则相等（其他字段不影响）', () {
      final a = _msg(id: 5, content: 'alpha');
      final b = _msg(id: 5, content: 'beta', viewCount: 100);
      expect(a == b, isTrue);
    });

    test('== — 不同 id 则不相等', () {
      final a = _msg(id: 1);
      final b = _msg(id: 2);
      expect(a == b, isFalse);
    });

    test('hashCode — 同 id 时相同', () {
      final a = _msg(id: 7, content: 'x');
      final b = _msg(id: 7, content: 'y');
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode — 等于 id.hashCode', () {
      final msg = _msg(id: 42);
      expect(msg.hashCode, 42.hashCode);
    });
  });
}
