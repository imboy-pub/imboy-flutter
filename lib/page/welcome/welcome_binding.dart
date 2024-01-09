import 'package:get/get.dart';

import 'welcome_logic.dart';

class WelcomeBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => WelcomeLogic()),
      ];
}
