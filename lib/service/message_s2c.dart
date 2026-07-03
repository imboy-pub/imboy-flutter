import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDialog, AlertDialog, TextButton;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/service/websocket_events.dart';

import 'package:imboy/page/group/group_detail/group_detail_service.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/page/contact/new_friend/new_friend_provider.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/store/api/user_api.dart';

import 'package:imboy/store/model/moment_notify_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/moment_notify_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/routes.dart';

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/service/app_upgrade_service.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/group_member_mute_s2c.dart';
import 'package:imboy/service/group_edit_s2c.dart';
import 'package:imboy/service/group_member_role_s2c.dart';
import 'package:imboy/service/group_notice_s2c.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/model/group_member_columns.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// S2C 消息处理服务（WebSocket API v2.0 格式）
///
/// v2.0 主要变更：
/// - action 字段在顶层（不再兼容旧格式）
/// - 使用 switch 语句处理不同的 action
/// - 提取各个 action 处理逻辑为独立方法
class MessageS2CService {
  // 必须通过 setProviderContainer 注入应用级容器，否则状态更新不会反映到 UI
  // 初始值为 null，防止创建与根容器状态不同步的孤立容器
  static ProviderContainer? _providerContainer;

  /// 注入应用级 ProviderContainer（由 MessageService.setProviderContainer 级联调用）
  static void setProviderContainer(ProviderContainer container) {
    _providerContainer = container;
  }

  /// 获取已注入的容器，未注入时抛出断言错误
  static ProviderContainer get _container {
    assert(
      _providerContainer != null,
      'MessageS2CService: ProviderContainer 未注入，请先调用 setProviderContainer',
    );
    return _providerContainer!;
  }

  // ============================================
  // S2C 重复投递去重层
  // ============================================
  //
  // 历史问题：switchS2C 此前无任何去重，服务端按 2/5/7/11s 窗口重发 ACK 未到的 S2C 时，
  // 非幂等动作（force_offline / apply_friend / group_member_join / user_muted 等）会
  // 重复执行——重复踢登录、重复建联系人、重复弹 toast。
  //
  // 策略：在 switchS2C 顶部用 S2C 帧自带的稳定 id 做单点去重，命中则跳过 action 执行，
  //       但【仍发送 ACK】（否则服务端继续重发）。
  //       pull_offline_msg 是服务端主动 nudge（非事件），跨重连可能合法重发，单独走短 TTL。
  static final Map<String, int> _processedS2CIds = {}; // key -> 处理时间戳(ms)
  // 常规去重 TTL 必须 ≫ 服务端 S2C 重发窗口（2/5/7/11s，最大约 11s），
  // 否则窗口内的重投会被当作新事件重复执行。@visibleForTesting 供特征化测试断言此不变量。
  @visibleForTesting
  static const int s2cDedupTtlMs = 5 * 60 * 1000; // 常规 5 分钟
  @visibleForTesting
  static const int s2cPullOfflineTtlMs = 2 * 1000; // pull_offline_msg 短 TTL

  /// 构建 S2C 去重 key：优先用帧 id；id 为空时回退到 action+from+to+server_ts 复合 key
  @visibleForTesting
  static String buildS2CDedupKey(
    Map<String, dynamic> data,
    String action,
    String from,
    String to,
  ) {
    final id = data['id']?.toString() ?? '';
    if (id.isNotEmpty) return id;
    final serverTs = data['server_ts']?.toString() ?? '';
    return '${action}_${from}_${to}_$serverTs';
  }

  /// 惰性清理过期去重标记（镜像 message.dart 的 _cleanExpiredReceivingMarks）
  static void _cleanExpiredS2CIds(int now) {
    if (_processedS2CIds.isEmpty) return;
    final expiredKeys = <String>[];
    // 用最长 TTL 作为清理阈值（短 TTL 的条目也会被这个窗口清掉，足够安全）
    _processedS2CIds.forEach((key, ts) {
      if (now - ts > s2cDedupTtlMs) expiredKeys.add(key);
    });
    for (final key in expiredKeys) {
      _processedS2CIds.remove(key);
    }
  }

