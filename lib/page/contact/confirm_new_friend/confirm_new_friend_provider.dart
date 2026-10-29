import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
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
    final owner = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;
    bool current() =>
        ref.mounted &&
        owner.isNotEmpty &&
        UserRepoLocal.to.currentUid == owner &&
        UserRepoLocal.to.sessionGeneration == generation &&
        !UserRepoLocal.to.isAuthTransitioning;
    if (!current() || to != owner) {
      await AppLoading.dismiss();
      return false;
    }
    var accepted = false;

    try {
      IMBoyHttpResponse resp = await HttpClient.client.post(
        "${Env().apiBaseUrl}${API.confirmFriend}",
        data: msg,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          responseDecoder: channelIdResponseDecoder(
            ChannelResponseShape.contact,
          ),
          extra: {httpNoAutoRetry: true},
        ),
      );

      if (!current()) {
        await AppLoading.dismiss();
        return false;
      }
      if (resp.ok) {
        accepted = true;

        // 修正好友申请状态
        await _receivedConfirmFriend({"from": to, "to": from}, owner, current);
        if (!current()) {
          await AppLoading.dismiss();
          return false;
        }

        // 存储好友信息
        await _storeContactInfo(
          resp.payload is Map<String, dynamic>
              ? resp.payload as Map<String, dynamic>
              : null,
          from,
          owner,
          current,
        );
        if (!current()) {
          await AppLoading.dismiss();
          return false;
        }
        AppLoading.showSuccess(t.main.sent);

        // 同步触发新好友提醒计数重新计算。
        // ⚠️ 不能再用 Future.delayed：confirmNewFriendProvider 是 autoDispose，
        // 页面确认后 pop → provider 被立即 dispose → 延迟回调里 ref.mounted
        // 恒为 false → countReminders 被跳过 → 角标 stale 直到重启/切页。
        // 本方法执行期间 notifier 存活，ref 有效，且 _receivedConfirmFriend
        // 已 await 完成（status=1 已落库），此处查询结果必然最新。
        ref.read(newFriendRemindProvider.notifier).countReminders();

        return true;
      } else {
        AppLoading.showError(t.common.friendConfirmResultUnknown);
        return false;
      }
    } catch (e) {
      iPrint("❌ [CONFIRM_FRIEND] 好友确认失败 from=$from to=$to error=$e");
      if (current()) {
        AppLoading.showError(
          accepted
              ? t.common.denylistLocalNotSynced
              : t.common.friendConfirmResultUnknown,
        );
      } else {
        await AppLoading.dismiss();
      }
      return false;
    }
  }

  /// 收到确认好友
  Future<void> _receivedConfirmFriend(
    Map<String, dynamic> data,
    String owner,
    bool Function() current,
  ) async {
    String from = data["from"] as String;
    String to = data["to"] as String;
    NewFriendRepo repo = NewFriendRepo();
    var obj = await repo.findByFromTo(to, from, account: owner);
    if (!current()) {
      throw StateError('Session changed during friend confirmation');
    }
    iPrint(
      "> on _receivedConfirmFriend data=${json.encode(data)} obj=${obj?.from}/${obj?.to}/${obj?.status}",
    );
    if (obj != null) {
      // 更新状态为已添加
      int n = await repo.update({
        "from": to,
        "to": from,
        "status": 1, // NewFriendStatus.added.index
      }, account: owner);
      if (n == 0) throw StateError('Friend request was not updated');
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
  Future<void> _storeContactInfo(
    Map<String, dynamic>? payload,
    String from,
    String owner,
    bool Function() current,
  ) async {
    if (payload != null && payload.isNotEmpty) {
      // 兼容后端 `id`（friend_logic.erl confirm_friend_resp 实际契约）
      // 与 `peerId`（部分旧路径）两种键名
      final rawPeerId = payload['peerId'] ?? payload['id'];
      final peerId = channelDecimalId(rawPeerId);
      if (peerId == null || peerId != from) {
        throw const FormatException('Invalid confirmed peer identity');
      }
      final existing = await ContactRepo().findByUid(
        peerId,
        autoFetch: false,
        account: owner,
      );
      if (!current()) throw StateError('Session changed during contact lookup');
      // 落库 map：显式注入 is_friend=1，绕过 update() 的 containsKey 门槛
      final Map<String, dynamic> data = Map<String, dynamic>.from(payload)
        ..[ContactRepo.isFriend] = 1
        ..[ContactRepo.isFrom] = 1;
      if (existing != null) {
        // 更新现有联系人（含非好友缓存提升为好友）
        if (await ContactRepo().update(data, account: owner) == 0) {
          throw StateError('Confirmed contact was not updated');
        }
      } else {
        // 插入新联系人
        await ContactRepo().insert(
          ContactModel.fromMap({...data, 'id': peerId}),
          account: owner,
        );
      }
      return;
    }
    throw const FormatException('Missing confirmed contact');
  }
}
