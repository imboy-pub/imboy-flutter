import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDialog, AlertDialog, TextButton;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/service/websocket_events.dart';

import 'package:imboy/page/group/group_detail/group_detail_service.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/page/contact/new_friend/new_friend_provider.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/modules/ops_governance/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/store/api/user_api.dart';

import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/routes.dart';

import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// S2C 消息处理服务（WebSocket API v2.0 格式）
///
/// v2.0 主要变更：
/// - action 字段在顶层（不再兼容旧格式）
/// - 使用 switch 语句处理不同的 action
/// - 提取各个 action 处理逻辑为独立方法
class MessageS2CService {
  static final _providerContainer = ProviderContainer();

  /// 处理 S2C 消息（WebSocket API v2.0 格式）
  ///
  /// v2.0 格式：
  /// - action 字段在顶层
  /// - 不再兼容旧格式（payload.msg_type）
  ///
  /// 消息格式示例：
  /// ```json
  /// {
  ///   "id": "msg_id",
  ///   "type": "S2C",
  ///   "action": "pull_offline_msg",
  ///   "from": "user_id",
  ///   "to": "user_id",
  ///   "payload": {...},
  ///   "server_ts": "1234567890"
  /// }
  /// ```
  static Future<void> switchS2C(Map data) async {
    // 安全日志：只输出消息类型，不输出完整数据
    final msgId = data['id'] ?? '';
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    bool autoAck = true;

    try {
      // v2.0: 从顶层读取 action 字段（不再兼容旧格式）
      final payloadMap =
          parseModelJsonMap(data['payload']) ?? <String, dynamic>{};

      // v2.0: action 必须在顶层，不存在则报错
      final action = data['action']?.toString() ?? '';
      if (action.isEmpty) {
        debugPrint("❌ [S2C] 缺少 action 字段: msgId=$msgId");
        return;
      }
      debugPrint("switchS2C action=$action, msgId=$msgId");

      // v2.0: 使用 switch 处理不同的 action（统一转小写，避免大小写问题）
      switch (action.toString().toLowerCase()) {
        case 'pull_offline_msg':
          await _handlePullOfflineMsg(data, payloadMap);
          break;
        case 'c2c_revoke':
          await _handleC2CRevoke(data, payloadMap, from, to);
          break;
        case 'c2c_del_everyone':
          await _handleC2CDelEveryone(data, payloadMap, from, to);
          break;
        case 'c2g_del_everyone':
          await _handleC2GDelEveryone(data, payloadMap);
          break;
        case 'c2g_del_for_me':
          // 暂不处理
          break;
        case 'group_member_join':
          await _handleGroupMemberJoin(data, payloadMap);
          break;
        case 'group_dissolve':
          await _handleGroupDissolve(payloadMap);
          break;
        case 'group_member_leave':
          await _handleGroupMemberLeave(data, payloadMap);
          break;
        case 'group_member_alias':
          // 暂不处理
          break;
        case 'user_cancel':
          // 当前用户的朋友user_id注销了
          await _handleUserCancel(data, payloadMap);
          break;
        case 'apply_friend':
          // 添加朋友申请
          await _providerContainer
              .read(newFriendProvider.notifier)
              .receivedAddFriend(data);
          break;
        case 'apply_friend_confirm':
          await _handleApplyFriendConfirm(data, payloadMap);
          break;
        case 'in_denylist':
          // 对方将我加入黑名单后： 消息已发出，但被对方拒收了。
          await _handleInDenylist(data, payloadMap);
          break;
        case 'not_a_friend':
          await _handleNotAFriend(data, payloadMap);
          break;
        case 'logged_another_device':
          autoAck = false;
          await _handleLoggedAnotherDevice(payloadMap);
          break;
        case 'please_refresh_token':
          autoAck = false;
          await _handlePleaseRefreshToken(payloadMap, msgId);
          break;
        case 'app_upgrade':
          await _handleAppUpgrade(payloadMap);
          break;
        case 'device_force_offline':
          await _handleDeviceForceOffline(payloadMap);
          break;
        case 'online':
          // 好友上线提醒
          await _handleUserOnline(data, payloadMap);
          break;
        case 'offline':
          // 好友下线提醒
          await _handleUserOffline(data, payloadMap);
          break;
        case 'hide':
          // 好友hide提醒
          await _handleUserHide(data, payloadMap);
          break;
        case 'e2ee_device_key_changed':
          // E2EE 设备密钥变更通知
          await _handleE2EEDeviceKeyChanged(payloadMap);
          break;
        // ==================== 频道消息处理 ====================
        case 'channel_message':
          // 频道消息推送
          await _handleChannelMessage(data, payloadMap);
          break;
        case 'channel_subscribed':
          // 频道订阅通知
          await _handleChannelSubscribed(payloadMap);
          break;
        case 'channel_unsubscribed':
          // 频道取消订阅通知
          await _handleChannelUnsubscribed(payloadMap);
          break;
        case 'channel_updated':
          // 频道信息更新
          await _handleChannelUpdated(payloadMap);
          break;
        case 'channel_message_deleted':
          await _handleChannelMessageDeleted(payloadMap);
          break;
        case 'channel_message_revoked':
          await _handleChannelMessageRevoked(payloadMap);
          break;
        case 'channel_deleted':
          // 频道删除通知
          await _handleChannelDeleted(payloadMap);
          break;
        case 'channel_invitation_created':
          await _handleChannelInvitationCreated(payloadMap);
          break;
        case 'channel_invitation_accepted':
          await _handleChannelInvitationAccepted(payloadMap);
          break;
        case 'channel_order_paid':
          await _handleChannelOrderPaid(payloadMap);
          break;
        case 'channel_unread_count':
          // 频道未读计数更新
          await _handleChannelUnreadCount(payloadMap);
          break;
        case 'user_muted':
          // 当前用户被禁言（消息频率异常等）
          await _handleUserMuted(payloadMap);
          break;
        case 'user_unmuted':
          // 当前用户禁言解除
          await _handleUserUnmuted(payloadMap);
          break;
        case 'moment_new':
        case 'moment_like':
        case 'moment_comment':
        case 'moment_deleted':
          await _handleMomentAction(action, payloadMap);
          break;
        default:
          debugPrint("⚠️ [S2C] 未知的 action: $action");
          break;
      }

      // 确认消息
      if (autoAck) {
        iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId");
        // 直接发送 ACK 确认
        AckManager.to.sendAckDirect('S2C', msgId);
      }
    } catch (e, s) {
      iPrint("switchS2C error: $e, $s");
    }
  }

