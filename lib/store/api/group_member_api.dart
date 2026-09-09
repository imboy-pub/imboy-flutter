import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/app_loading.dart';

/// GroupMember API 失败（透传服务端 envelope code 与消息）。
class GroupMemberApiException implements Exception {
  final int code;
  final String message;

  const GroupMemberApiException(this.code, this.message);

  @override
  String toString() =>
      message.isEmpty ? 'GroupMemberApiException($code)' : message;
}

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
      // AppLoading.showBackendError(resp.msg);
      return null;
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  Future<Map<String, dynamic>?> join({
    required String gid,
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberJoin,
      data: {'gid': gid, 'member_uids': memberUserIds},
    );

    if (!resp.ok) {
      // 失败必须抛出并透传服务端消息：邀请向导把 join 包成 Future<void>
      // 可选关系，null 返回会把失败伪装成成功（批次152 实测）。
      throw GroupMemberApiException(resp.code, resp.msg);
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  Future<Map<String, dynamic>?> leave({
    required String gid,
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberLeave,
      data: {'gid': gid, 'member_uids': memberUserIds},
    );

    if (!resp.ok) {
      // 透出服务端中文错误消息（如"仅群主可踢出管理员"），页面层不再重复兜底
      if (resp.msg.isNotEmpty) {
        AppLoading.showBackendError(resp.msg);
      }
      return null;
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  Future<bool> changeAlias(String gid, String alias) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberAlias,
      data: {'gid': gid, 'alias': alias},
    );
    return resp.ok;
  }

  Future<Map<String, dynamic>?> sameGroup(String uid1, String uid2) async {
    IMBoyHttpResponse resp = await get(
      API.groupMemberSameGroup,
      queryParameters: {'uid1': uid1, 'uid2': uid2},
    );

    if (!resp.ok) {
      return null;
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  /// 更新群成员角色
  /// [gid] 群组ID
  /// [userId] 成员用户ID
  /// [role] 角色: 1 成员  2 嘉宾  3 管理员 4 群主
  Future<bool> updateRole({
    required String gid,
    required String userId,
    required int role,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberRole,
      data: {'gid': gid, 'user_id': userId, 'role': role},
    );

    // 透出服务端中文错误消息（如"仅群主可设置管理员"），页面层不再重复兜底
    if (!resp.ok && resp.msg.isNotEmpty) {
      AppLoading.showBackendError(resp.msg);
    }
    return resp.ok;
  }

  /// 禁言群成员。
  /// [gid] 群组 ID。
  /// [userId] 成员用户 ID。
  /// [duration] 禁言时长（秒），**必须 > 0**。
  ///
  /// 注意：后端 `group_member_handler.erl` 在 `Duration =< 0` 时直接返回错误
  /// `"禁言时长必须大于0"`，不会做解禁处理。取消禁言请用独立方法 [unmute]
  /// （slice-9a/9b 已落地）。
  ///
  /// 抛出 [ArgumentError]：当 `duration <= 0` 时；不发送任何网络请求。
  Future<bool> mute({
    required String gid,
    required String userId,
    required int duration,
  }) async {
    if (duration <= 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        '禁言时长必须大于 0 秒；取消禁言请使用独立的 unmute action',
      );
    }
    IMBoyHttpResponse resp = await post(
      API.groupMemberMute,
      data: {'gid': gid, 'user_id': userId, 'duration': duration},
    );

    // 透出服务端中文错误消息（如"禁言时长必须大于0"），页面层不再重复兜底
    if (!resp.ok && resp.msg.isNotEmpty) {
      AppLoading.showBackendError(resp.msg);
    }
    return resp.ok;
  }

  /// 解除群成员禁言。
  /// [gid] 群组 ID。
  /// [userId] 成员用户 ID。
  ///
  /// 对应后端（slice-9b）：`POST /api/v1/group_member/unmute`，将 `mute_until`
  /// 设为 0 / NULL 并广播 `group_member_mute` 通知（mute_until=0）让客户端
  /// 同步本地 Repo。
  Future<bool> unmute({required String gid, required String userId}) async {
    IMBoyHttpResponse resp = await post(
      API.groupMemberUnmute,
      data: {'gid': gid, 'user_id': userId},
    );

    // 透出服务端中文错误消息，页面层不再重复兜底
    if (!resp.ok && resp.msg.isNotEmpty) {
      AppLoading.showBackendError(resp.msg);
    }
    return resp.ok;
  }
}
