import 'package:flutter/foundation.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class GroupMemberApi extends HttpClient {
  Future<Map<String, dynamic>?> page({
    required String gid,
    int page = 1,
    int size = 10,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupMemberPage,
      queryParameters: {'gid': gid, 'page': page, 'size': size},
    );

    // debugPrint("GroupMemberApi/page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      // EasyLoading.showError(resp.msg);
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>?> join({
    required String gid,
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberJoin,
      data: {'gid': gid, 'member_uids': memberUserIds},
    );

    debugPrint("GroupMemberApi/join resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>?> leave({
    required String gid,
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberLeave,
      data: {'gid': gid, 'member_uids': memberUserIds},
    );

    debugPrint("GroupMemberApi/leave resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<bool> changeAlias(String gid, String alias) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberAlias,
      data: {'gid': gid, 'alias': alias},
    );
    debugPrint(
      "GroupMemberApi/changeAlias resp: ${resp.payload.toString()}",
    );
    return resp.ok;
  }

  Future<Map<String, dynamic>?> sameGroup(String uid1, String uid2) async {
    IMBoyHttpResponse resp = await get(
      API.groupMemberSameGroup,
      queryParameters: {'uid1': uid1, 'uid2': uid2},
    );

    debugPrint(
      "GroupMemberApi/sameGroup resp: ${resp.payload.toString()}",
    );
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }
}