  // ============================================
  // S2C Action 处理方法
  // ============================================

  /// 处理拉取离线消息
  ///
  /// Action: pull_offline_msg
  /// 触发时机：服务端通知客户端拉取离线消息
  /// 处理逻辑：发布离线消息拉取事件，由 MessageOfflineService 订阅处理
  static Future<void> _handlePullOfflineMsg(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    iPrint("pull_offline_msg 收到离线消息拉取指令，开始处理离线消息");

    // 发布离线消息拉取事件，由 MessageOfflineService 订阅处理
    // 异步处理，避免阻塞 S2C 消息确认
    AppEventBus.fire(
      OfflineMessagesPullRequestedEvent(source: 'S2C', reason: '服务端通知拉取离线消息'),
    );
  }

  /// 处理 C2C 消息撤回
  ///
  /// Action: c2c_revoke
  /// 触发时机：对端撤回了一条消息
  /// 处理逻辑：使用公共辅助类将消息转换为撤回提示，更新数据库，触发UI刷新
  static Future<void> _handleC2CRevoke(
    Map data,
    Map<String, dynamic> payload,
    String from,
    String to,
  ) async {
    final revokeMsgId = payload['old_msg_id'] ?? '';

    iPrint("收到对端撤回消息: revokeMsgId=$revokeMsgId");

    // 验证必需的字段
    if (revokeMsgId.isEmpty) {
      debugPrint("❌ [S2C_C2C_REVOKE] old_msg_id 为空，跳过处理");
      return;
    }

    // 查找要撤回的消息
    final messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    final oldMsg = await messageRepo.find(revokeMsgId);

    if (oldMsg != null) {
      iPrint("找到要撤回的消息: ${oldMsg.toJson()}");

      // 使用公共辅助类处理撤回（消除代码重复）
      await MessageActions.convertMessageToRevoked(
        originalMsg: oldMsg,
        repo: messageRepo,
        revokeUserId: from,
        originalText: payload['text'],
      );
    } else {
      iPrint("未找到要撤回的消息: $revokeMsgId");
    }
  }

