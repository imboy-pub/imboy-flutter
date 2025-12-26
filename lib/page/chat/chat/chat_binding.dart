import 'package:get/get.dart';
import 'package:imboy/component/chat/message_scroll_manager.dart';

import 'chat_logic.dart';
import 'chat_state.dart';

class ChatBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => ChatLogic()),
        Bind.lazyPut(() => ChatState()),
        Bind.lazyPut(() => MessageScrollManager()),
      ];
}
