// integration_test/all_tests.dart — 全量集成测试入口
import 'app_test.dart' as app_test;
import 'e2e_chat_test.dart' as c2c_chat;
import 'chat/conversation_test.dart' as conversation;
import 'chat/group_chat_test.dart' as group_chat;
import 'channel/channel_e2e_test.dart' as channel_e2e;
import 'channel/channel_publish_test.dart' as channel_publish;
import 'channel/channel_edit_persistence_test.dart' as channel_edit;
import 'channel/channel_subscribed_detail_consistency_test.dart' as channel_consist;
import 'contact/friend_management_test.dart' as friend_mgmt;
import 'contact/add_friend_request_test.dart' as add_friend;
import 'auth/register_flow_test.dart' as register;
import 'auth/password_change_test.dart' as pwd_change;

void main() {
  app_test.main();
  c2c_chat.main();
  conversation.main();
  group_chat.main();
  channel_e2e.main();
  channel_publish.main();
  channel_edit.main();
  channel_consist.main();
  friend_mgmt.main();
  add_friend.main();
  register.main();
  pwd_change.main();
}
