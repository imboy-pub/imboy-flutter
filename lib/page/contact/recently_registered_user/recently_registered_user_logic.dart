import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

import 'recently_registered_user_state.dart';

class RecentlyRegisteredUserLogic extends GetxController {
  final RecentlyRegisteredUserState state = RecentlyRegisteredUserState();

  Future<List<PeopleModel>> page({
    int page = 1,
    int size = 10,
    String? kind,
    String? kwd,
    bool onRefresh = false,
  }) async {
    List<PeopleModel> list = [];
    page = page > 1 ? page : 1;

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      String msg = 'tip_connect_desc'.tr;
      EasyLoading.showError(' $msg        ');
      return [];
    }
    iPrint("UserTagRepo_page logic ; onRefresh $onRefresh;  ${list.length}");
    Map<String, dynamic>? payload = await UserProvider().ftsRecentlyUser(
      page: page,
      size: size,
      keyword: kwd ?? '',
    );
    if (payload == null) {
      return [];
    }
    ContactRepo repo = ContactRepo();
    for (var json in payload['list']) {
      PeopleModel model = PeopleModel.fromJson(json);
      repo.update({
        'id': json['id'],
        ContactRepo.isFriend: json['is_friend'],
        ContactRepo.nickname: json['nickname'],
        ContactRepo.avatar: json['avatar'],
        ContactRepo.sign: json['sign'],
        ContactRepo.gender: json['gender'],
        ContactRepo.region: json['region'],
      });
      list.add(model);
    }
    return list;
  }
}