  /// 发送 S2C ACK（去重命中与正常路径共用，确保服务端始终收到 ACK 以停止重发）
  static void _sendS2CAck(String msgId, bool autoAck) {
    if (!autoAck) return;
    if (msgId.isEmpty) return;
    iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId");
    AckManager.to.sendAckDirect('S2C', msgId);
  }

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
  static Future<void> switchS2C(Map<String, dynamic> data) async {
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
        return;
      }

      // 【S2C 去重层】在 switch 之前用帧 id 做单点去重，杜绝重复投递导致的重复执行。
      final actionLower = action.toLowerCase();
      final dedupKey = buildS2CDedupKey(
        data,
        actionLower,
        from.toString(),
        to.toString(),
      );
      final isPullOffline = actionLower == 'pull_offline_msg';
      final ttl = isPullOffline ? s2cPullOfflineTtlMs : s2cDedupTtlMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      _cleanExpiredS2CIds(now);
      final lastSeen = _processedS2CIds[dedupKey];
      if (lastSeen != null && now - lastSeen < ttl) {
        iPrint('🟡 [S2C dedup] 重复 S2C 已处理，跳过 action=$action key=$dedupKey');
        // 重复也必须 ACK，否则服务端在重发窗口内继续重投
        _sendS2CAck(msgId.toString(), autoAck);
        return;
      }
      _processedS2CIds[dedupKey] = now;

      // v2.0: 使用 switch 处理不同的 action（统一转小写，避免大小写问题）
      switch (actionLower) {
        case 'pull_offline_msg':
          await _handlePullOfflineMsg(data, payloadMap);
          break;
        case 'message_read_sync':
          await _handleMessageReadSync(payloadMap);
          break;
        case 'c2c_revoke':
          await _handleC2CRevoke(
            data,
            payloadMap,
            from as String,
            to as String,
          );
          break;
        case 'c2c_del_everyone':
          await _handleC2CDelEveryone(
            data,
            payloadMap,
            from as String,
            to as String,
          );
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
          await _container
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
          await _handlePleaseRefreshToken(payloadMap, msgId as String);
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
        case 'group_member_mute':
          // 群管理员禁言群成员的广播（slice-1：仅通知，不更新 Repo）
          await _handleGroupMemberMute(payloadMap);
          break;
        case 'group_edit':
          // 群资料被编辑的广播（slice-3：写本地 GroupRepo + 广播事件）
          await _handleGroupEdit(payloadMap);
          break;
        case 'group_member_role':
          // 群成员角色变更广播（slice-4：写本地 group_member.role + 广播事件）
          await _handleGroupMemberRole(payloadMap);
          break;
        case 'group_notice_published':
          // 群公告发布广播（W1.1：不写本地表，仅广播事件触发 UI 刷新）
          await _handleGroupNoticePublished(payloadMap);
          break;
        case 'user_unmuted':
          // 当前用户禁言解除
          await _handleUserUnmuted(payloadMap);
          break;
        case 'moment_new':
        case 'moment_like':
        case 'moment_comment':
        case 'moment_deleted':
        case 'moment_updated':
          await _handleMomentAction(action, payloadMap);
          break;
        case 'manifest_updated':
          await AppManifestService.refresh();
          break;
        default:
          break;
      }

