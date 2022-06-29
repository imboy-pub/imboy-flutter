import 'package:get/get.dart';

import 'bottom_navigation_state.dart';

class BottomNavigationLogic extends GetxController {
  final state = BottomNavigationState();

  //改变底部导航栏索引
  void changeBottomBarIndex(int index) {
    state.bottombarIndex.value = index;
    // print(state.bottombarIndex.value);
  }
}
