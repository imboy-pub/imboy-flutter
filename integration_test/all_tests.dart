// 全功能测试套件
//
// 批量运行所有功能测试
// 运行命令: flutter test integration_test/all_tests.dart -d macos

import 'simple_demo_test.dart' as demo;
import 'chat/c2c_chat_test.dart' as c2c;
import 'chat/group_chat_test.dart' as group;
import 'chat/conversation_test.dart' as conversation;
import 'chat/message_ack_test.dart' as ack;
import 'contact/friend_management_test.dart' as friend;
import 'channel/channel_e2e_test.dart' as channel;
import 'channel/channel_publish_test.dart' as channel_publish;
import 'channel/channel_edit_persistence_test.dart' as channel_edit_persistence;
import 'channel/channel_subscribed_detail_consistency_test.dart'
    as channel_subscribed_consistency;
import 'auth/register_flow_test.dart' as register;
import 'auth/password_change_test.dart' as password_change;
import 'chat/c2c_dual_role_test.dart' as c2c_dual;
import 'contact/add_friend_request_test.dart' as add_friend_req;
import 'enhanced_chat_test.dart' as enhanced_chat;
import 'group_manage_test.dart' as group_manage;

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
  ack.main();
  friend.main();
  channel.main();
  channel_publish.main();
  channel_edit_persistence.main();
  channel_subscribed_consistency.main();
  register.main();
  password_change.main();
  c2c_dual.main();
  add_friend_req.main();
  enhanced_chat.main();
  group_manage.main();

  print('');
  print('╔════════════════════════════════════════════════════════════╗');
  print('║         所有测试执行完成                                     ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');
}