  /// 处理 C2C 消息删除（双方）
  ///
  /// Action: c2c_del_everyone
  /// 触发时机：对端删除了一条消息（双方都删除）
  /// 处理逻辑：使用公共辅助类处理删除，触发UI更新
  static Future<void> _handleC2CDelEveryone(
    Map data,
    Map<String, dynamic> payload,
    String from,
    String to,
  ) async {
    final oldMsgId = payload['old_msg_id'] ?? '';

    // 使用公共辅助类处理删除（消除代码重复）
    await MessageActions.handleC2CDeleteMessage(
      oldMsgId: oldMsgId,
      from: from,
      to: to,
    );
  }

  /// 处理 C2G 消息删除（所有人）
  ///
  /// Action: c2g_del_everyone
  /// 触发时机：群组消息被删除（所有人可见）
  /// 处理逻辑：使用公共辅助类处理删除，触发UI更新
  static Future<void> _handleC2GDelEveryone(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final oldMsgId = payload['old_msg_id'] ?? '';
    final groupId = payload['to'] ?? '';

    // 使用公共辅助类处理删除（消除代码重复）
    await MessageActions.handleC2GDeleteMessage(
      oldMsgId: oldMsgId,
      groupId: groupId,
    );
  }

  /// 处理群组成员加入
  ///
  /// Action: group_member_join
  /// 触发时机：有新成员加入群组
  /// 处理逻辑：更新群组成员列表，触发UI更新
  static Future<void> _handleGroupMemberJoin(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final userId = data['from'];
    final nickname = payload['nickname'];
    final avatar = payload['avatar'];
    final account = payload['account'];
    final gid = payload['gid'];
    final userIdSum = payload['user_id_sum'] ?? 0;

    iPrint('🔔 [S2C] 收到 group_member_join 消息');
    iPrint('  ├─ userId: $userId');
    iPrint('  ├─ nickname: $nickname');
    iPrint('  ├─ gid: $gid');
    iPrint('  ├─ userIdSum: $userIdSum');
    iPrint('  └─ 完整 payload: $payload');

    final joinRes = await GroupListService().memberJoin(
      groupId: gid,
      userId: userId,
      userIdSum: userIdSum,
    );

    iPrint('📢 [S2C] 发布 join_group 事件到 ChatExtendEvent');

    AppEventBus.fire(
      ChatExtendEvent(
        type: 'join_group',
        payload: {
          'groupId': gid,
          'userId': userId,
          'isFirst': joinRes?['isFirst'] ?? false,
          'people': PeopleModel(
            id: userId,
            account: account,
            nickname: nickname,
            avatar: avatar,
          ),
        },
      ),
    );

    iPrint('✅ [S2C] group_member_join 事件处理完成');
  }

  /// 处理群组解散
  ///
  /// Action: group_dissolve
  /// 触发时机：群组被解散
  /// 处理逻辑：清理群组相关数据，更新UI
  static Future<void> _handleGroupDissolve(Map<String, dynamic> payload) async {
    final gid = payload['gid'];
    await GroupDetailService().cleanData(gid);
  }

  /// 处理群组成员离开
  ///
  /// Action: group_member_leave
  /// 触发时机：有成员离开群组
  /// 处理逻辑：更新群组成员列表，触发UI更新
  static Future<void> _handleGroupMemberLeave(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final userId = payload['leave_uid'];
    final gid = payload['gid'];
    final userIdSum = payload['user_id_sum'] ?? 0;

    await GroupListService().memberLeave(
      groupId: gid,
      userId: userId,
      userIdSum: userIdSum,
    );

    AppEventBus.fire(
      ChatExtendEvent(
        type: 'leave_group',
        payload: {
          'groupId': gid,
          'userId': userId,
          'people': PeopleModel(id: userId, account: ''),
        },
      ),
    );
  }

