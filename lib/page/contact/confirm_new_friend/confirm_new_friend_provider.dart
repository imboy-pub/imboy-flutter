import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';

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

    AppLoading.show(status: t.chat.sending);

    try {
      IMBoyHttpResponse resp = await HttpClient.client.post(
        "${Env().apiBaseUrl}${API.confirmFriend}",
        data: msg,
        options: Options(contentType: "application/x-www-form-urlencoded"),
      );

      if (resp.ok) {
        AppLoading.showSuccess(t.main.sent);

        // 修正好友申请状态
        await _receivedConfirmFriend({"from": to, "to": from});

        // 存储好友信息
        _storeContactInfo(resp.payload as Map<String, dynamic>?);

        // 同步触发新好友提醒计数重新计算。
        // ⚠️ 不能再用 Future.delayed：confirmNewFriendProvider 是 autoDispose，
        // 页面确认后 pop → provider 被立即 dispose → 延迟回调里 ref.mounted
        // 恒为 false → countReminders 被跳过 → 角标 stale 直到重启/切页。
        // 本方法执行期间 notifier 存活，ref 有效，且 _receivedConfirmFriend
        // 已 await 完成（status=1 已落库），此处查询结果必然最新。
        ref.read(newFriendRemindProvider.notifier).countReminders();

        return true;
      } else {
        // 服务端业务错误须透出真实信息：如 no_pending_request（申请已被确认/
        // 网络抖动重试时常见）；统一显示「网络故障」会误导用户反复重试。
        // friend_handler 约定：msg=英文错误码，人类可读中文消息在 payload.field。
        // 同 apply_friend_provider 的 else 分支契约，避免 DRY 漂移。
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
      iPrint("❌ [CONFIRM_FRIEND] 好友确认失败 from=$from to=$to error=$e");
      AppLoading.showError(t.common.networkFailureTryAgain);
      return false;
    }
  }

  /// 收到确认好友
  Future<void> _receivedConfirmFriend(Map<String, dynamic> data) async {
    String from = data["from"] as String;
    String to = data["to"] as String;
    NewFriendRepo repo = NewFriendRepo();
    var obj = await repo.findByFromTo(to, from);
    iPrint(
      "> on _receivedConfirmFriend data=${json.encode(data)} obj=${obj?.from}/${obj?.to}/${obj?.status}",
    );
    if (obj != null) {
      // 更新状态为已添加
      int n = await repo.update({
        "from": to,
        "to": from,
        "status": 1, // NewFriendStatus.added.index
      });
      iPrint("> _receivedConfirmFriend update rows=$n");
    }
  }

  /// 存储联系人信息
  ///
  /// accept 成功后把对方写入本地 contact 表，保证通讯录 findFriend
  /// (WHERE is_friend=1) 能查到。
  ///
  /// 历史根因（已修复）：
  ///   ① 后端 /api/v1/friend/confirm 响应用 `id` 键，旧代码读 `peerId` →
  ///     永远 null → 整个函数体被跳过，accept 后完全不落库。
  ///   ② 即便落库，ContactRepo.update 仅在 payload.containsKey(is_friend)
  ///     时才写 is_friend；后端响应不带该字段 → is_friend 保持 0 →
  ///     通讯录查不到。
  /// 修复：兼容 id/peerId 两种键名；落库 map 显式注入 is_friend=1 与
  ///       is_from=1（accept 语义即"我确认了对方申请"）。
  Future<void> _storeContactInfo(Map<String, dynamic>? payload) async {
    if (payload != null && payload.isNotEmpty) {
      try {
        // 兼容后端 `id`（friend_logic.erl confirm_friend_resp 实际契约）
        // 与 `peerId`（部分旧路径）两种键名
        final rawPeerId = payload['peerId'] ?? payload['id'];
        final peerId = rawPeerId?.toString();
        if (peerId == null || peerId.isEmpty) {
          return;
        }
        final existing = await ContactRepo().findByUid(
          peerId,
          autoFetch: false,
        );
        // 落库 map：显式注入 is_friend=1，绕过 update() 的 containsKey 门槛
        final Map<String, dynamic> data = Map<String, dynamic>.from(payload)
          ..[ContactRepo.isFriend] = 1
          ..[ContactRepo.isFrom] = 1;
        if (existing != null) {
          // 更新现有联系人（含非好友缓存提升为好友）
          await ContactRepo().update(data);
        } else {
          // 插入新联系人
          await ContactRepo().insert(
            ContactModel.fromMap({...data, 'id': peerId}),
          );
        }
      } catch (e) {
        // 忽略错误，因为联系人信息可能在其他地方处理
        // debugPrint('存储联系人信息失败: $e');
      }
    }
  }
}
