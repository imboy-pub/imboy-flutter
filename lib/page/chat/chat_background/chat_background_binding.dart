import 'package:get/get.dart';

import 'chat_background_logic.dart';

class ChatBackgroundBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => ChatBackgroundLogic()),
      ];
}