  /// 处理好友申请确认
  ///
  /// Action: apply_friend_confirm
  /// 触发时机：好友申请被确认
  /// 处理逻辑：保存好友信息，更新UI
  static Future<void> _handleApplyFriendConfirm(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    /*
       {
          "id": "afc_jp24wa_pjyv83",
          "type": "S2C",
          "from": "pjyv83",
          "to": "jp24wa",
          "payload": {
              "from": {
                  "source": "people_nearby",
                  "msg": "我是 leeyi109",
                  "remark": "leeyi10000",
                  "avatar": "http://a.imboy.pub/avatar/jp24wa.jpg?s=dev&a=2d098a62371bef21&v=175730",
                  "nickname": "leeyi109",
                  "role": "all",
                  "donotlookhim": false,
                  "donotlethimlook": false
              },
              "to": {
                  "remark": "leeyi109",
                  "avatar": "http://a.imboy.pub/avatar/0_pjyv83.jpg?s=dev&a=6273f2e63037bbaa&v=660682",
                  "nickname": "leeyi10000",
                  "role": "all",
                  "donotlookhim": false,
                  "donotlethimlook": false
              },
              "msg_type": "apply_friend_confirm"
          },
          "server_ts": "1681980840528"
      }
  */

    // 对端 的个人信息
    final json = {
      'id': data['from'], // 服务端对调了 from to，离线消息需要对调
      'account': payload['to']['account'],
      'nickname': payload['to']['nickname'],
      'avatar': payload['to']['avatar'],
      'sign': payload['to']['sign'],
      'gender': payload['to']['gender'],
      ContactRepo.tag: payload['to'][ContactRepo.tag] ?? '',
      'region': payload['to']['region'],
      'remark': payload['from']['remark'] ?? '', // from 给对方的备注
      'source': payload['from']['source'],
    };

    _providerContainer
        .read(contactProvider.notifier)
        .receivedConfirmFriend(json);

    // 修正好友申请状态
    await _providerContainer
        .read(newFriendProvider.notifier)
        .receivedConfirmFriend(true, data);
  }

