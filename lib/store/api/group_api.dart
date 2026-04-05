import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class GroupApi extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String attr = '', // owner | join | manager
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupPage,
      queryParameters: {'page': page, 'size': size, 'attr': attr},
    );

    debugPrint("> on GroupApi/page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>> detail({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      API.groupDetail,
      queryParameters: {"gid": gid},
    );
    debugPrint("GroupApi/detail resp.payload: ${resp.payload.toString()}");
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : {};
  }

  /// 获取群备注（仅自己可见）
  Future<String?> getRemark({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      API.groupRemark,
      queryParameters: {'gid': gid},
    );
    if (!resp.ok) return null;
    return resp.payload['remark'] as String?;
  }

  /// 更新群备注（仅自己可见）
  Future<bool> updateRemark({
    required String gid,
    required String remark,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupRemark,
      data: {'gid': gid, 'remark': remark},
    );
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok;
  }

  Future<Map<String, dynamic>?> dissolve({required String gid}) async {
    IMBoyHttpResponse resp = await post(API.groupDissolve, data: {"gid": gid});
    debugPrint("GroupApi/dissolve resp.payload: ${resp.payload.toString()}");
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : null;
  }

  /// 面对面建群
  Future<Map<String, dynamic>> groupFace2face({
    required String code,
    required String longitude,
    required String latitude,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupFace2face,
      queryParameters: {
        "code": code,
        "longitude": longitude, // 经度
        "latitude": latitude, // 维度
      },
    );
    debugPrint(
      "GroupApi/groupFace2face resp.payload: ${resp.payload.toString()}",
    );
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : {};
  }

  Future<Map<String, dynamic>> groupFace2faceSave({
    required String code,
    required String gid,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupFace2faceSave,
      data: {"code": code, "gid": gid},
    );
    debugPrint(
      "GroupApi/groupFace2faceSave resp.payload: ${resp.payload.toString()}",
    );
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : {};
  }

  Future<Map<String, dynamic>?> groupAdd({
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupAdd,
      data: {"member_uids": memberUserIds},
    );
    debugPrint("GroupApi/add resp: ${resp.toString()}");
    debugPrint(
      "GroupApi/add resp.ok: ${resp.ok}, resp.code: ${resp.code}, resp.payload: ${resp.payload}",
    );
    return resp.ok ? resp.payload : null;
  }

  Future<bool> groupEdit({
    required String gid,
    required Map<String, dynamic> data,
  }) async {
    data['gid'] = gid;
    IMBoyHttpResponse resp = await post(API.groupEdit, data: data);
    debugPrint("GroupApi/groupEdit resp: ${resp.code.toString()}; ${resp.msg}");
    if (resp.code == ErrorCode.ERROR) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? true : false;
  }

  Future<int> addTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(
      API.userTagAdd,
      data: {"scene": scene, "tag": tagName},
    );
    debugPrint("GroupApi/addTag resp: ${resp.toString()}");
    if (resp.code == ErrorCode.ERROR) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload['tagId'] : 0;
  }

  Future<Map<String, dynamic>?> pageRelation({
    int page = 1,
    int size = 10,
    required int tagId,
    String scene = '',
    String? kwd,
  }) async {
    String api = API.userTagRelationFriendPage;
    if (scene == 'collect') {
      api = API.userTagRelationCollectPage;
    } else if (scene == 'friend') {
      api = API.userTagRelationFriendPage;
    }
    IMBoyHttpResponse resp = await get(
      api,
      queryParameters: {
        'page': page,
        'size': size,
        'scene': scene,
        'tag_id': tagId,
        'kwd': kwd,
      },
    );

    debugPrint("GroupApi/pageRelation resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<bool> removeRelation({
    required int tagId,
    required String objectId,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationRemove,
      data: {"scene": scene, "tagId": tagId, "objectId": objectId},
    );
    debugPrint("GroupApi/delete resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<bool> setRelation({
    required int tagId,
    required String tagName,
    required List<String> objectIds,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationSet,
      data: {
        "scene": scene,
        "tagId": tagId,
        "tagName": tagName,
        "objectIds": objectIds,
      },
    );
    debugPrint("GroupApi/setRelation resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  /// 转让群主
  /// [gid] 群组ID
  /// [newOwnerUid] 新群主用户ID
  Future<bool> transfer({
    required String gid,
    required String newOwnerUid,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupTransfer,
      data: {'gid': gid, 'new_owner_uid': newOwnerUid},
    );

    debugPrint("GroupApi/transfer resp: ${resp.payload.toString()}");
    return resp.ok;
  }
}
