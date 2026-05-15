import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/datetime.dart';
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

    EasyLoading.show(status: t.chat.sending);

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

        (NewFriendRepo()).save(saveData);
        EasyLoading.showSuccess(t.main.sent);
        return true;
      } else {
        EasyLoading.showError(t.common.networkFailureTryAgain);
        return false;
      }
    } catch (e) {
      EasyLoading.showError(t.common.networkFailureTryAgain);
      return false;
    }
  }
}
