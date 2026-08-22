import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apply_friend_provider.g.dart';

/// 申请好友状态类
class ApplyFriendState {
  final String role; // all | just_chat
  final bool visibilityLook;
  final bool donotlethimlook;
  final bool donotlookhim;
  final String peerTag;

  const ApplyFriendState({
    this.role = 'all',
    this.visibilityLook = true,
    this.donotlethimlook = false,
    this.donotlookhim = false,
    this.peerTag = '',
  });

  ApplyFriendState copyWith({
    String? role,
    bool? visibilityLook,
    bool? donotlethimlook,
    bool? donotlookhim,
    String? peerTag,
  }) {
    return ApplyFriendState(
      role: role ?? this.role,
      visibilityLook: visibilityLook ?? this.visibilityLook,
      donotlethimlook: donotlethimlook ?? this.donotlethimlook,
      donotlookhim: donotlookhim ?? this.donotlookhim,
      peerTag: peerTag ?? this.peerTag,
    );
  }
}

/// 申请好友 Notifier
@riverpod
class ApplyFriendNotifier extends _$ApplyFriendNotifier {
  @override
  ApplyFriendState build() {
    return const ApplyFriendState();
  }

  /// 设置角色权限
  void setRole(String newRole) {
    state = state.copyWith(role: newRole);
    if (newRole == 'all') {
      state = state.copyWith(visibilityLook: true);
    } else {
      state = state.copyWith(
        visibilityLook: false,
        donotlethimlook: false,
        donotlookhim: false,
      );
    }
  }

  /// 切换"不让他看"
  void toggleDonotLetHimLook(bool value) {
    state = state.copyWith(donotlethimlook: value);
  }

  /// 切换"不看他"
  void toggleDonotLookHim(bool value) {
    state = state.copyWith(donotlookhim: value);
  }

  /// 更新标签
  void updateTag(String tag) {
    state = state.copyWith(peerTag: tag);
  }

  /// 申请成为好友
  Future<bool> apply({
    required String to,
    required String peerNickname,
    required String peerAvatar,
    required Map<String, dynamic> payload,
  }) async {
    // v2.0: 移除 msg_type 设置，由后端 friend_logic 添加 action 字段
    // payload["msg_type"] = "apply_friend"; // v1.0 旧逻辑
    int createdAt = DateTimeHelper.millisecond();
    Map<String, dynamic> msg = {
      "to": to,
      "payload": json.encode(payload),
      "created_at": createdAt,
    };

    AppLoading.show(status: t.chat.sending);

    try {
      IMBoyHttpResponse resp = await HttpClient.client.post(
        "${Env().apiBaseUrl}${API.addFriend}",
        data: msg,
        options: Options(contentType: "application/x-www-form-urlencoded"),
      );

      if (resp.ok) {
        Map<String, dynamic> saveData = {
          "uid": UserRepoLocal.to.currentUid,
          NewFriendRepo.from: UserRepoLocal.to.currentUid,
          NewFriendRepo.to: to,
          "nickname": peerNickname,
          "avatar": peerAvatar,
          "msg": payload["from"]["msg"] ?? "",
          "payload": json.encode(payload),
          "status": NewFriendStatus.waitingForValidation.index,
          NewFriendRepo.createdAt: createdAt,
        };

        // 单独 try：申请已经发到服务端了，本地落库失败不能被外层 catch 当成
        // 「网络失败」并 return false（会诱导用户重复申请）。但也不能静默 ——
        // 不 await 时异常会被吞，用户看到「已发送」，记录却根本没落库。
        try {
          await (NewFriendRepo()).save(saveData);
          AppLoading.showSuccess(t.main.sent);
        } catch (e) {
          iPrint("❌ [APPLY_FRIEND] 好友申请落库失败 to=$to error=$e");
          AppLoading.showError(t.common.saveFailedRetry);
        }
        return true;
      } else {
        // 服务端业务错误须透出真实信息：如 already_requested（申请实际已送达，
        // 网络抖动重试时常见）；统一显示「网络故障」会误导用户反复重试。
        // friend_handler 约定：msg=英文错误码，人类可读中文消息在 payload.field。
        final field = resp.payload is Map
            ? (resp.payload as Map)['field']
            : null;
        final serverMsg = field is String && field.isNotEmpty
            ? field
            : (resp.msg.isNotEmpty
                  ? resp.msg
                  : t.common.networkFailureTryAgain);
        AppLoading.showError(serverMsg);
        return false;
      }
    } catch (e) {
      iPrint("❌ [APPLY_FRIEND] 好友申请发送失败 to=$to error=$e");
      AppLoading.showError(t.common.networkFailureTryAgain);
      return false;
    }
  }
}