  /// 处理异地登录
  ///
  /// Action: logged_another_device
  /// 触发时机：账号在其他设备登录
  /// 处理逻辑：强制退出当前设备登录，跳转到登录页
  static Future<void> _handleLoggedAnotherDevice(
    Map<String, dynamic> payload,
  ) async {
    final did = payload['did'] ?? '';
    if (did != deviceId) {
      try {
        await UserRepoLocal.to.quitLogin();

        // 使用延迟确保 quitLogin 完全执行完毕
        await Future.delayed(const Duration(milliseconds: 100));

        // 使用 go_router 进行导航
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // 使用 go_router 的 go 方法替代 Navigator.pushNamedAndRemoveUntil
          // go_router 会自动清除路由栈
          context.go(AppRoutes.signIn);
        }
      } catch (e) {
        iPrint("switchS2C error: $e");
        // 如果导航失败，尝试使用其他方式
        rethrow;
      }
    }
  }

  /// 处理 Token 刷新请求
  ///
  /// Action: please_refresh_token
  /// 触发时机：服务端要求客户端刷新访问令牌
  /// 处理逻辑：使用刷新令牌获取新的访问令牌
  static Future<void> _handlePleaseRefreshToken(
    Map<String, dynamic> payload,
    String msgId,
  ) async {
    iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId,false");

    // 直接发送 ACK 确认
    AckManager.to.sendAckDirect('S2C', msgId);

    final rtk = await UserRepoLocal.to.refreshToken;

    await UserApi.to.refreshAccessTokenApi(rtk, checkNewToken: true);
  }

  /// 处理应用升级
  ///
  /// Action: app_upgrade
  /// 触发时机：服务端通知客户端有新版本
  /// 处理逻辑：检查版本信息，显示升级提示页面
  static Future<void> _handleAppUpgrade(Map<String, dynamic> payload) async {
    final p = AppVersionApi();
    final info = await p.check(appVsn);
    final downLoadUrl = info['download_url'] ?? '';
    bool updatable = info['updatable'] ?? false;
    updatable = downLoadUrl.isEmpty ? false : updatable;

    if (updatable) {
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null) {
        await Navigator.of(context).push(
          CupertinoPageRoute(
            // "右滑返回上一页"功能
            builder: (_) => UpgradePage(
              version: info['vsn'],
              downLoadUrl: downLoadUrl,
              message: info['description'] ?? '',
              isForce: 1 == (info['force_update'] ?? 2) ? true : false,
            ),
          ),
        );
      }
    }
  }

  /// 处理设备强制下线
  ///
  /// Action: device_force_offline
  /// 触发时机：账号被服务端强制下线（如封号、违规等）
  /// 处理逻辑：显示提示信息，退出登录，跳转到登录页
  static Future<void> _handleDeviceForceOffline(
    Map<String, dynamic> payload,
  ) async {
    final byName = payload['by_name'] ?? '';

    // 优先弹窗提示来源设备；若无可用 context 则忽略弹窗
    try {
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: Text(t.offlineNotification),
            content: Text(t.forcedOfflineByDevice(device: byName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(t.buttonOk),
              ),
            ],
          ),
        );
      }
    } catch (_) {}

    // 统一执行退登与清理
    try {
      AppEventBus.fire(WebSocketForceCloseEvent(permanent: true));
    } catch (_) {}

    EasyLoading.showSuccess(t.confirmRecoverSuccess);
    await UserRepoLocal.to.quitLogin();

    // 使用延迟确保 quitLogin 完全执行完毕
    await Future.delayed(const Duration(milliseconds: 100));

    // 使用 go_router 进行导航
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go(AppRoutes.signIn);
    }
  }

  ///
  /// Action: not_a_friend
  /// 触发时机：尝试向非好友用户发送消息
  /// 处理逻辑：使用公共辅助类处理非好友错误
  static Future<void> _handleNotAFriend(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final msgId = parseModelNullableString(data['id']);
    final msgType = data['type']?.toString() ?? 'C2C';

    // 使用公共辅助类处理非好友错误（消除代码重复）
    await MessageActions.handleNotAFriendError(msgId: msgId, msgType: msgType);
  }

  ///
  /// Action: in_denylist
  /// 触发时机：对方将您加入黑名单
  /// 处理逻辑：使用公共辅助类处理黑名单错误
  static Future<void> _handleInDenylist(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final msgId = parseModelNullableString(data['id']);
    final msgType = data['type']?.toString() ?? 'C2C';

    // 使用公共辅助类处理黑名单错误（消除代码重复）
    await MessageActions.handleDenylistError(msgId: msgId, msgType: msgType);
  }

  /// 处理用户注销
  ///
  /// Action: user_cancel
  /// 触发时机：好友账号注销
  /// 处理逻辑：发布用户注销事件，由UI层订阅显示提示
  static Future<void> _handleUserCancel(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final userId = data['from']?.toString() ?? '';
    final nickname = payload['nickname']?.toString();

    iPrint('[S2C] user_cancel: userId=$userId, nickname=$nickname');

    // 发布用户注销事件
    AppEventBus.fire(UserCancelEvent(userId: userId, nickname: nickname));

    // 可选：从联系人列表中移除或标记为已注销
    // await ContactRepo.to.markAsDeleted(userId);
  }

  /// 处理用户状态变更（上线/下线/隐身）
  static Future<void> _handleUserStatusChange(
    Map data,
    Map<String, dynamic> payload,
    String status,
  ) async {
    final userId = data['from']?.toString() ?? '';
    final nickname = payload['nickname']?.toString();

    iPrint('[S2C] $status: userId=$userId, nickname=$nickname');

    AppEventBus.fire(
      UserStatusChangeEvent(userId: userId, status: status, nickname: nickname),
    );
  }

  static Future<void> _handleUserOnline(
    Map data,
    Map<String, dynamic> payload,
  ) => _handleUserStatusChange(data, payload, 'online');

  static Future<void> _handleUserOffline(
    Map data,
    Map<String, dynamic> payload,
  ) => _handleUserStatusChange(data, payload, 'offline');

  static Future<void> _handleUserHide(Map data, Map<String, dynamic> payload) =>
      _handleUserStatusChange(data, payload, 'hide');

  /// 处理 E2EE 设备密钥变更通知
  ///
  /// Action: e2ee_device_key_changed
  /// 触发时机：好友的设备 E2EE 密钥发生变化（如重新安装应用）
  /// 处理逻辑：清除该好友的公钥缓存，下次发送消息时自动获取新密钥
  static Future<void> _handleE2EEDeviceKeyChanged(
    Map<String, dynamic> payload,
  ) async {
    final uid = payload['uid']?.toString() ?? '';
    final deviceId = payload['device_id']?.toString() ?? '';
    final deviceType = payload['device_type']?.toString() ?? '';
    final keyId = payload['key_id']?.toString() ?? '';

    iPrint(
      '[S2C] e2ee_device_key_changed: uid=$uid, deviceId=$deviceId, deviceType=$deviceType, keyId=$keyId',
    );

    // 清除该用户的公钥缓存
    if (uid.isNotEmpty) {
      E2EEService.clearUserKeyCache(uid);
      iPrint('🔑 E2EE: 已清除用户 $uid 的公钥缓存（密钥已变更）');
    }
  }

  /// 处理用户被禁言通知
  ///
  /// Action: user_muted
  /// 触发时机：后端 msg_rate_logic 检测到消息频率异常，自动禁言
  /// payload: { mute_until: 毫秒时间戳, reason: "消息频率异常" , conversation_id: "可选" }
  static Future<void> _handleUserMuted(Map<String, dynamic> payload) async {
    final muteUntil = payload['mute_until'] ?? 0;
    final reason = payload['reason']?.toString();
    final conversationId = payload['conversation_id']?.toString();

    iPrint(
      '[S2C] user_muted: muteUntil=$muteUntil, reason=$reason, conversationId=$conversationId',
    );

    // 显示禁言提示
    final event = UserMutedEvent(
      muteUntilMs: muteUntil is int ? muteUntil : int.tryParse('$muteUntil') ?? 0,
      reason: reason,
      conversationId: conversationId,
    );

    // 发布事件供 UI 层订阅
    AppEventBus.fire(event);

    // 同时用 EasyLoading 显示即时提示
    final minutes = event.remainingMinutes;
    if (minutes > 0) {
      EasyLoading.showInfo(
        t.youAreMutedWithTime(minutes: '$minutes'),
        duration: const Duration(seconds: 3),
      );
    } else {
      EasyLoading.showInfo(
        t.youAreMuted,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// 处理用户禁言解除通知
  ///
  /// Action: user_unmuted
  /// 触发时机：禁言到期或管理员手动解除禁言
  static Future<void> _handleUserUnmuted(Map<String, dynamic> payload) async {
    final conversationId = payload['conversation_id']?.toString();

    iPrint('[S2C] user_unmuted: conversationId=$conversationId');

    AppEventBus.fire(UserUnmutedEvent(conversationId: conversationId));
  }

  // ============================================
  // 频道消息处理方法
  // ============================================

  /// 处理朋友圈相关 S2C 通知
  static Future<void> _handleMomentAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final momentId = payload['moment_id']?.toString() ?? '';
    iPrint('[S2C] $action: momentId=$momentId');
    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: action,
        momentId: momentId,
        payload: payload,
      ),
    );
  }

  /// 处理频道消息推送
  ///
  /// Action: channel_message
  /// 触发时机：订阅的频道发布新消息
  /// 处理逻辑：保存消息到本地，更新未读计数
  static Future<void> _handleChannelMessage(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    iPrint('[S2C] channel_message: 收到频道消息');

    try {
      await ChannelService.to.handleChannelMessage(payload);
    } catch (e) {
      debugPrint('[S2C] channel_message 处理失败: $e');
    }
  }

  /// 处理频道订阅通知
  ///
  /// Action: channel_subscribed
  /// 触发时机：用户成功订阅频道
  /// 处理逻辑：更新本地订阅状态
  static Future<void> _handleChannelSubscribed(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_subscribed: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelSubscribed(payload);
    } catch (e) {
      debugPrint('[S2C] channel_subscribed 处理失败: $e');
    }
  }

  /// 处理频道取消订阅通知
  ///
  /// Action: channel_unsubscribed
  /// 触发时机：用户取消订阅频道
  /// 处理逻辑：更新本地订阅状态
  static Future<void> _handleChannelUnsubscribed(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_unsubscribed: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelUnsubscribed(payload);
    } catch (e) {
      debugPrint('[S2C] channel_unsubscribed 处理失败: $e');
    }
  }

  /// 处理频道信息更新通知
  ///
  /// Action: channel_updated
  /// 触发时机：频道信息被管理员更新
  /// 处理逻辑：更新本地频道信息
  static Future<void> _handleChannelUpdated(
    Map<String, dynamic> payload,
  ) async {
    iPrint('[S2C] channel_updated: 收到频道更新通知');

    try {
      await ChannelService.to.handleChannelUpdated(payload);
    } catch (e) {
      debugPrint('[S2C] channel_updated 处理失败: $e');
    }
  }

  static Future<void> _handleChannelMessageDeleted(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    final messageId = payload['message_id']?.toString() ?? '';
    iPrint(
      '[S2C] channel_message_deleted: channelId=$channelId, messageId=$messageId',
    );

    try {
      await ChannelService.to.handleChannelMessageDeleted(payload);
    } catch (e) {
      debugPrint('[S2C] channel_message_deleted 处理失败: $e');
    }
  }

  static Future<void> _handleChannelMessageRevoked(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    final messageId = payload['message_id']?.toString() ?? '';
    iPrint(
      '[S2C] channel_message_revoked: channelId=$channelId, messageId=$messageId',
    );

    try {
      await ChannelService.to.handleChannelMessageRevoked(payload);
    } catch (e) {
      debugPrint('[S2C] channel_message_revoked 处理失败: $e');
    }
  }

  /// 处理频道删除通知
  ///
  /// Action: channel_deleted
  /// 触发时机：频道被创建者删除
  /// 处理逻辑：删除本地频道数据
  static Future<void> _handleChannelDeleted(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_deleted: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelDeleted(payload);
    } catch (e) {
      debugPrint('[S2C] channel_deleted 处理失败: $e');
    }
  }

  static Future<void> _handleChannelInvitationCreated(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_invitation_created: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelInvitationCreated(payload);
    } catch (e) {
      debugPrint('[S2C] channel_invitation_created 处理失败: $e');
    }
  }

  static Future<void> _handleChannelInvitationAccepted(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_invitation_accepted: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelInvitationAccepted(payload);
    } catch (e) {
      debugPrint('[S2C] channel_invitation_accepted 处理失败: $e');
    }
  }

  static Future<void> _handleChannelOrderPaid(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_order_paid: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelOrderPaid(payload);
    } catch (e) {
      debugPrint('[S2C] channel_order_paid 处理失败: $e');
    }
  }

  /// 处理频道未读计数更新
  ///
  /// Action: channel_unread_count
  /// 触发时机：频道未读消息数变化
  /// 处理逻辑：更新本地未读计数，发布事件通知 UI 刷新
  static Future<void> _handleChannelUnreadCount(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    final unreadCount = parseModelInt(payload['unread_count']);
    iPrint(
      '[S2C] channel_unread_count: channelId=$channelId, count=$unreadCount',
    );

    try {
      // 更新本地未读计数
      await ChannelService.to.updateUnreadCount(channelId, unreadCount);

      // 发布事件通知 UI 刷新
      AppEventBus.fire(
        ChannelUnreadCountUpdatedEvent(
          channelId: channelId,
          unreadCount: unreadCount,
        ),
      );
    } catch (e) {
      debugPrint('[S2C] channel_unread_count 处理失败: $e');
    }
  }
}
