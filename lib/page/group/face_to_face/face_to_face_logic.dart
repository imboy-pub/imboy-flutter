import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/provider/group_provider.dart';

import 'face_to_face_state.dart';

class FaceToFaceLogic extends GetxController {
  final FaceToFaceState state = FaceToFaceState();

  /// 返回空字符串，表示成功
  Future<Map<String, dynamic>> faceToFace(String code) async {
    if (state.longitude.isEmpty) {
      AMapPosition? l = await AMapHelper().startLocation();
      state.longitude.value = '${l?.latLng.longitude}';
      state.latitude.value = '${l?.latLng.latitude}';
    }
    String error = '';
    if (state.longitude.value.isEmpty ||
        state.longitude.value == "0.0" ||
        state.longitude.value == "null") {
      error =
          "${'failed_get_lat_long'.tr}，${'not_turned_location_service'.tr}，${'or'.tr} ${'not_authorized_lat_long'.tr}";
      return {
        'error': error,
      };
    }

    Map<String, dynamic> payload = await GroupProvider().groupFace2face(
      code: code,
      longitude: state.longitude.value,
      latitude: state.latitude.value,
    );

    List memberList = payload['member_list'] ?? [];
    List<PeopleModel> memberList2 = [];
    for (Map<String, dynamic> item in memberList) {
      memberList2.add(PeopleModel(
        id: item['user_id'],
        account: item['account'] ?? '',
        avatar: item['avatar'] ?? '',
        nickname: item['alias'] ?? (item['nickname'] ?? ''),
      ));
    }
    return {
      'gid': payload['gid'] ?? '',
      'memberList': memberList2,
      'error': error,
    };
  }


  Future<Map<String, dynamic>> faceToFaceSave(String gid, String code) async {
    Map<String, dynamic> payload = await GroupProvider().groupFace2faceSave(
      code: code,
      gid: gid,
    );
    iPrint("faceToFaceSave payload ${payload.toString()}");
    List memberList = payload['member_list'] ?? [];
    List<PeopleModel> memberList2 = [];
    for (Map<String, dynamic> item in memberList) {
      memberList2.add(PeopleModel(
        id: item['user_id'],
        account: item['account'] ?? '',
        avatar: item['avatar'] ?? '',
        nickname: item['alias'] ?? (item['nickname'] ?? ''),
      ));
    }
    return {
      'group': payload['group'] ?? {},
      'memberList': memberList2,
    };
  }
}
