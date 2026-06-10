import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserTagApi extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String scene = '',
    String kwd = '',
  }) async {
    IMBoyHttpResponse resp = await get(
      API.userTagPage,
      queryParameters: {'page': page, 'size': size, 'scene': scene, 'kwd': kwd},
    );

    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }

  /// 添加标签、移除标签功能
  /// tag 为空表示移除表情
  Future<bool> relationAdd({
    required String objectId,
    required List<dynamic> tag,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationAdd,
      data: {"scene": scene, "objectId": objectId, "tag": tag},
    );
    return resp.ok ? true : false;
  }

  Future<bool> changeName({
    required String scene,
    required int tagId,
    required String tagName,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagChangeName,
      data: {"scene": scene, "tagId": tagId, "tagName": tagName},
    );
    if (resp.code == ErrorCode.ERROR) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? true : false;
  }

  Future<bool> deleteTag({
    required String scene,
    required String tagName,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagDelete,
      data: {"scene": scene, "tag": tagName},
    );
    return resp.ok ? true : false;
  }

  Future<int> addTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(
      API.userTagAdd,
      data: {"scene": scene, "tag": tagName},
    );
    if (resp.code == ErrorCode.ERROR) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok ? (resp.payload['tagId'] as int) : 0;
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

    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
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
    return resp.ok ? true : false;
  }
}
