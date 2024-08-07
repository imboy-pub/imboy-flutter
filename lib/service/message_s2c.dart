import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';

// ignore: depend_on_referenced_packages
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/people_model.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/contact/new_friend/new_friend_logic.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/provider/app_version_provider.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message.dart';

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
    // try {
    switch (msgType.toString().toLowerCase()) {
      case 'c2c_del_everyone':
        String oldMsgId = payload['old_msg_id'] ?? '';
        String peerId = UserRepoLocal.to.currentUid == from ? to : from;
        ConversationRepo repo = ConversationRepo();
        ConversationModel? m = await repo.findByPeerId('C2C', peerId);

        MessageRepo messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
        MessageModel? oldMsg = await messageRepo.find(oldMsgId);

        if (m == null || oldMsg == null) {
          break;
        }
        types.Message msg = await oldMsg.toTypeMessage();
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
      case 'c2g_del_everyone':
        String oldMsgId = payload['old_msg_id'] ?? '';
        String groupId = payload['to'] ?? '';
        ConversationRepo repo = ConversationRepo();
        ConversationModel? m = await repo.findByPeerId('C2G', groupId);

        MessageRepo messageRepo = MessageRepo(tableName: MessageRepo.c2gTable);
        MessageModel? oldMsg = await messageRepo.find(oldMsgId);
        iPrint("c2g_del_everyone_check oldMsg ${oldMsg == null}, m ${m == null}; payload ${payload.toString()}");
        if (m == null || oldMsg == null) {
          break;
        }
        types.Message msg = await oldMsg.toTypeMessage();
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
        Map<String, dynamic>? joinRes =
            await Get.find<GroupListLogic>().memberJoin(
          groupId: gid,
          userId: userId,
          userIdSum: userIdSum,
        );

        eventBus.fire(ChatExtendModel(type: 'join_group', payload: {
          'groupId': gid,
          'userId': userId,
          'isFirst': joinRes?['isFirst'] ?? false,
          'people': PeopleModel(
            id: userId,
            account: account,
            nickname: nickname,
            avatar: avatar,
          ),
        }));
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
        eventBus.fire(ChatExtendModel(type: 'leave_group', payload: {
          'groupId': gid,
          'userId': userId,
          'people': PeopleModel(
            id: userId,
            account: '',
          ),
        }));
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
        Get.find<ChatLogic>()
            .setSysPrompt(MessageRepo.c2cTable, msgId, 'in_denylist');
        break;
      case 'not_a_friend':
        // String msgId = payload['content'] ?? '';
        Get.find<ChatLogic>()
            .setSysPrompt(MessageRepo.c2cTable, msgId, 'not_a_friend');
        break;
      case 'logged_another_device': // 在其他设备登录了
        String did = payload['did'] ?? '';
        if (did != deviceId) {
          int serverTs = data['server_ts'] ?? 0;
          UserRepoLocal.to.quitLogin();
          Get.off(() => PassportPage(), arguments: {
            "msg_type": "logged_another_device",
            "server_ts": serverTs,
            "dname": payload['dname'] ?? '', // 设备名称
          });
        }
        break;
      case 'please_refresh_token': // 服务端通知客户端刷新token
        iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId,$autoAck");
        autoAck = false;
        MessageService.to.sendAckMsg('S2C', msgId);
        String rtk = await UserRepoLocal.to.refreshToken;

        await (UserProvider()).refreshAccessTokenApi(rtk, checkNewToken: true);
        break;
      case 'app_upgrade':
        final AppVersionProvider p = AppVersionProvider();
        final Map<String, dynamic> info = await p.check(
          appVsn,
        );
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
    // } catch (e) {}
    // 确认消息
    if (autoAck) {
      iPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$deviceId");
      MessageService.to.sendAckMsg('S2C', msgId);
    }
  }
}
