import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class GroupProvider extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String attr = '', // owner | join
  }) async {
    IMBoyHttpResponse resp = await get(API.groupPage, queryParameters: {
      'page': page,
      'size': size,
      'attr': attr,
    });

    debugPrint("> on GroupProvider/page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>> detail({required String gid}) async {
    IMBoyHttpResponse resp = await get(API.groupDetail, queryParameters: {
      "gid": gid,
    });
    debugPrint("GroupProvider/detail resp.payload: ${resp.payload.toString()}");
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : {};
  }

  Future<Map<String, dynamic>?> dissolve({required String gid}) async {
    IMBoyHttpResponse resp = await post(API.groupDissolve, data: {
      "gid": gid,
    });
    debugPrint(
        "GroupProvider/dissolve resp.payload: ${resp.payload.toString()}");
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
    IMBoyHttpResponse resp = await get(API.groupFace2face, queryParameters: {
      "code": code,
      "longitude": longitude, // 经度
      "latitude": latitude, // 维度
    });
    debugPrint(
        "GroupProvider/groupFace2face resp.payload: ${resp.payload.toString()}");
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : {};
  }

  Future<Map<String, dynamic>> groupFace2faceSave({
    required String code,
    required String gid,
  }) async {
    IMBoyHttpResponse resp = await post(API.groupFace2faceSave, data: {
      "code": code,
      "gid": gid,
    });
    debugPrint(
        "GroupProvider/groupFace2faceSave resp.payload: ${resp.payload.toString()}");
    if (resp.ok == false) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload : {};
  }

  Future<Map<String, dynamic>?> groupAdd({
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(API.groupAdd, data: {
      "member_uids": memberUserIds,
    });
    debugPrint("GroupProvider/add resp: ${resp.toString()}");
    return resp.ok ? resp.payload : null;
  }

  Future<bool> groupEdit({
    required String gid,
    required Map<String, dynamic> data,
  }) async {
    data['gid'] = gid;
    IMBoyHttpResponse resp = await post(API.groupEdit, data: data);
    debugPrint(
        "GroupProvider/groupEdit resp: ${resp.code.toString()}; ${resp.msg}");
    if (resp.code == 1) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? true : false;
  }

  /// 下面的代码是垃圾代码，作完功能后需要清理 TODO

  // Future<bool> deleteGr({required String groupId}) async {
  //   IMBoyHttpResponse resp = await post(API., data: {
  //     "scene": scene,
  //     "tag": tagName,
  //   });
  //   debugPrint("GroupProvider/deleteTag resp: ${resp.toString()}");
  //   return resp.ok ? true : false;
  // }

  Future<int> addTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(API.userTagAdd, data: {
      "scene": scene,
      "tag": tagName,
    });
    debugPrint("GroupProvider/addTag resp: ${resp.toString()}");
    if (resp.code == 1) {
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
    IMBoyHttpResponse resp = await get(api, queryParameters: {
      'page': page,
      'size': size,
      'scene': scene,
      'tag_id': tagId,
      'kwd': kwd,
    });

    debugPrint("GroupProvider/pageRelation resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<bool> removeRelation(
      {required int tagId,
      required String objectId,
      required String scene}) async {
    IMBoyHttpResponse resp = await post(API.userTagRelationRemove, data: {
      "scene": scene,
      "tagId": tagId,
      "objectId": objectId,
    });
    debugPrint("GroupProvider/delete resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<bool> setRelation(
      {required int tagId,
      required String tagName,
      required List<String> objectIds,
      required String scene}) async {
    IMBoyHttpResponse resp = await post(API.userTagRelationSet, data: {
      "scene": scene,
      "tagId": tagId,
      "tagName": tagName,
      "objectIds": objectIds,
    });
    debugPrint("GroupProvider/setRelation resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }
}
