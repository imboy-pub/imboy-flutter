import 'package:get/get.dart';

class BottomNavigationState {
  //底部导航栏索引
  RxInt bottomBarIndex = 0.obs;
  RxBool isConnected = false.obs;
  BottomNavigationState() {
    ///Initialize variables
  }
}
