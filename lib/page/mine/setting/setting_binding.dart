import 'package:get/get.dart';

import 'setting_logic.dart';

class SettingBinding extends Binding {
  @override
    List<Bind> dependencies() => [
        Bind.lazyPut(() => SettingLogic()),
      ];
}
