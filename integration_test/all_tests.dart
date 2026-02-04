// 全功能测试套件
//
// 批量运行所有功能测试
// 运行命令: flutter test integration_test/all_tests.dart -d macos

import 'simple_demo_test.dart' as demo;
import 'chat/c2c_chat_test.dart' as c2c;
import 'chat/group_chat_test.dart' as group;
import 'chat/conversation_test.dart' as conversation;
import 'contact/friend_management_test.dart' as friend;

void main() {
  print('');
  print('╔════════════════════════════════════════════════════════════╗');
  print('║         IM Boy 全功能测试套件                                 ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');

  // 运行所有测试
  demo.main();
  c2c.main();
  group.main();
  conversation.main();
  friend.main();

  print('');
  print('╔════════════════════════════════════════════════════════════╗');
  print('║         所有测试执行完成                                     ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');
}
