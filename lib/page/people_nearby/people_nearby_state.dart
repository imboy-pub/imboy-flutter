import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class PeopleNearbyState {
  int page = 1;
  int size = 20;
  int limit = 90;

  RxBool peopleNearbyVisible = false.obs;
  RxList peopleList = [].obs;

  RxString longitude = "".obs; // 经度
  RxString latitude = "".obs; // 维度

  PeopleNearbyState() {
    ///Initialize variables
    peopleNearbyVisible.value = UserRepoLocal.to.setting.peopleNearbyVisible;
    debugPrint(
        "PeopleNearbyState init peopleNearbyVisible $peopleNearbyVisible; ${UserRepoLocal.to.setting.peopleNearbyVisible}");
  }
}
