import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserTagProvider extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String scene = '',
    String kwd = '',
  }) async {
    IMBoyHttpResponse resp = await get(API.userTagPage, queryParameters: {
      'page': page,
      'size': size,
      'scene': scene,
      'kwd': kwd,
    });

    debugPrint("> on UserTagProvider/page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 添加标签、移除标签功能
  /// tag 为空表示移除表情
  Future<bool> relationAdd({
    required String objectId,
    required List<dynamic> tag,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(API.userTagRelationAdd, data: {
      "scene": scene,
      "objectId": objectId,
      "tag": tag,
    });
    debugPrint("UserTagProvider/add resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<bool> changeName(
      {required String scene,
      required int tagId,
      required String tagName}) async {
    IMBoyHttpResponse resp = await post(API.userTagChangeName, data: {
      "scene": scene,
      "tagId": tagId,
      "tagName": tagName,
    });
    debugPrint(
        "UserTagProvider/changeName resp: ${resp.code.toString()}; ${resp.msg}");
    if (resp.code == 1) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? true : false;
  }

  Future<bool> deleteTag(
      {required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(API.userTagDelete, data: {
      "scene": scene,
      "tag": tagName,
    });
    debugPrint("UserTagProvider/deleteTag resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<int> addTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(API.userTagAdd, data: {
      "scene": scene,
      "tag": tagName,
    });
    debugPrint("UserTagProvider/addTag resp: ${resp.toString()}");
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

    debugPrint("UserTagProvider/pageRelation resp: ${resp.payload.toString()}");
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
    debugPrint("UserTagProvider/delete resp: ${resp.toString()}");
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
    debugPrint("UserTagProvider/setRelation resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }
}
