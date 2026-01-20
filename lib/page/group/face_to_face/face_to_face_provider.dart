import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
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
      AMapPosition? l = await AMapHelper().startLocation();
      final lon = '${l?.latLng.longitude}';
      final lat = '${l?.latLng.latitude}';

      state = state.copyWith(longitude: lon, latitude: lat);

      return lon.isNotEmpty && lon != "0.0" && lon != "null";
    } catch (e) {
      return false;
    }
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

    // 调用 API
    Map<String, dynamic> payload = await GroupApi().groupFace2face(
      code: code,
      longitude: state.longitude,
      latitude: state.latitude,
    );

    // 解析成员列表
    List memberList = payload['member_list'] ?? [];
    List<PeopleModel> memberList2 = [];
    for (Map<String, dynamic> item in memberList) {
      memberList2.add(
        PeopleModel(
          id: item['user_id'],
          account: item['account'] ?? '',
          avatar: item['avatar'] ?? '',
          nickname: item['alias'] ?? (item['nickname'] ?? ''),
        ),
      );
    }

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
    iPrint("faceToFaceSave payload ${payload.toString()}");

    List memberList = payload['member_list'] ?? [];
    List<PeopleModel> memberList2 = [];
    for (Map<String, dynamic> item in memberList) {
      memberList2.add(
        PeopleModel(
          id: item['user_id'],
          account: item['account'] ?? '',
          avatar: item['avatar'] ?? '',
          nickname: item['alias'] ?? (item['nickname'] ?? ''),
        ),
      );
    }

    return {'group': payload['group'] ?? {}, 'memberList': memberList2};
  }
}
