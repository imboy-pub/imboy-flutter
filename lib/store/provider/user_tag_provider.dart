import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

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
  Future<bool> add({
    required String peerId,
    required List<String> tag,
  }) async {
    IMBoyHttpResponse resp = await post(API.userTagRelationAdd, data: {
      "scene": "friend",
      "objectId": peerId,
      "tag": tag,
    });
    debugPrint("UserTagProvider/add resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<bool> changeName({required String scene, required int tagId, required String tagName}) async {
    IMBoyHttpResponse resp = await post(API.userTagChangeName, data: {
      "scene": scene,
      "tagId": tagId,
      "tagName": tagName,
    });
    debugPrint("UserTagProvider/changeName resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<bool> deleteTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(API.userTagDelete, data: {
      "scene": scene,
      "tag": tagName,
    });
    debugPrint("UserTagProvider/delete resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  Future<Map<String, dynamic>?> pageRelation({
    int page = 1,
    int size = 10,
    String scene = '',
    String kwd = '',
  }) async {
    IMBoyHttpResponse resp = await get(API.userTagRelationPage, queryParameters: {
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
}
