import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/location_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
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
  int _epoch = 0;
  int _listRequest = 0;
  Future<void> _visibilityWrites = Future<void>.value();

  (String, int, int) get _session =>
      (UserRepoLocal.to.currentUid, UserRepoLocal.to.sessionGeneration, _epoch);

  bool _isCurrent((String, int, int) session) =>
      ref.mounted && session == _session && !UserRepoLocal.to.isClearingSession;

  @override
  PeopleNearbyState build() {
    ref.watch(
      currentUserProvider.select(
        (user) => (user?.uid ?? '', UserRepoLocal.to.sessionGeneration),
      ),
    );
    _visibilityWrites = Future<void>.value();
    _epoch++;
    _listRequest++;
    // 初始化时从本地存储读取可见性设置
    final isVisible = UserRepoLocal.to.setting.peopleNearbyVisible;

    return PeopleNearbyState(peopleNearbyVisible: isVisible);
  }

  Future<bool> _hasLocationAccess({bool requestIfDenied = false}) async {
    const timeout = Duration(seconds: 5);
    try {
      if (!await Geolocator.isLocationServiceEnabled().timeout(timeout)) {
        return false;
      }
      var permission = await Geolocator.checkPermission().timeout(timeout);
      if (requestIfDenied && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(timeout);
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } on Object {
      debugPrint('[PeopleNearby] location permission unavailable');
      return false;
    }
  }

  void _clearLocation() {
    _listRequest++;
    state = state.copyWith(
      longitude: '',
      latitude: '',
      peopleList: [],
      isLoading: false,
    );
  }

  Future<void> _revokeLocation((String, int, int) session) async {
    if (!_isCurrent(session)) return;
    _clearLocation();
    final hidden = await makeMyselfUnVisible();
    if (_isCurrent(session) && !hidden) {
      AppLoading.showBackendError(t.common.operationFailedAgainLater);
    }
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
      iPrint('[PeopleNearby] 坐标解析失败: $e');
      return false;
    }
  }

  /// 清空列表
  void clearList() {
    state = state.copyWith(peopleList: []);
  }

  /// 初始化：直接拉取附近的人。坐标为空时由 peopleNearby 内部定位，
  /// 避免此处与 peopleNearby 重复定位拖慢首次进入。
  Future<void> init() async {
    await peopleNearby();
  }

  /// 获取附近的人
  Future<void> peopleNearby() async {
    final session = _session;
    if (session.$1.isEmpty || !_isCurrent(session)) return;
    final request = ++_listRequest;
    bool active() => _isCurrent(session) && request == _listRequest;
    // 进入即置加载态：首次定位(GPS+权限)耗时期间显示加载菊花，
    // 而非误导性的空状态。finally 统一兜底关闭。
    state = state.copyWith(isLoading: true);
    // 分段耗时埋点：真机反馈「首次进入要 3 秒以上才出数据」，iOS/Android 都有。
    // 后端接口公网实测 49~220ms，慢的不在服务端，用分段计时定位到底卡在哪一段。
    // 过滤日志：flutter logs | grep PeopleNearbyPerf
    final swTotal = Stopwatch()..start();
    int msLocate = 0, msApi = 0, msLocalDb = 0;
    try {
      final permitted = await _hasLocationAccess(
        requestIfDenied: state.longitude.isEmpty,
      );
      if (!active()) return;
      if (!permitted) {
        await _revokeLocation(session);
        return;
      }
      if (state.longitude.isEmpty) {
        final swLocate = Stopwatch()..start();
        // preferLastKnown: 附近的人半径 500km，几分钟前的坐标与实时坐标
        // 落到同一批结果，没必要为此等高德失败(约1s)+geolocator 超时(4s)。
        AMapPosition? l = await LocationService().getCurrentPosition(
          preferLastKnown: true,
        );
        if (!active()) return;
        msLocate = swLocate.elapsedMilliseconds;
        debugPrint('[PeopleNearbyPerf] 1.定位 ${msLocate}ms');
        updateLocation('${l?.latLng.longitude}', '${l?.latLng.latitude}');
      } else {
        debugPrint('[PeopleNearbyPerf] 1.定位 跳过(已有坐标)');
      }

      // 检查坐标是否有效（包括 "0.0", "0.0000000" 等无效坐标）
      if (!_isValidCoordinate(state.longitude, state.latitude)) {
        AppLoading.showInfo(
          "${t.common.failedGetLatLong}\n${t.common.notTurnedLocationService}\n${t.main.or} ${t.common.notAuthorizedLatLong}",
        );
        return;
      }

      int radius = 500000;
      // 获取附近的人
      final swApi = Stopwatch()..start();
      Map<String, dynamic>? payload = await LocationApi().peopleNearby(
        longitude: state.longitude, // 经度
        latitude: state.latitude, // 维度
        radius: radius,
        unit: 'm',
      );
      if (!active()) return;
      msApi = swApi.elapsedMilliseconds;
      debugPrint('[PeopleNearbyPerf] 2.接口 ${msApi}ms');

      final stillPermitted = await _hasLocationAccess();
      if (!active()) return;
      if (!stillPermitted) {
        await _revokeLocation(session);
        return;
      }
      if (payload == null) {
        return;
      }
      final swDb = Stopwatch()..start();
      List<Map<String, dynamic>> li = await ContactRepo().selectFriend(
        columns: [ContactRepo.peerId],
      );
      if (!active()) return;
      msLocalDb = swDb.elapsedMilliseconds;
      debugPrint('[PeopleNearbyPerf] 3.本地好友查询 ${msLocalDb}ms');
      List<String> friendUidList = [];
      for (var f in li) {
        // peer_id 在 SQLite 中为整型(TSID)，统一 toString 比较，避免 as String 崩溃
        friendUidList.add(f[ContactRepo.peerId].toString());
      }

      List<PeopleModel> l = [];
      for (var json in IMBoyHttpResponse.payloadList(payload)) {
        json['unit'] = payload['unit'];
        // 后端 id 以 JSON integer(TSID) 返回，统一按 String 比较（排除自己 + isFriend）
        final String pid = (json['uid'] ?? json['id']).toString();
        PeopleModel model = PeopleModel.fromJson(json);
        if (pid != UserRepoLocal.to.currentUid) {
          model.isFriend = friendUidList.contains(pid);
          l.add(model);
        }
      }
      final permittedAtCompletion = await _hasLocationAccess();
      if (!active()) return;
      if (!permittedAtCompletion) {
        await _revokeLocation(session);
        return;
      }
      updatePeopleList(l);
    } finally {
      if (active()) state = state.copyWith(isLoading: false);
      debugPrint(
        '[PeopleNearbyPerf] 合计 ${swTotal.elapsedMilliseconds}ms '
        '= 定位 ${msLocate}ms + 接口 ${msApi}ms + 本地库 ${msLocalDb}ms '
        '+ 其余 ${swTotal.elapsedMilliseconds - msLocate - msApi - msLocalDb}ms',
      );
    }
  }

  /// 让自己可见
  Future<bool> makeMyselfVisible() async {
    final session = _session;
    if (session.$1.isEmpty || !_isCurrent(session)) return false;
    // 检查坐标是否有效
    if (!_isValidCoordinate(state.longitude, state.latitude)) {
      AppLoading.showInfo(
        "${t.common.failedGetLatLong}\n${t.common.notTurnedLocationService}\n${t.main.or} ${t.common.notAuthorizedLatLong}",
      );
      return false;
    }

    return _setVisibility(true);
  }

  /// 让自己不可见
  Future<bool> makeMyselfUnVisible() => _setVisibility(false);

  Future<bool> _setVisibility(bool visible) {
    final session = _session;
    if (session.$1.isEmpty || !_isCurrent(session)) return Future.value(false);
    final longitude = state.longitude;
    final latitude = state.latitude;
    final result = _visibilityWrites.then(
      (_) => _commitVisibility(session, visible, longitude, latitude),
    );
    // 仅恢复队列，原 result 仍向调用方传播错误。
    _visibilityWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<bool> _allowVisibility((String, int, int) session) async {
    final permitted = await _hasLocationAccess();
    if (!_isCurrent(session)) return false;
    if (permitted) return true;
    _clearLocation();
    final hidden = await _commitVisibility(session, false, '', '');
    if (_isCurrent(session) && !hidden) {
      AppLoading.showBackendError(t.common.operationFailedAgainLater);
    }
    return false;
  }

  Future<bool> _commitVisibility(
    (String, int, int) session,
    bool visible,
    String longitude,
    String latitude,
  ) async {
    if (session.$1.isEmpty || !_isCurrent(session)) return false;
    if (visible && !await _allowVisibility(session)) return false;
    final api = LocationApi();
    final res = visible
        ? await api.makeMyselfVisible(longitude: longitude, latitude: latitude)
        : await api.makeMyselfUnVisible();
    if (!_isCurrent(session)) return false;
    if (!res) return false;
    if (visible && !await _allowVisibility(session)) return false;
    final setting = UserRepoLocal.to.setting..peopleNearbyVisible = visible;
    final saved = await UserRepoLocal.to.changeSettingForSession(
      setting,
      uid: session.$1,
      generation: session.$2,
    );
    if (!saved || !_isCurrent(session)) return false;
    updateVisibility(visible);
    return true;
  }
}

/// 附近的人 Provider
final peopleNearbyProvider =
    NotifierProvider<PeopleNearbyNotifier, PeopleNearbyState>(
      PeopleNearbyNotifier.new,
    );
