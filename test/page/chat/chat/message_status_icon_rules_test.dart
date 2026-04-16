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

    test('sent / delivered 结果对称（colorKey 相同）', () {
      final sent = resolveMessageStatusIcon(MessageStatus.sent);
      final delivered = resolveMessageStatusIcon(MessageStatus.delivered);
      expect(sent.iconData, delivered.iconData);
      expect(sent.colorKey, delivered.colorKey);
    });
  });
}
