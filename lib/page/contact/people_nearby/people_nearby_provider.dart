import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/location_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 附近的人状态类
class PeopleNearbyState {
  final List<PeopleModel> peopleList;
  final bool peopleNearbyVisible;
  final bool isLoading;
  final String longitude; // 经度
  final String latitude; // 维度
  final int page;
  final int size;
  final int limit;

  const PeopleNearbyState({
    this.peopleList = const [],
    this.peopleNearbyVisible = false,
    this.isLoading = false,
    this.longitude = "",
    this.latitude = "",
    this.page = 1,
    this.size = 20,
    this.limit = 90,
  });

  PeopleNearbyState copyWith({
    List<PeopleModel>? peopleList,
    bool? peopleNearbyVisible,
    bool? isLoading,
    String? longitude,
    String? latitude,
    int? page,
    int? size,
    int? limit,
  }) {
    return PeopleNearbyState(
      peopleList: peopleList ?? this.peopleList,
      peopleNearbyVisible: peopleNearbyVisible ?? this.peopleNearbyVisible,
      isLoading: isLoading ?? this.isLoading,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      page: page ?? this.page,
      size: size ?? this.size,
      limit: limit ?? this.limit,
    );
  }
}

/// 附近的人状态通知器
class PeopleNearbyNotifier extends Notifier<PeopleNearbyState> {
  @override
  PeopleNearbyState build() {
    // 初始化时从本地存储读取可见性设置
    final isVisible = UserRepoLocal.to.setting.peopleNearbyVisible;

    return PeopleNearbyState(peopleNearbyVisible: isVisible);
  }

  /// 更新人员列表
  void updatePeopleList(List<PeopleModel> list) {
    state = state.copyWith(peopleList: list);
  }

  /// 更新可见性状态
  void updateVisibility(bool visible) {
    state = state.copyWith(peopleNearbyVisible: visible);
  }

  /// 更新位置信息
  void updateLocation(String longitude, String latitude) {
    state = state.copyWith(longitude: longitude, latitude: latitude);
  }

  /// 检查坐标是否有效
  bool _isValidCoordinate(String longitude, String latitude) {
    if (longitude.isEmpty || latitude.isEmpty) {
      return false;
    }

    // 尝试解析为 double
    try {
      double lng = double.parse(longitude);
      double lat = double.parse(latitude);
      // 检查是否为无效坐标 (0, 0) 或超出范围
      if (lng == 0.0 && lat == 0.0) {
        return false;
      }
      // 经度范围: -180 到 180
      // 纬度范围: -90 到 90
      if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 清空列表
  void clearList() {
    state = state.copyWith(peopleList: []);
  }

  /// 初始化
  Future<void> init() async {
    AMapPosition? l = await LocationService().getCurrentPosition();
    updateLocation('${l?.latLng.longitude}', '${l?.latLng.latitude}');
    await peopleNearby();
  }

  /// 获取附近的人
  Future<void> peopleNearby() async {
    if (state.longitude.isEmpty) {
      AMapPosition? l = await LocationService().getCurrentPosition();
      updateLocation('${l?.latLng.longitude}', '${l?.latLng.latitude}');
    }

    // 检查坐标是否有效（包括 "0.0", "0.0000000" 等无效坐标）
    if (!_isValidCoordinate(state.longitude, state.latitude)) {
      EasyLoading.showInfo(
        "${t.common.failedGetLatLong}\n${t.common.notTurnedLocationService}\n${t.main.or} ${t.common.notAuthorizedLatLong}",
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      int radius = 500000;
      // 获取附近的人
      Map<String, dynamic>? payload = await LocationApi().peopleNearby(
        longitude: state.longitude, // 经度
        latitude: state.latitude, // 维度
        radius: radius,
        unit: 'm',
      );

      if (payload == null) {
        return;
      }
      List<Map<String, dynamic>> li = await ContactRepo().selectFriend(
        columns: [ContactRepo.peerId],
      );
      List<String> friendUidList = [];
      for (var f in li) {
        // peer_id 在 SQLite 中为整型(TSID)，统一 toString 比较，避免 as String 崩溃
        friendUidList.add(f[ContactRepo.peerId].toString());
      }

      List<PeopleModel> l = [];
      for (var json in (payload['list'] as List)) {
        json['unit'] = payload['unit'];
        // 后端 id 以 JSON integer(TSID) 返回，统一按 String 比较（排除自己 + isFriend）
        final String pid = (json['uid'] ?? json['id']).toString();
        PeopleModel model = PeopleModel.fromJson(json as Map<String, dynamic>);
        if (pid != UserRepoLocal.to.currentUid) {
          model.isFriend = friendUidList.contains(pid);
          l.add(model);
        }
      }
      updatePeopleList(l);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 让自己可见
  Future<bool> makeMyselfVisible() async {
    // 检查坐标是否有效
    if (!_isValidCoordinate(state.longitude, state.latitude)) {
      EasyLoading.showInfo(
        "${t.common.failedGetLatLong}\n${t.common.notTurnedLocationService}\n${t.main.or} ${t.common.notAuthorizedLatLong}",
      );
      return false;
    }

    updateVisibility(!state.peopleNearbyVisible);

    bool res = await LocationApi().makeMyselfVisible(
      longitude: state.longitude,
      latitude: state.latitude,
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
    updateVisibility(!state.peopleNearbyVisible);

    bool res = await LocationApi().makeMyselfUnVisible();
    if (res) {
      var s = UserRepoLocal.to.setting;
      s.peopleNearbyVisible = false;
      UserRepoLocal.to.changeSetting(s);
    }
    return res;
  }
}

/// 附近的人 Provider
final peopleNearbyProvider =
    NotifierProvider<PeopleNearbyNotifier, PeopleNearbyState>(
      PeopleNearbyNotifier.new,
    );
