import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/provider/location_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'people_nearby_state.dart';

class PeopleNearbyLogic extends GetxController {
  final PeopleNearbyState state = PeopleNearbyState();

  PeopleNearbyLogic() {
    ///Initialize variables
    init();
  }

  Future<void> init() async {
    DateTime s = DateTime.now();
    AMapPosition? l = await AMapHelper().startLocation();
    DateTime end = DateTime.now();
    debugPrint(
        "PeopleNearbyLogic init peopleNearbyVisible ${state.peopleNearbyVisible} diff ${end.difference(s)}");
    state.longitude.value = '${l?.latLng.longitude}';
    state.latitude.value = '${l?.latLng.latitude}';
    peopleNearby();
    DateTime end2 = DateTime.now();
    debugPrint(
        "PeopleNearbyLogic init peopleNearbyVisible diff2 ${end2.difference(s)}");
  }

  Future<void> peopleNearby() async {
    if (state.longitude.isEmpty) {
      AMapPosition? l = await AMapHelper().startLocation();
      state.longitude.value = '${l?.latLng.longitude}';
      state.latitude.value = '${l?.latLng.latitude}';
    }
    if (state.longitude.value.isEmpty || state.longitude.value == "null") {
      EasyLoading.showInfo(
          "${'failed_get_lat_long'.tr}\n${'not_turned_location_service'.tr}\n${'or'.tr} ${'not_authorized_lat_long'.tr}");
      return;
    }
    // debugPrint("PeopleNearbyLogic peopleNearby ${state.longitude.value.isEmpty} = ${state.longitude.value} ");
    int radius = 500000;
    // 获取附近的人
    Map<String, dynamic>? payload = await LocationProvider().peopleNearby(
      longitude: state.longitude.value, // 经度
      latitude: state.latitude.value, // 维度
      radius: radius,
      unit: 'm',
    );
    // debugPrint("PeopleNearbyLogic peopleNearby ${payload.toString()}");

    if (payload == null) {
      return;
    }
    List<Map<String, dynamic>> li = await ContactRepo().selectFriend(
      columns: [ContactRepo.peerId],
    );
    List<String> friendUidList = [];
    for (var f in li) {
      friendUidList.add(f[ContactRepo.peerId]);
    }
    // debugPrint(" on selectFrien2 ${friendUidList.toString()}");

    List<PeopleModel> l = [];
    for (var json in payload['list']) {
      json['unit'] = payload['unit'];
      PeopleModel model = PeopleModel.fromJson(json);
      if (json['id'] != UserRepoLocal.to.currentUid) {
        model.isFriend = friendUidList.contains(json['id']);
        // debugPrint("on selectFrien2 ${json['id']} isFriend ${model.isFriend}");
        l.add(model);
      }
    }
    state.peopleList.value = l;
  }

  /// 让自己可见
  Future<bool> makeMyselfVisible() async {
    state.peopleNearbyVisible.value = !state.peopleNearbyVisible.value;
    // return true;
    bool res = await LocationProvider().makeMyselfVisible(
      longitude: state.longitude.value,
      latitude: state.latitude.value,
    );
    if (res) {
      var s = UserRepoLocal.to.setting;
      s.peopleNearbyVisible = true;
      UserRepoLocal.to.changeSetting(s);
    }
    return res;
  }

  /// 让自己不可见
  Future<bool> makeMyselfUnVisible() async {
    state.peopleNearbyVisible.value = !state.peopleNearbyVisible.value;
    bool res = await LocationProvider().makeMyselfUnVisible();
    if (res) {
      var s = UserRepoLocal.to.setting;
      s.peopleNearbyVisible = false;
      UserRepoLocal.to.changeSetting(s);
    }
    return res;
  }
}