      // 确认消息
      _sendS2CAck(msgId.toString(), autoAck);
    } on Object catch (e, s) {
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
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    iPrint("pull_offline_msg 收到离线消息拉取指令，开始处理离线消息");

    // 发布离线消息拉取事件，由 MessageOfflineService 订阅处理
    // 异步处理，避免阻塞 S2C 消息确认
    AppEventBus.fire(
      OfflineMessagesPullRequestedEvent(source: 'S2C', reason: '服务端通知拉取离线消息'),
    );
  }

  /// 处理已读状态同步（自己其他设备已读了某条 C2C 消息）
  ///
  /// Action: message_read_sync（ws-protocol-contract.md §9，2026-07-02 新增）
  /// 触发时机：本账号任一设备发送已读回执并落库后，服务端推送给阅读者本人
  /// payload: { msg_id, peer, read_at }
  /// 处理逻辑：复用消息状态事件把该消息标记为 seen（DB 与 UI 由既有监听者处理）；
  /// 本设备若正是阅读设备，消息已是 seen，事件幂等无副作用。
  static Future<void> _handleMessageReadSync(
    Map<String, dynamic> payload,
  ) async {
    final syncMsgId = parseModelString(payload['msg_id']);
    // peer = 后端 To（原消息发送者的编码 id），与本地会话表的 peerId 同源
    final peer = parseModelString(payload['peer']);
    if (syncMsgId.isEmpty || peer.isEmpty) {
      return;
    }
    iPrint('message_read_sync 同步其他设备已读 msgId=$syncMsgId peer=$peer');
    // 复用 chatProvider.markAsRead 而非只发 MessageStatusUpdateRequestedEvent：
    // 后者只更新消息行状态，不递减会话未读数（unreadNum），会导致本设备
    // 消息已读但未读徽章残留。syncToServer=false 避免再次上报已读回执，
    // 否则会与服务端 message_read_sync 推送形成 ACK/回执循环。
    try {
      await _container.read(chatProvider.notifier).markAsRead(
        MessageFlowType.c2c,
        peer,
        [syncMsgId],
        syncToServer: false,
      );
    } on Object catch (e) {
      iPrint('❌ [message_read_sync] markAsRead 失败: $e');
    }
  }

  /// 处理 C2C 消息撤回
  ///
  /// Action: c2c_revoke
  /// 触发时机：对端撤回了一条消息
  /// 处理逻辑：使用公共辅助类将消息转换为撤回提示，更新数据库，触发UI刷新
  static Future<void> _handleC2CRevoke(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
    String from,
    String to,
  ) async {
    final revokeMsgId = (payload['old_msg_id'] ?? '') as String;

    iPrint("收到对端撤回消息: revokeMsgId=$revokeMsgId");

    // 验证必需的字段
    if (revokeMsgId.isEmpty) {
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
        originalText: payload['text'] as String?,
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
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
    String from,
    String to,
  ) async {
    final oldMsgId = payload['old_msg_id'] ?? '';

    // 使用公共辅助类处理删除（消除代码重复）
    await MessageActions.handleC2CDeleteMessage(
      oldMsgId: oldMsgId as String,
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
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    final oldMsgId = payload['old_msg_id'] ?? '';
    final groupId = payload['to'] ?? '';

    // 使用公共辅助类处理删除（消除代码重复）
    await MessageActions.handleC2GDeleteMessage(
      oldMsgId: oldMsgId as String,
      groupId: groupId as String,
    );
  }

  /// 处理群组成员加入
  ///
  /// Action: group_member_join
  /// 触发时机：有新成员加入群组
  /// 处理逻辑：更新群组成员列表，触发UI更新
  static Future<void> _handleGroupMemberJoin(
    Map<String, dynamic> data,
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
      groupId: gid as String,
      userId: userId as String,
      userIdSum: userIdSum as int,
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
            id: userId as int,
            account: account as String,
            nickname: nickname as String,
            avatar: avatar as String,
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
    await GroupDetailService().cleanData(gid as String);
  }

  /// 处理群组成员离开
  ///
  /// Action: group_member_leave
  /// 触发时机：有成员离开群组
  /// 处理逻辑：更新群组成员列表，触发UI更新
  static Future<void> _handleGroupMemberLeave(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    final userId = payload['leave_uid'];
    final gid = payload['gid'];
    final userIdSum = payload['user_id_sum'] ?? 0;

    await GroupListService().memberLeave(
      groupId: gid as String,
      userId: userId as String,
      userIdSum: userIdSum as int,
    );

    AppEventBus.fire(
      ChatExtendEvent(
        type: 'leave_group',
        payload: {
          'groupId': gid,
          'userId': userId,
          'people': PeopleModel(id: userId as int, account: ''),
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
    Map<String, dynamic> data,
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

    _container.read(contactProvider.notifier).receivedConfirmFriend(json);

    // 修正好友申请状态
    await _container
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
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        // 使用 go_router 进行导航
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // 使用 go_router 的 go 方法替代 Navigator.pushNamedAndRemoveUntil
          // go_router 会自动清除路由栈
          context.go(AppRoutes.signIn);
        }
      } on Object catch (e) {
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
  /// 触发时机：服务端通知客户端有新版本（S2C 推送 或 WebSocket 版本保护）
  /// 处理逻辑：委托给 AppUpgradeService 统一处理三级升级策略
  static Future<void> _handleAppUpgrade(Map<String, dynamic> payload) async {
    await AppUpgradeService.to.onS2CUpgradeNotice(payload);
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
            title: Text(t.common.offlineNotification),
            content: Text(
              t.common.forcedOfflineByDevice(device: byName as Object),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(t.common.buttonOk),
              ),
            ],
          ),
        );
      }
    } on Object catch (e) {
      iPrint('[S2C] s2c_handler failed: $e');
    }

    // 统一执行退登与清理
    try {
      AppEventBus.fire(WebSocketForceCloseEvent(permanent: true));
    } on Object catch (e) {
      iPrint('[S2C] fire failed: $e');
    }

    AppLoading.showSuccess(t.common.confirmRecoverSuccess);
    await UserRepoLocal.to.quitLogin();

    // 使用延迟确保 quitLogin 完全执行完毕
    await Future<dynamic>.delayed(const Duration(milliseconds: 100));

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
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    final msgId = parseModelNullableString(data['id']);
    // 会话类型 (C2C/C2G)
    final chatType = data['type']?.toString() ?? 'C2C';

    // 使用公共辅助类处理非好友错误（消除代码重复）
    await MessageActions.handleNotAFriendError(
      msgId: msgId,
      chatType: chatType,
    );
  }

  ///
  /// Action: in_denylist
  /// 触发时机：对方将您加入黑名单
  /// 处理逻辑：使用公共辅助类处理黑名单错误
  static Future<void> _handleInDenylist(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    final msgId = parseModelNullableString(data['id']);
    // 会话类型 (C2C/C2G)
    final chatType = data['type']?.toString() ?? 'C2C';

    // 使用公共辅助类处理黑名单错误（消除代码重复）
    await MessageActions.handleDenylistError(msgId: msgId, chatType: chatType);
  }

  /// 处理用户注销
  ///
  /// Action: user_cancel
  /// 触发时机：好友账号注销
  /// 处理逻辑：发布用户注销事件，由UI层订阅显示提示
  static Future<void> _handleUserCancel(
    Map<String, dynamic> data,
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
    Map<String, dynamic> data,
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
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) => _handleUserStatusChange(data, payload, 'online');

  static Future<void> _handleUserOffline(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) => _handleUserStatusChange(data, payload, 'offline');

  static Future<void> _handleUserHide(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) => _handleUserStatusChange(data, payload, 'hide');

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
      // TOFU 安全告警：通知 UI 层（若正打开与该 uid 的 C2C 会话）提示"对方安全码已变更"
      AppEventBus.fire(
        E2EEPeerKeyChangedEvent(uid: uid, deviceId: deviceId, keyId: keyId),
      );
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
      muteUntilMs: muteUntil is int
          ? muteUntil
          : int.tryParse('$muteUntil') ?? 0,
      reason: reason,
      conversationId: conversationId,
    );

    // 发布事件供 UI 层订阅
    AppEventBus.fire(event);

    // 同时用 EasyLoading 显示即时提示
    final minutes = event.remainingMinutes;
    if (minutes > 0) {
      AppLoading.showInfo(
        t.chat.youAreMutedWithTime(minutes: '$minutes'),
        duration: const Duration(seconds: 3),
      );
    } else {
      AppLoading.showInfo(
        t.chat.youAreMuted,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// 处理群成员被禁言通知（S2C `group_member_mute`）
  ///
  /// Action: group_member_mute
  /// 触发时机：群管理员 / 群主禁言某成员后，后端向群内所有成员广播。
  ///
  /// **slice-1-finalize（2026-04-15）**：后端 `mute_notice/4` 已补
  /// `<<"user_id">> => UserId`。客户端流程：
  ///   1. 解析 payload（含 userId）
  ///   2. 广播 `GroupMemberMuteEvent`（携带 userId，UI 可定位成员行）
  ///   3. **userId 非空** → 调 `GroupMemberRepo.update` 写本地
  ///      `group_member.mute_until`，UI 重进群成员页时即可看到状态
  ///   4. **userId 为空**（老后端 / 解析缺失）→ 跳过 Repo 写入，仅做群级 toast
  ///   5. 任何 Repo 异常 / 当前用户未加入群 → 吞异常不阻塞 toast
  static Future<void> _handleGroupMemberMute(
    Map<String, dynamic> payload,
  ) async {
    final parsed = parseGroupMemberMutePayload(payload);
    switch (parsed) {
      case GroupMemberMuteParseError(:final reason):
        iPrint('[S2C] group_member_mute 解析失败: $reason, payload=$payload');
        return;
      case GroupMemberMutePayload(
        :final gid,
        :final userId,
        :final muteUntilMs,
        :final remainingSeconds,
        :final durationText,
        :final adminNickname,
      ):
        iPrint(
          '[S2C] group_member_mute: gid=$gid, userId=$userId, '
          'muteUntilMs=$muteUntilMs, remainingSec=$remainingSeconds, '
          'admin=$adminNickname',
        );

        // Repo 写入：仅在 userId 非空时执行（老后端兼容）
        if (userId.isNotEmpty) {
          try {
            await GroupMemberRepo().update(gid.toString(), userId, {
              GroupMemberColumns.muteUntil: muteUntilMs,
            });
          } on Object catch (e) {
            // 当前用户未加入该群 / Repo 异常 → 吞异常，不阻塞 toast
            iPrint('[S2C] group_member_mute Repo update failed: $e');
          }
        }

        AppEventBus.fire(
          GroupMemberMuteEvent(
            gid: gid,
            userId: userId,
            muteUntilMs: muteUntilMs,
            remainingSeconds: remainingSeconds,
            durationText: durationText,
            adminNickname: adminNickname,
          ),
        );
        // 仅在有可读文案时展示轻量提示，避免骚扰
        if (durationText.isNotEmpty && adminNickname.isNotEmpty) {
          AppLoading.showInfo(
            '$adminNickname 禁言群成员 $durationText',
            duration: const Duration(seconds: 2),
          );
        }
      case GroupMemberUnmutePayload(
        :final gid,
        :final userId,
        :final adminNickname,
      ):
        // slice-9b：解禁语义，Repo mute_until 置 NULL + 广播 Unmute 事件
        iPrint(
          '[S2C] group_member_unmute: gid=$gid, userId=$userId, '
          'admin=$adminNickname',
        );

        if (userId.isNotEmpty) {
          try {
            await GroupMemberRepo().update(gid.toString(), userId, {
              GroupMemberColumns.muteUntil: null,
            });
          } on Object catch (e) {
            iPrint('[S2C] group_member_unmute Repo update failed: $e');
          }
        }

        AppEventBus.fire(
          GroupMemberUnmuteEvent(
            gid: gid,
            userId: userId,
            adminNickname: adminNickname,
          ),
        );
        if (adminNickname.isNotEmpty) {
          AppLoading.showInfo(
            '$adminNickname 解除了群成员禁言',
            duration: const Duration(seconds: 2),
          );
        }
    }
  }

  /// 处理群资料编辑的广播（S2C `group_edit`）
  ///
  /// Action: group_edit
  /// 触发时机：群主/管理员通过 `POST /group/edit` 更新群资料后，后端向
  /// 所有群成员广播。本地需要：
  ///   1. 更新 `GroupRepo` 对应行（只写白名单字段，由 Repo.update 自身过滤）
  ///   2. 广播 `GroupEditEvent`，让 UI（群详情、会话列表、聊天页头部等）
  ///      响应式刷新
  ///
  /// 使用 `handleGroupEditS2C` 做分派，便于单测覆盖分支（见
  /// `test/service/group_edit_s2c_handler_test.dart`）。
  static Future<void> _handleGroupEdit(Map<String, dynamic> payload) async {
    await handleGroupEditS2C(
      payload: payload,
      applyUpdate: (gid, updates) =>
          GroupRepo().update(gid.toString(), updates),
      fireEvent: (gid, updates) =>
          AppEventBus.fire(GroupEditEvent(gid: gid, updates: updates)),
      log: iPrint,
    );
  }

  /// 处理群成员角色变更的广播（S2C `group_member_role`）
  ///
  /// Action: group_member_role
  /// 触发时机：后端 `group_member_logic:role_change_notice/4` 将角色变更广播
  /// 给群内所有成员。本地需要：
  ///   1. 更新 `group_member.role`（含 updated_at 若后端带）
  ///   2. 广播 `GroupMemberRoleEvent`，让 UI（群成员列表 / 聊天页头部权限按钮）
  ///      响应式刷新
  ///
  /// 使用 `handleGroupMemberRoleS2C` 做分派（见
  /// `test/service/group_member_role_s2c_handler_test.dart`）。
  static Future<void> _handleGroupMemberRole(
    Map<String, dynamic> payload,
  ) async {
    await handleGroupMemberRoleS2C(
      payload: payload,
      applyRoleUpdate: (gid, userId, role, updatedAt) async {
        final json = <String, dynamic>{'role': role};
        if (updatedAt > 0) {
          json['updated_at'] = updatedAt;
        }
        await GroupMemberRepo().update(gid.toString(), userId.toString(), json);
      },
      fireEvent: (p) => AppEventBus.fire(
        GroupMemberRoleEvent(
          gid: p.gid,
          userId: p.userId,
          role: p.role,
          roleText: p.roleText,
          nickname: p.nickname,
          adminNickname: p.adminNickname,
          updatedAt: p.updatedAt,
        ),
      ),
      log: iPrint,
    );
  }

  /// 处理群公告发布的广播（S2C `group_notice_published`）
  ///
  /// Action: group_notice_published
  /// 触发时机：后端 `group_notice_logic:publish_notice/3` 在公告发布
  /// 成功后向群内所有成员广播（规划中，见 W1.1 runbook）。
  ///
  /// 本切片**不写本地 announcement 表**：
  ///   1. 后端当前 REST-only，公告数据源仍为 REST（避免引入 v20 migration）
  ///   2. UI 层（`GroupAnnouncementProvider`）订阅 `GroupNoticePublishedEvent`
  ///      后自行调 REST 刷新，或在聊天页显示 toast 提示
  ///
  /// 使用 `handleGroupNoticeS2C` 做分派（见
  /// `test/service/group_notice_s2c_handler_test.dart`）。
  static Future<void> _handleGroupNoticePublished(
    Map<String, dynamic> payload,
  ) async {
    await handleGroupNoticeS2C(
      payload: payload,
      fireEvent: (p) => AppEventBus.fire(
        GroupNoticePublishedEvent(
          gid: p.gid,
          noticeId: p.noticeId,
          publisherId: p.publisherId,
          publisherNickname: p.publisherNickname,
          title: p.title,
          body: p.body,
          expiredAt: p.expiredAt,
          publishedAt: p.publishedAt,
        ),
      ),
      log: iPrint,
    );
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
  ///
  /// 分两条路径：
  ///   1. timeline 变更事件 —— 永远广播，供朋友圈列表/详情页刷新（new/deleted
  ///      /like/comment 都走这里）
  ///   2. 通知中心落库 —— 仅 `moment_like` / `moment_comment` 入 `moment_notify`
  ///      表，成功后额外广播 `MomentNotifyUnreadChangedEvent` 供红点实时刷新
  static Future<void> _handleMomentAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final momentId = payload['moment_id']?.toString() ?? '';
    iPrint('[S2C] $action: momentId=$momentId');

    // 1) timeline 广播（朋友圈列表 / 详情页订阅）
    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: action,
        momentId: momentId,
        payload: payload,
      ),
    );

    // 2) 通知中心落库（仅 like / comment）
    if (action != 'moment_like' && action != 'moment_comment') {
      return;
    }
    final currentUid = UserRepoLocal.to.currentUid;
    if (currentUid.isEmpty) {
      // 未登录或未初始化，忽略（防御性：正常情况 S2C 不会在未登录态到达）
      return;
    }

    final parseResult = MomentNotifyModel.fromS2CPayload(
      action: action,
      payload: payload,
      currentUid: currentUid,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );

    switch (parseResult) {
      case MomentNotifyParseOk(:final model):
        try {
          final repo = MomentNotifyRepo();
          final rowId = await repo.insert(model);
          if (rowId > 0) {
            final unread = await repo.unreadCount(currentUid);
            AppEventBus.fire(
              MomentNotifyUnreadChangedEvent(
                unreadCount: unread,
                trigger: action == 'moment_like' ? 's2c_like' : 's2c_comment',
              ),
            );
          }
          // rowId == 0：被唯一索引拦截（重复 S2C），静默忽略
        } on Object catch (error, stack) {
          // Repo 异常不能阻断其他 S2C 处理（例如 moment_notify 表在老版本
          // 用户上尚未迁移到）
          iPrint('[S2C] moment_notify insert failed: $error\n$stack');
        }
        return;
      case MomentNotifyParseSkipSelf():
        // 自赞 / 自评防御分支，后端已过滤，忽略即可
        return;
      case MomentNotifyParseInvalid(:final reason):
        iPrint('[S2C] moment_notify invalid payload: $reason action=$action');
        return;
    }
  }

  /// 处理频道消息推送
  ///
  /// Action: channel_message
  /// 触发时机：订阅的频道发布新消息
  /// 处理逻辑：保存消息到本地，更新未读计数
  static Future<void> _handleChannelMessage(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    iPrint('[S2C] channel_message: 收到频道消息');

    try {
      await ChannelService.to.handleChannelMessage(payload);
    } on Object catch (e) {
      iPrint('[S2C] handleChannelMessage failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] handleChannelSubscribed failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] handleChannelUnsubscribed failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] handleChannelUpdated failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] handleChannelMessageDeleted failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] handleChannelMessageRevoked failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] handleChannelDeleted failed: $e');
    }
  }

  static Future<void> _handleChannelInvitationCreated(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_invitation_created: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelInvitationCreated(payload);
    } on Object catch (e) {
      iPrint('[S2C] handleChannelInvitationCreated failed: $e');
    }
  }

  static Future<void> _handleChannelInvitationAccepted(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_invitation_accepted: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelInvitationAccepted(payload);
    } on Object catch (e) {
      iPrint('[S2C] handleChannelInvitationAccepted failed: $e');
    }
  }

  static Future<void> _handleChannelOrderPaid(
    Map<String, dynamic> payload,
  ) async {
    final channelId = payload['channel_id']?.toString() ?? '';
    iPrint('[S2C] channel_order_paid: channelId=$channelId');

    try {
      await ChannelService.to.handleChannelOrderPaid(payload);
    } on Object catch (e) {
      iPrint('[S2C] handleChannelOrderPaid failed: $e');
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
    } on Object catch (e) {
      iPrint('[S2C] s2c_handler failed: $e');
    }
  }
}
