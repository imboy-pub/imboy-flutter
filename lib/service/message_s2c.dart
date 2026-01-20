import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDialog, AlertDialog, TextButton;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/websocket_events.dart';

import 'package:imboy/page/group/group_detail/group_detail_service.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
// TODO: 迁移到 Riverpod - new_friend_logic 已迁移为 new_friend_provider
// import 'package:imboy/page/contact/new_friend/new_friend_logic.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/store/api/app_version_api.dart';
import 'package:imboy/store/api/user_api.dart';

import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/routes.dart';

/// S2C 消息处理服务（WebSocket API v2.0 格式）
///
/// v2.0 主要变更：
/// - action 字段从 payload.msg_type 移到顶层 action
/// - 使用 switch 语句处理不同的 action
/// - 提取各个 action 处理逻辑为独立方法
/// - 支持向后兼容（自动检测旧格式）
class MessageS2CService {
  static final _providerContainer = ProviderContainer();

  /// 处理 S2C 消息（WebSocket API v2.0 格式）
  ///
  /// v2.0 变更：
  /// - action 字段从 payload.msg_type 移到顶层 action
  /// - 使用 switch 语句处理不同的 action
  /// - 提取各个 action 处理逻辑为独立方法
  /// - 向后兼容：自动检测旧格式（从 payload.msg_type 读取）
  ///
  /// 消息格式示例：
  /// ```json
  /// {
  ///   "id": "msg_id",
  ///   "type": "S2C",
  ///   "action": "pull_offline_msg",  // v2.0：顶层 action
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
      // v2.0: 从顶层读取 action 字段（兼容旧格式：从 payload.msg_type 读取）
      final payload = data['payload'] ?? {};
      final Map<String, dynamic> payloadMap =
          payload is String ? json.decode(payload) : payload as Map<String, dynamic>;

