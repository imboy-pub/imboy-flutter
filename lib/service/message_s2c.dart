import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDialog, AlertDialog, TextButton;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/service/websocket.dart';

// ignore: depend_on_referenced_packages
import 'package:get/get.dart';

import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/people_model.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/contact/new_friend/new_friend_logic.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/provider/app_version_provider.dart';
import 'package:imboy/store/provider/user_provider.dart';

import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message.dart';
import 'message_offline.dart';

class MessageS2CService {
  static Future<void> switchS2C(Map data) async {
    iPrint("switchS2C ${data.toString()}");
    var payload = data['payload'] ?? {};
    if (payload is String) {
      payload = json.decode(payload);
    }
    String msgId = data['id'] ?? '';
    String from = data['from'];
    String to = data['to'];
    String msgType = payload['msg_type'] ?? '';
    bool autoAck = true;
    try {
      switch (msgType.toString().toLowerCase()) {
        case 'pull_offline_msg':
          // 拉取离线消息
          iPrint("pull_offline_msg 收到离线消息拉取指令，开始处理离线消息");

          // 异步处理离线消息，避免阻塞 S2C 消息确认
          Future.microtask(() async {
            try {
              await MessageOfflineService.to.pullOfflineMessages();
              iPrint("离线消息处理完成");
            } catch (e) {
              iPrint("离线消息处理失败: $e");
            }
          });

          break;
        case 'c2c_revoke':
          // 处理对端发来的撤回消息
          String revokeMsgId = payload['old_msg_id'] ?? '';
          String peerId = UserRepoLocal.to.currentUid == from ? to : from;

          iPrint("收到对端撤回消息: revokeMsgId=$revokeMsgId, peerId=$peerId");

          // 验证必需的字段
          if (revokeMsgId.isEmpty) {
            iPrint("❌ [S2C_C2C_REVOKE] old_msg_id 为空，跳过处理: data=${data.toString()}");
            break;
          }

          // 查找会话
          ConversationRepo conversationRepo = ConversationRepo();
          ConversationModel? conversation = await conversationRepo.findByPeerId('C2C', peerId);
          
          if (conversation != null) {
            // 查找要撤回的消息
            MessageRepo messageRepo = MessageRepo(
              tableName: MessageRepo.c2cTable,
            );
            MessageModel? oldMsg = await messageRepo.find(revokeMsgId);
            
            if (oldMsg != null) {
              iPrint("找到要撤回的消息: ${oldMsg.toJson()}");
              
              // 转换为撤回消息
              Map<String, dynamic> revokePayload = {
                'msg_type': 'custom',
                'custom_type': 'peer_revoked', // 标记为对方撤回
                'text': payload['text'] ?? '撤回的消息',
                'original_type': oldMsg.payload['msg_type'] ?? 'TextMessage',
                'revoke_time': payload['revoke_time'] ?? DateTimeHelper.millisecond(),
                'revoke_user': from, // 记录撤回操作的用户ID
              };
              
              // 更新消息
              int res = await messageRepo.update({
                'id': revokeMsgId,
                'payload': json.encode(revokePayload),
                'status': 20, // 设置为已读状态
              });
              
              iPrint("撤回消息数据库更新结果: $res, 消息ID: $revokeMsgId");
              
              if (res > 0) {
                // 重新获取更新后的消息
                MessageModel? updatedMsg = await messageRepo.find(revokeMsgId);
                if (updatedMsg != null) {
                  iPrint("撤回消息更新成功: ${updatedMsg.toJson()}");
                  
                  // 触发UI更新事件
                  eventBus.fire(ChatExtendModel(type: 'revoke_msg', payload: {
                    'conversation': conversation,
                    'msgId': revokeMsgId,
                    'revokeUser': from,
                  }));
                  
                  // 更新会话的最后一条消息
                  final ChatLogic chatLogic = Get.find();
                  await chatLogic.updateConversationAfterRevoke(
                    conversation,
                    await oldMsg.toTypeMessage(),
                    'peer_revoked',
                  );
                }
              }
            } else {
              iPrint("未找到要撤回的消息: $revokeMsgId");
            }
          } else {
            iPrint("未找到对应的会话: peerId=$peerId");
          }
          break;
        case 'c2c_del_everyone':
          String oldMsgId = payload['old_msg_id'] ?? '';
          String peerId = UserRepoLocal.to.currentUid == from ? to : from;
          ConversationRepo repo = ConversationRepo();
          ConversationModel? m = await repo.findByPeerId('C2C', peerId);

          MessageRepo messageRepo = MessageRepo(
            tableName: MessageRepo.c2cTable,
          );
          MessageModel? oldMsg = await messageRepo.find(oldMsgId);
          iPrint("switchS2C m ${m?.toJson().toString()} ;");
          iPrint("switchS2C oldMsg ${oldMsg?.toJson().toString()} ;");
          if (m == null || oldMsg == null) {
            break;
          }
          Message msg = await oldMsg.toTypeMessage();
          final ChatLogic logic = Get.find();
          // logic.setConversationModel(m);
          // 删除消息
          // 删除消息
          bool res = await logic.removeMessage(m, msg);
          if (res) {
            eventBus.fire(ChatExtendModel(type: 'delete_msg', payload: {
              'conversation': m,
              'msg': msg,
            }));
          }
          break;
        case 'c2g_del_everyone':
          String oldMsgId = payload['old_msg_id'] ?? '';
          String groupId = payload['to'] ?? '';
          ConversationRepo repo = ConversationRepo();
          ConversationModel? m = await repo.findByPeerId('C2G', groupId);

          MessageRepo messageRepo = MessageRepo(
            tableName: MessageRepo.c2gTable,
          );
          MessageModel? oldMsg = await messageRepo.find(oldMsgId);
          iPrint(
            "c2g_del_everyone_check oldMsg ${oldMsg == null}, m ${m == null}; payload ${payload.toString()}",
          );
          if (m == null || oldMsg == null) {
            break;
          }
          Message msg = await oldMsg.toTypeMessage();
          final ChatLogic logic = Get.find();
          // 删除消息
          bool res = await logic.removeMessage(m, msg);
          if (res) {
            eventBus.fire(ChatExtendModel(type: 'delete_msg', payload: {
              'conversation': m,
              'msg': msg,
            }));
          }
          break;
        case 'c2g_del_for_me':
          break;
        case 'group_member_join':
          // {id: , type: S2C, from: vyb9xb, to: 7b4v1b, payload: {msg_type: group_member_join}, server_ts: 1713334354767}
          String userId = data['from'];
          String nickname = payload['nickname'];
          String avatar = payload['avatar'];
          String account = payload['account'];
          String gid = payload['gid'];
          int userIdSum = payload['user_id_sum'] ?? 0;
          Map<String, dynamic>? joinRes = await Get.find<GroupListLogic>()
              .memberJoin(groupId: gid, userId: userId, userIdSum: userIdSum);

          eventBus.fire(
            ChatExtendModel(
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
          // eventBus.fire(JoinGroupModel(
          //   groupId: gid,
          //   userId: userId,
          //   isFirst: joinRes?['isFirst'] ?? false,
          //   people: PeopleModel(
          //     id: userId,
          //     account: account,
          //     nickname: nickname,
          //     avatar: avatar,
          //   ),
          // ));
          break;
        case 'group_dissolve':
          // String userId = data['from'];
          String gid = payload['gid'];
          await GroupDetailLogic().cleanData(gid);
          break;
        case 'group_member_leave':
          String userId = payload['leave_uid'];
          String gid = payload['gid'];
          int userIdSum = payload['user_id_sum'] ?? 0;
          await Get.find<GroupListLogic>().memberLeave(
            groupId: gid,
            userId: userId,
            userIdSum: userIdSum,
          );
          eventBus.fire(
            ChatExtendModel(
              type: 'leave_group',
              payload: {
                'groupId': gid,
                'userId': userId,
                'people': PeopleModel(id: userId, account: ''),
              },
            ),
          );
          // eventBus.fire(LeaveGroupModel(
          //   groupId: gid,
          //   userId: userId,
          //   people: PeopleModel(
          //     id: userId,
          //     account: '',
          //   ),
          // ));
          break;
        case 'group_member_alias':
          // payload:{alias:, description:, updated_at:, gid:}
          break;
        case 'user_cancel':
          // 当前用户的朋友user_id注销了
          // TODO
          // String userId = data['from'];
          break;
        case 'apply_friend': // 添加朋友申请
          Get.find<NewFriendLogic>().receivedAddFriend(data);
          break;
        case 'apply_friend_confirm': // 添加朋友申请确认
          // 接受消息人（to）新增联系人
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
          Map<String, dynamic> json = {
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
          Get.find<ContactLogic>().receivedConfirmFriend(json);
          // 修正好友申请状态
          Get.find<NewFriendLogic>().receivedConfirmFriend(true, data);
          break;
        case 'in_denylist':
          // 对方将我加入黑名单后： 消息已发出，但被对方拒收了。
          // String msgId = payload['content'] ?? '';
          Get.find<ChatLogic>().setSysPrompt(
            MessageRepo.c2cTable,
            msgId,
            'in_denylist',
          );
          break;
        case 'not_a_friend':
          // String msgId = payload['content'] ?? '';
          Get.find<ChatLogic>().setSysPrompt(
            MessageRepo.c2cTable,
            msgId,
            'not_a_friend',
          );
          break;
        case 'logged_another_device': // 在其他设备登录了
          String did = payload['did'] ?? '';
          if (did != deviceId) {
            int serverTs = data['server_ts'] ?? 0;
            UserRepoLocal.to.quitLogin();
            Get.off(
              () => const LoginPage(),
              arguments: {
                "msg_type": "logged_another_device",
                "server_ts": serverTs,
                "dname": payload['dname'] ?? '', // 设备名称
              },
            );
          }
          break;
        case 'please_refresh_token': // 服务端通知客户端刷新token
          iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId,$autoAck");
          autoAck = false;
          MessageService.to.sendAckMsg('S2C', msgId);
          String rtk = await UserRepoLocal.to.refreshToken;

          await (UserProvider()).refreshAccessTokenApi(
            rtk,
            checkNewToken: true,
          );
          break;
        case 'app_upgrade':
          final AppVersionProvider p = AppVersionProvider();
          final Map<String, dynamic> info = await p.check(appVsn);
          final String downLoadUrl = info['download_url'] ?? '';
          bool updatable = info['updatable'] ?? false;
          updatable = downLoadUrl.isEmpty ? false : updatable;
          if (updatable) {
            await Navigator.of(Get.context!).push(
              CupertinoPageRoute(
                // “右滑返回上一页”功能
                builder: (_) => UpgradePage(
                  version: info['vsn'],
                  downLoadUrl: downLoadUrl,
                  message: info['description'] ?? '',
                  isForce: 1 == (info['force_update'] ?? 2) ? true : false,
                ),
              ),
            );
          }
          break;
        case 'device_force_offline': // 被其他设备强制下线
          {
            final byDid = payload['by_did'] ?? '';
            final byName = payload['by_name'] ?? '';
            final serverTs = data['server_ts'] ?? 0;

            // 优先弹窗提示来源设备；若无可用 context 则忽略弹窗
            try {
              if (Get.context != null) {
                await showDialog<bool>(
                  context: Get.context!,
                  barrierDismissible: true,
                  builder: (ctx) => AlertDialog(
                    title: Text('下线通知'.tr),
                    content: Text('您已被设备【$byName】强制下线'.tr),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('buttonOk'.tr),
                      ),
                    ],
                  ),
                );
              }
            } catch (_) {}

            // 统一执行退登与清理
            try {
              WebSocketService.to.closeSocket(permanent: true);
            } catch (_) {}

            EasyLoading.showSuccess('confirmRecoverSuccess'.tr);
            await UserRepoLocal.to.quitLogin();
            Get.offAll(
              () => const LoginPage(),
              arguments: {
                'msg_type': 'device_force_offline',
                'server_ts': serverTs,
                'by_did': byDid,
                'by_dname': byName,
              },
            );
          }
          break;
        case 'online': // 好友上线提醒
          // TODO
          break;
        case 'offline': // 好友下线提醒
          // TODO
          break;
        case 'hide': // 好友hide提醒
          // TODO
          // String uid = data['from'] ?? '';
          break;
      }
      // 确认消息
     if (autoAck) {
       iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId");
       MessageService.to.sendAckMsg('S2C', msgId);
     }
    } catch (e, s) {
      iPrint("switchS2C error: $e, $s");
    }
  }
}
