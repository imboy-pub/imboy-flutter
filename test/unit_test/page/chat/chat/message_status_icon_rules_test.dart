/// Characterization tests for [resolveMessageStatusIcon].
///
/// slice-C-11: `chat_page.dart` L1966-1998 内联的 MessageStatus switch
/// 依赖 MessageStatus 枚举返回 iconData + colorKey，
/// 零 Widget 依赖（颜色解析留给调用方），可独立单测钉死所有分支契约。
///
/// 契约（钉死）：
///   - sending  → (Icons.access_time,  'textSecondary')
///   - sent     → (Icons.done_all,     'primary')
///   - delivered → (Icons.done_all,    'primary')
///   - seen     → (Icons.done_all,     'sendMessageBg')
///   - error    → (Icons.error_outline,'error')
///   - null     → (null, null)
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/message_status_icon_rules.dart';

void main() {
  group('resolveMessageStatusIcon', () {
    test('sending → access_time / textSecondary', () {
      final r = resolveMessageStatusIcon(MessageStatus.sending);
      expect(r.iconData, Icons.access_time);
      expect(r.colorKey, 'textSecondary');
    });

    test('sent → done_all / primary', () {
      final r = resolveMessageStatusIcon(MessageStatus.sent);
      expect(r.iconData, Icons.done_all);
      expect(r.colorKey, 'primary');
    });

    test('delivered → done_all / primary（与 sent 同图标）', () {
      final r = resolveMessageStatusIcon(MessageStatus.delivered);
      expect(r.iconData, Icons.done_all);
      expect(r.colorKey, 'primary');
    });

    test('seen → done_all / sendMessageBg', () {
      final r = resolveMessageStatusIcon(MessageStatus.seen);
      expect(r.iconData, Icons.done_all);
      expect(r.colorKey, 'sendMessageBg');
    });

    test('error → error_outline / error', () {
      final r = resolveMessageStatusIcon(MessageStatus.error);
      expect(r.iconData, Icons.error_outline);
      expect(r.colorKey, 'error');
    });

    test('null → iconData null / colorKey null（不显示图标）', () {
      final r = resolveMessageStatusIcon(null);
      expect(r.iconData, isNull);
      expect(r.colorKey, isNull);
    });

    test('sent / delivered 图标同形，但读屏标签必须可区分', () {
      final sent = resolveMessageStatusIcon(MessageStatus.sent);
      final delivered = resolveMessageStatusIcon(MessageStatus.delivered);
      expect(sent.iconData, delivered.iconData);
      expect(sent.colorKey, delivered.colorKey);
      expect(sent.semanticLabel, isNot(delivered.semanticLabel));
    });

    test('每个可见状态都有非空读屏标签（a11y 契约）', () {
      const visible = [
        MessageStatus.sending,
        MessageStatus.sent,
        MessageStatus.delivered,
        MessageStatus.seen,
        MessageStatus.error,
      ];
      final labels = <String>{};
      for (final s in visible) {
        final label = resolveMessageStatusIcon(s).semanticLabel;
        expect(label, isNotNull, reason: '$s 缺读屏标签');
        expect(label, isNotEmpty, reason: '$s 读屏标签为空串');
        labels.add(label!);
      }
      // 五态标签互不相同，否则读屏用户仍分不清
      expect(labels.length, visible.length);
    });

    test('无图标状态不带读屏标签', () {
      expect(resolveMessageStatusIcon(null).semanticLabel, isNull);
    });
  });
}
