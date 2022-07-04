import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'bottom_navigation_state.dart';

class BottomNavigationLogic extends GetxController {
  final state = BottomNavigationState();

  RxInt newFriendRemindCounter = 0.obs;

  Future<void> countNewFriendRemindCounter() async {
    debugPrint(">>> on countNewFriendRemindCounter");
    int? count = await NewFriendRepo().countStatus(
        NewFriendStatus.waiting_for_validation.index,
        UserRepoLocal.to.currentUid);
    newFriendRemindCounter.value = count ?? 0;
  }

  //改变底部导航栏索引
  void changeBottomBarIndex(int index) {
    state.bottombarIndex.value = index;
    // print(state.bottombarIndex.value);
  }
}
