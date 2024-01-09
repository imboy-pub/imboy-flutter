import 'package:get/get.dart';

import 'chat_setting_logic.dart';

class ChatSettingBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => ChatSettingLogic()),
      ];
}
