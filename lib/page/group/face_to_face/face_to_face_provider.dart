import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'face_to_face_provider.g.dart';

/// 面对面建群状态
class FaceToFaceState {
  final NumericKeypadController textEditingController;
  final String errorInfo;
  final String resultData;
  final String longitude; // 经度
  final String latitude; // 纬度

  const FaceToFaceState({
    required this.textEditingController,
    this.errorInfo = '',
    this.resultData = '',
    this.longitude = '',
    this.latitude = '',
  });

  FaceToFaceState copyWith({
    NumericKeypadController? textEditingController,
    String? errorInfo,
    String? resultData,
    String? longitude,
    String? latitude,
  }) {
    return FaceToFaceState(
      textEditingController:
          textEditingController ?? this.textEditingController,
      errorInfo: errorInfo ?? this.errorInfo,
      resultData: resultData ?? this.resultData,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
    );
  }
}

/// 面对面建群 Notifier
@Riverpod(keepAlive: false)
class FaceToFaceNotifier extends _$FaceToFaceNotifier {
  @override
  FaceToFaceState build() {
    return FaceToFaceState(textEditingController: NumericKeypadController(''));
  }

  /// 更新输入结果
  void updateResult(String value) {
    state = state.copyWith(resultData: value);
  }

  /// 更新错误信息
  void updateErrorInfo(String error) {
    state = state.copyWith(errorInfo: error);
  }

  /// 清空输入
  void clearInput() {
    state.textEditingController.clearText();
    state = state.copyWith(resultData: '', errorInfo: '');
  }

  /// 获取位置
  Future<bool> getLocation() async {
    if (state.longitude.isNotEmpty) {
      return true;
    }

    try {
      AMapPosition? l = await LocationService().getCurrentPosition();
      final lon = '${l?.latLng.longitude}';
      final lat = '${l?.latLng.latitude}';

      state = state.copyWith(longitude: lon, latitude: lat);

      return _isValidCoordinate(lon, lat);
    } catch (e) {
      return false;
    }
  }

  bool _isValidCoordinate(String lon, String lat) {
    if (lon.isEmpty || lat.isEmpty) return false;

    final longitude = double.tryParse(lon);
    final latitude = double.tryParse(lat);
    if (longitude == null || latitude == null) return false;

    if (longitude == 0.0 && latitude == 0.0) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude < -90 || latitude > 90) return false;
    return true;
  }

  /// 面对面建群
  Future<Map<String, dynamic>> faceToFace(String code) async {
    // 获取位置
    final hasLocation = await getLocation();
    if (!hasLocation) {
      final error =
          "${t.failedGetLatLong}，${t.notTurnedLocationService}，${t.or} ${t.notAuthorizedLatLong}";
      return {'error': error};
    }

    iPrint('[面对面建群] 开始请求, hasLocation=true');

    // 调用 API
    Map<String, dynamic> payload = await GroupApi().groupFace2face(
      code: code,
      longitude: state.longitude,
      latitude: state.latitude,
    );

    iPrint(
      '[面对面建群] API 响应, gid=${payload['gid'] ?? ''}, memberCount=${(payload['member_list'] ?? []).length}',
    );

    // 解析成员列表
    List<dynamic> memberList = payload['member_list'] ?? [];
    List<PeopleModel> memberList2 = [];
    for (var item in memberList) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        memberList2.add(
          PeopleModel(
            id: itemMap['user_id'],
            account: itemMap['account'] ?? '',
            avatar: itemMap['avatar'] ?? '',
            nickname: itemMap['alias'] ?? (itemMap['nickname'] ?? ''),
          ),
        );
      }
    }

    iPrint('[面对面建群] 解析后成员数量: ${memberList2.length}');

    return {
      'gid': payload['gid'] ?? '',
      'memberList': memberList2,
      'error': '',
    };
  }

  /// 保存面对面建群
  Future<Map<String, dynamic>> faceToFaceSave(String gid, String code) async {
    Map<String, dynamic> payload = await GroupApi().groupFace2faceSave(
      code: code,
      gid: gid,
    );
    iPrint(
      "faceToFaceSave memberCount=${(payload['member_list'] ?? []).length}",
    );

    List<dynamic> memberList = payload['member_list'] ?? [];
    List<PeopleModel> memberList2 = [];
    for (var item in memberList) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        memberList2.add(
          PeopleModel(
            id: itemMap['user_id'],
            account: itemMap['account'] ?? '',
            avatar: itemMap['avatar'] ?? '',
            nickname: itemMap['alias'] ?? (itemMap['nickname'] ?? ''),
          ),
        );
      }
    }

    return {'group': payload['group'] ?? {}, 'memberList': memberList2};
  }
}
