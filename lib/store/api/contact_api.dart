import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactApi extends HttpClient {
  Future<List<dynamic>> listFriend() async {
    IMBoyHttpResponse resp = await get(API.friendList);
    // 失败必须抛出（fail-open 改造）：HttpClient 从不抛异常，静默 return []
    // 会把网络失败压成「没有好友」。唯一调用方
    // contact_provider._syncFriendFromServer 有 catch 并留日志。
    resp.throwIfFailed();
    // [DIAG #19] API 层：响应形状与 friend 数组长度
    final payload = resp.payload;
    final friendRaw = (payload is Map) ? payload['friend'] : null;
    if (friendRaw is! List) {
      return [];
    }
    return friendRaw;
  }

  /// 同步非好友联系人信息
  Future<ContactModel?> syncByUid(String uid) async {
    IMBoyHttpResponse resp = await get(
      API.userShow,
      queryParameters: {"id": uid},
    );
    ContactModel? ct;
    if (kDebugMode) {}
    if (resp.ok && resp.payload.isNotEmpty == true) {
      try {
        final payload = IMBoyHttpResponse.payloadAsMap(resp.payload);
        await (ContactRepo()).save(payload);
        ct = ContactModel.fromMap(payload);
      } on Exception {
        if (kDebugMode) {}
      }
    } else {
      if (kDebugMode) {}
    }
    return ct;
  }

  /// 删除联系人
  Future<bool> changeRemark(String uid, String remark) async {
    IMBoyHttpResponse resp = await post(
      API.friendChangeRemark,
      data: {'uid': uid, 'remark': remark},
    );
    if (kDebugMode) {}
    return resp.ok;
  }

  /// 删除联系人
  Future<bool> deleteContact(String uid) async {
    IMBoyHttpResponse resp = await post(API.deleteFriend, data: {'uid': uid});
    if (kDebugMode) {}
    return resp.ok;
  }
}
