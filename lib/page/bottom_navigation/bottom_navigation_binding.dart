import 'package:get/get.dart';

import 'bottom_navigation_logic.dart';

class BottomNavigationBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => BottomNavigationLogic()),
      ];
}