      // v2.0 格式：data['action']
      // v1.x 兼容：payloadMap['msg_type']
      final action = data['action'] ?? payloadMap['msg_type'] ?? '';
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
          // TODO: 实现 user_cancel 处理
          debugPrint("TODO: user_cancel 需要实现处理逻辑");
          break;
        case 'apply_friend':
          // 添加朋友申请
          // TODO: 迁移到 Riverpod - 需要使用 newFriendProvider
          debugPrint("TODO: apply_friend 需要迁移到 Riverpod");
          break;
        case 'apply_friend_confirm':
          await _handleApplyFriendConfirm(data, payloadMap);
          break;
        case 'in_denylist':
          // 对方将我加入黑名单后： 消息已发出，但被对方拒收了。
          // TODO: 通过事件总线处理系统提示设置
          debugPrint("TODO: in_denylist 需要迁移到事件总线或 Provider");
          break;
        case 'not_a_friend':
          // TODO: 通过事件总线处理系统提示设置
          debugPrint("TODO: not_a_friend 需要迁移到事件总线或 Provider");
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
          // TODO: 实现 online 处理
          break;
        case 'offline':
          // 好友下线提醒
          // TODO: 实现 offline 处理
          break;
        case 'hide':
          // 好友hide提醒
          // TODO: 实现 hide 处理
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
      OfflineMessagesPullRequestedEvent(
        source: 'S2C',
        reason: '服务端通知拉取离线消息',
      ),
    );
  }

  /// 处理 C2C 消息撤回
  ///
  /// Action: c2c_revoke
  /// 触发时机：对端撤回了一条消息
  /// 处理逻辑：将消息转换为撤回提示，更新数据库，触发UI刷新
  static Future<void> _handleC2CRevoke(
    Map data,
    Map<String, dynamic> payload,
    String from,
    String to,
  ) async {
    final revokeMsgId = payload['old_msg_id'] ?? '';
    final peerId = UserRepoLocal.to.currentUid == from ? to : from;

    iPrint("收到对端撤回消息: revokeMsgId=$revokeMsgId, peerId=$peerId");

    // 验证必需的字段
    if (revokeMsgId.isEmpty) {
      debugPrint("❌ [S2C_C2C_REVOKE] old_msg_id 为空，跳过处理");
      return;
    }

    // 查找会话
    final conversationRepo = ConversationRepo();
    final conversation = await conversationRepo.findByPeerId(
      'C2C',
      peerId,
    );

    if (conversation != null) {
      // 查找要撤回的消息
      final messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
      final oldMsg = await messageRepo.find(revokeMsgId);

      if (oldMsg != null) {
        iPrint("找到要撤回的消息: ${oldMsg.toJson()}");

        // 转换为撤回消息
        final revokePayload = {
          'msg_type': 'custom',
          'custom_type': 'peer_revoked', // 标记为对方撤回
          'text': payload['text'] ?? '撤回的消息',
          'original_type': oldMsg.payload['msg_type'] ?? 'TextMessage',
          'revoke_time':
              payload['revoke_time'] ?? DateTimeHelper.millisecond(),
          'revoke_user': from, // 记录撤回操作的用户ID
        };

        // 更新消息
        final res = await messageRepo.update({
          'id': revokeMsgId,
          'payload': json.encode(revokePayload),
          'status': 20, // 设置为已读状态
        });

        iPrint("撤回消息数据库更新结果: $res, 消息ID: $revokeMsgId");

        if (res > 0) {
          // 重新获取更新后的消息
          final updatedMsg = await messageRepo.find(revokeMsgId);
          if (updatedMsg != null) {
            iPrint("撤回消息更新成功: ${updatedMsg.toJson()}");

            // 触发UI更新事件
            AppEventBus.fire(
              ChatExtendEvent(
                type: 'revoke_msg',
                payload: {
                  'conversation': conversation,
                  'msgId': revokeMsgId,
                  'revokeUser': from,
                },
              ),
            );
          }
        }
      } else {
        iPrint("未找到要撤回的消息: $revokeMsgId");
      }
    } else {
      iPrint("未找到对应的会话: peerId=$peerId");
    }
  }

  /// 处理 C2C 消息删除（双方）
  ///
  /// Action: c2c_del_everyone
  /// 触发时机：对端删除了一条消息（双方都删除）
  /// 处理逻辑：从会话中移除消息，触发UI更新
  static Future<void> _handleC2CDelEveryone(
    Map data,
    Map<String, dynamic> payload,
    String from,
    String to,
  ) async {
    final oldMsgId = payload['old_msg_id'] ?? '';
    final peerId = UserRepoLocal.to.currentUid == from ? to : from;
    final repo = ConversationRepo();
    final m = await repo.findByPeerId('C2C', peerId);

    final messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    final oldMsg = await messageRepo.find(oldMsgId);

    debugPrint(
      "switchS2C conversation found: ${m != null}, oldMsg found: ${oldMsg != null}",
    );

    if (m == null || oldMsg == null) {
      return;
    }

    final msg = await oldMsg.toTypeMessage();
    // 发布删除消息事件，由聊天界面订阅处理
    AppEventBus.fire(
      ChatExtendEvent(
        type: 'delete_msg',
        payload: {'conversation': m, 'msg': msg},
      ),
    );
  }

  /// 处理 C2G 消息删除（所有人）
  ///
  /// Action: c2g_del_everyone
  /// 触发时机：群组消息被删除（所有人可见）
  /// 处理逻辑：从群组会话中移除消息，触发UI更新
  static Future<void> _handleC2GDelEveryone(
    Map data,
    Map<String, dynamic> payload,
  ) async {
    final oldMsgId = payload['old_msg_id'] ?? '';
    final groupId = payload['to'] ?? '';
    final repo = ConversationRepo();
    final m = await repo.findByPeerId('C2G', groupId);

    final messageRepo = MessageRepo(tableName: MessageRepo.c2gTable);
    final oldMsg = await messageRepo.find(oldMsgId);

    iPrint(
      "c2g_del_everyone_check oldMsg ${oldMsg == null}, m ${m == null}; payload ${payload.toString()}",
    );

    if (m == null || oldMsg == null) {
      return;
    }

    final msg = await oldMsg.toTypeMessage();
    // 发布删除消息事件，由聊天界面订阅处理
    AppEventBus.fire(
      ChatExtendEvent(
        type: 'delete_msg',
        payload: {'conversation': m, 'msg': msg},
      ),
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

    final joinRes = await GroupListService().memberJoin(
      groupId: gid,
      userId: userId,
      userIdSum: userIdSum,
    );

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
    // TODO: 迁移到 Riverpod - 需要使用 newFriendProvider
    debugPrint("TODO: apply_friend_confirm 需要迁移到 Riverpod");
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
      UserRepoLocal.to.quitLogin();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
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

    await UserApi.to.refreshAccessTokenApi(
      rtk,
      checkNewToken: true,
    );
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
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.signIn,
      (route) => false,
    );
  }
}
