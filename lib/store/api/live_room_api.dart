import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/live_room_model.dart';

class LiveRoomApi extends HttpClient {
  /// 获取直播中的房间列表（公开）
  Future<Map<String, dynamic>?> list({int page = 1, int size = 20}) async {
    IMBoyHttpResponse resp = await get(
      API.liveRoomList,
      queryParameters: {'page': page, 'size': size},
    );
    debugPrint("> on LiveRoomApi/list resp: ${resp.payload}");
    if (!resp.ok) return null;
    return resp.payload as Map<String, dynamic>?;
  }

  /// 获取我的直播间列表
  Future<Map<String, dynamic>?> myList({int page = 1, int size = 20}) async {
    IMBoyHttpResponse resp = await get(
      API.liveRoomMyList,
      queryParameters: {'page': page, 'size': size},
    );
    debugPrint("> on LiveRoomApi/myList resp: ${resp.payload}");
    if (!resp.ok) return null;
    return resp.payload as Map<String, dynamic>?;
  }

  /// 创建直播间
  Future<LiveRoomModel?> create({
    required String title,
    String cover = '',
    int tagId = 0,
    int scene = 0,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.liveRoomCreate,
      data: {'title': title, 'cover': cover, 'tag_id': tagId, 'scene': scene},
    );
    debugPrint("> on LiveRoomApi/create resp: ${resp.payload}");
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    return LiveRoomModel.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 开始直播
  Future<bool> start(String roomId) async {
    IMBoyHttpResponse resp = await post(
      API.liveRoomStart,
      data: {'room_id': roomId},
    );
    debugPrint("> on LiveRoomApi/start resp: ${resp.payload}");
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok;
  }

  /// 停止直播
  Future<bool> stop(String roomId) async {
    IMBoyHttpResponse resp = await post(
      API.liveRoomStop,
      data: {'room_id': roomId},
    );
    debugPrint("> on LiveRoomApi/stop resp: ${resp.payload}");
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok;
  }

  /// 获取直播间详情
  Future<LiveRoomModel?> detail(String roomId) async {
    IMBoyHttpResponse resp = await get(
      API.liveRoomDetail,
      queryParameters: {'room_id': roomId},
    );
    debugPrint("> on LiveRoomApi/detail resp: ${resp.payload}");
    if (!resp.ok) return null;
    return LiveRoomModel.fromJson(resp.payload as Map<String, dynamic>);
  }
}
