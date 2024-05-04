import 'package:flutter/foundation.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class GroupMemberProvider extends HttpClient {
  Future<Map<String, dynamic>?> page({
    required String gid,
    int page = 1,
    int size = 10,
  }) async {
    IMBoyHttpResponse resp = await get(API.groupMemberPage, queryParameters: {
      'gid': gid,
      'page': page,
      'size': size,
    });

    // debugPrint("GroupMemberProvider/page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>?> join(
      {required String gid, required List<String> memberUserIds}) async {
    IMBoyHttpResponse resp = await post(API.groupMemberJoin,
        data: {'gid': gid, 'member_uids': memberUserIds});

    debugPrint("GroupMemberProvider/join resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>?> leave(
      {required String gid, required List<String> memberUserIds}) async {
    IMBoyHttpResponse resp = await post(API.groupMemberLeave,
        data: {'gid': gid, 'member_uids': memberUserIds});

    debugPrint("GroupMemberProvider/leave resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }
}
