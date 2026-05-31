import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// SendToLogic 纯逻辑契约测试（TypeB）
///
/// 仅覆盖不依赖 SQLite 的纯方法：toggleContactSelection / search。
/// conversationsList / sendMsg 依赖 ConversationRepo / MessageRepo（SQLite），
/// 需 FFI 运行时，不在此测。
void main() {
  ConversationModel conv(int id, String title) =>
      ConversationModel.empty().copyWith(id: id, title: title);

  group('SendToLogic.toggleContactSelection', () {
    test('首次添加 → selectedContacts 含该项', () {
      final logic = SendToLogic();
      final c = conv(1, '张三');
      logic.toggleContactSelection(c);
      expect(logic.selectedContacts.length, 1);
      expect(logic.selectedContacts.first.id, 1);
    });

    test('对同一项再次调用 → 取消选择（移除）', () {
      final logic = SendToLogic();
      final c = conv(1, '张三');
      logic.toggleContactSelection(c);
      logic.toggleContactSelection(c);
      expect(logic.selectedContacts, isEmpty);
    });

    test('多项独立选择互不影响', () {
      final logic = SendToLogic();
      logic.toggleContactSelection(conv(1, '张三'));
      logic.toggleContactSelection(conv(2, '李四'));
      expect(logic.selectedContacts.length, 2);
    });
  });

  group('SendToLogic.search', () {
    test('空 query → searchResults 等于完整会话集（初始为空）', () {
      final logic = SendToLogic();
      logic.search('');
      expect(logic.searchResults, isEmpty);
    });

    test('非空 query 在空会话集上 → 结果为空，不抛异常', () {
      final logic = SendToLogic();
      logic.search('不存在');
      expect(logic.searchResults, isEmpty);
    });
  });
}
