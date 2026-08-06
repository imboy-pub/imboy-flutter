/// 钉住 ChannelUserRole ↔ int 角色码的双向映射。
///
/// 背景：channel_admin_page 添加管理员时硬编 role=0 曾与注释「编辑」
/// 不一致（0 实为 subscriber/none）。该测试把数值语义固定下来，
/// 避免未来误写导致权限赋予失效。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_model.dart';

void main() {
  group('ChannelUserRole role code stability', () {
    test('editor toInt == 1', () {
      expect(ChannelUserRole.editor.toInt(), 1);
    });

    test('admin toInt == 2', () {
      expect(ChannelUserRole.admin.toInt(), 2);
    });

    test('creator toInt == 3', () {
      expect(ChannelUserRole.creator.toInt(), 3);
    });

    test('none/subscriber toInt == 0', () {
      expect(ChannelUserRole.none.toInt(), 0);
      expect(ChannelUserRole.subscriber.toInt(), 0);
    });

    test('fromInt covers every valid code and defaults to none', () {
      expect(ChannelUserRole.fromInt(1), ChannelUserRole.editor);
      expect(ChannelUserRole.fromInt(2), ChannelUserRole.admin);
      expect(ChannelUserRole.fromInt(3), ChannelUserRole.creator);
      expect(ChannelUserRole.fromInt(0), ChannelUserRole.none);
      expect(ChannelUserRole.fromInt(null), ChannelUserRole.none);
      expect(ChannelUserRole.fromInt(999), ChannelUserRole.none);
    });

    test('canPublish only for editor/admin/creator', () {
      expect(ChannelUserRole.editor.canPublish, isTrue);
      expect(ChannelUserRole.admin.canPublish, isTrue);
      expect(ChannelUserRole.creator.canPublish, isTrue);
      expect(ChannelUserRole.none.canPublish, isFalse);
      expect(ChannelUserRole.subscriber.canPublish, isFalse);
    });
  });
}
