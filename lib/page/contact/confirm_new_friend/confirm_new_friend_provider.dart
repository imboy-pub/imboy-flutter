import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'confirm_new_friend_provider.g.dart';

/// 确认新好友状态类
class ConfirmNewFriendState {
  final String role; // all | just_chat
  final bool visibilityLook;
  final bool donotlethimlook;
  final bool donotlookhim;
  final String peerTag;

  const ConfirmNewFriendState({
    this.role = 'all',
    this.visibilityLook = true,
    this.donotlethimlook = false,
    this.donotlookhim = false,
    this.peerTag = '',
  });

  ConfirmNewFriendState copyWith({
    String? role,
    bool? visibilityLook,
    bool? donotlethimlook,
    bool? donotlookhim,
    String? peerTag,
  }) {
    return ConfirmNewFriendState(
      role: role ?? this.role,
      visibilityLook: visibilityLook ?? this.visibilityLook,
      donotlethimlook: donotlethimlook ?? this.donotlethimlook,
      donotlookhim: donotlookhim ?? this.donotlookhim,
      peerTag: peerTag ?? this.peerTag,
    );
  }
}

/// 确认新好友 Notifier
@riverpod
class ConfirmNewFriendNotifier extends _$ConfirmNewFriendNotifier {
  @override
  ConfirmNewFriendState build() {
    return const ConfirmNewFriendState();
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

  /// 确认申请成为好友
  Future<bool> confirm({
    required String from,
    required String to,
    required Map<String, dynamic> payload,
  }) async {
    // v2.0: 移除 msg_type 设置，由后端 friend_logic 添加 action 字段
    // payload["msg_type"] = "apply_friend_confirm"; // v1.0 旧逻辑
    Map<String, dynamic> msg = {
      "from": from,
      "to": to,
      "payload": json.encode(payload),
    };

    EasyLoading.show(status: t.sending);

    try {
      IMBoyHttpResponse resp = await HttpClient.client.post(
        "${Env().apiBaseUrl}${API.confirmFriend}",
        data: msg,
        options: Options(contentType: "application/x-www-form-urlencoded"),
      );

      if (resp.ok) {
        EasyLoading.showSuccess(t.sent);

        // 修正好友申请状态
        await _receivedConfirmFriend({"from": to, "to": from});

        // 存储好友信息
        _storeContactInfo(resp.payload);

        // 触发新好友提醒计数重新计算
        Future.delayed(const Duration(seconds: 1), () {
          // 触发新好友提醒计数重新计算
          // 需要通过 WidgetRef 访问，这里暂时注释
          // ref.read(newFriendRemindProvider.notifier).countReminders();
        });

        return true;
      } else {
        EasyLoading.showError(t.networkFailureTryAgain);
        return false;
      }
    } catch (e) {
      EasyLoading.showError(t.networkFailureTryAgain);
      return false;
    }
  }

  /// 收到确认好友
  Future<void> _receivedConfirmFriend(Map<String, dynamic> data) async {
    String from = data["from"];
    String to = data["to"];
    NewFriendRepo repo = NewFriendRepo();
    var obj = await repo.findByFromTo(to, from);
    if (obj != null) {
      // 更新状态为已添加
      await repo.update({
        "from": to,
        "to": from,
        "status": 1, // NewFriendStatus.added.index
      });
    }
  }

  /// 存储联系人信息
  Future<void> _storeContactInfo(Map<String, dynamic>? payload) async {
    if (payload != null && payload.isNotEmpty) {
      // 使用 ContactRepo 的方法存储联系人信息
      // 先尝试更新，如果不存在则插入
      try {
        final peerId = payload['peerId'] as String?;
        if (peerId != null && peerId.isNotEmpty) {
          final existing = await ContactRepo().findByUid(peerId);
          if (existing != null) {
            // 更新现有联系人
            await ContactRepo().update(payload);
          } else {
            // 插入新联系人
            await ContactRepo().insert(
              ContactModel(
                peerId: peerId,
                nickname: payload['nickname'] ?? '',
                avatar: payload['avatar'] ?? '',
              ),
            );
          }
        }
      } catch (e) {
        // 忽略错误，因为联系人信息可能在其他地方处理
        // debugPrint('存储联系人信息失败: $e');
      }
    }
  }
}
