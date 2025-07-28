import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_controller.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:sqflite/sqflite.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat_state.dart';

/// 聊天业务逻辑控制器
/// 处理消息发送、接收、状态更新等核心业务逻辑
class ChatLogic extends GetxController {
  final state = ChatState();
  final scrollController = ScrollController();
  late SqliteChatController chatController; // 聊天控制器
  @override
  void onInit() {
    super.onInit();
    initState();
  }

  void initChatController(String chatType) {
    chatController = SqliteChatController();
    // 清理旧数据
    chatController.setMessages([]);
  }

  /// 初始化状态
  void initState() {
    // 这里可以初始化状态（如清除计数等），如有必要可扩展
    state.hasMoreMessage.value = true;
    state.isLoading.value = false;
    state.nextAutoId.value = 0;
    state.memberCount.value = 0;
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// 获取群组标题，格式为"群组名称(人数)"
  Future<String> groupTitle(String gid, String prefix, int num) async {
    String prefix2 = strNoEmpty(prefix) ? prefix : 'group_chat'.tr;
    if (num > 0) {
      return "$prefix2($num)";
    } else {
      // 如果人数为0，则从数据库查询群组详情
      GroupModel? g = await GroupDetailLogic().detail(gid: gid);
      state.memberCount.value = g?.memberCount ?? 0;
      if (state.memberCount.value > 0) {
        return "$prefix2(${state.memberCount.value})";
      }
      return prefix2;
    }
  }

  /// 分页加载消息
  /// [obj] 当前会话对象
  /// [size] 每页大小
  Future<List<Message>> pageMessages(ConversationModel obj, int size) async {
    final tb = MessageRepo.getTableName(obj.type);
    final repo = MessageRepo(tableName: tb);

    // 从数据库分页查询消息
    final items = await repo.pageForConversation(
      obj.uk3,
      state.nextAutoId.value,
      size,
    );

    if (items.isEmpty) {
      state.hasMoreMessage.value = false;
      return [];
    }

    // 并行处理消息转换和状态更新
    final messages = await Future.wait(
      items.map((item) async {
        // 如果是发送中的消息，尝试重新发送
        if (item.status == IMBoyMessageStatus.sending) {
          await sendWsMsg(item);
        }
        return await item.toTypeMessage();
      }),
    );

    // 更新下一页起始ID
    state.nextAutoId.value = items.first.autoId;
    // 返回反转后的列表(时间倒序)
    return messages.toList();
  }

  /// 通过WebSocket发送消息
  Future<bool> sendWsMsg(MessageModel obj) async {
    if (obj.status == IMBoyMessageStatus.sending) {
      Map<String, dynamic> msg = {
        'id': obj.id,
        'type': obj.type,
        'from': obj.fromId,
        'to': obj.toId,
        'payload': obj.payload,
        'created_at': obj.createdAt,
      };
      return await WebSocketService.to.sendMessage(json.encode(msg));
    }
    return true;
  }

  /// 从UI层消息模型转换为数据库模型
  MessageModel getMsgFromTMsg(
      String type,
      String conversationUk3,
      Message message,
      ) {
    Map<String, dynamic> payload = {};

    // 根据消息类型构造payload
    if (message is TextMessage) {
      payload = {
        "msg_type": "text",
        "text": message.text,
      };
    } else if (message is ImageMessage) {
      payload = {
        "msg_type": "image",
        "name": message.text,
        "text": message.text, // 用于搜索
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
        "md5": message.metadata?['md5'],
      };
    } else if (message is FileMessage) {
      payload = {
        "msg_type": "file",
        "name": message.name,
        "text": message.name, // 用于搜索
        "size": message.size,
        "uri": message.source,
        "mime_type": message.mimeType,
        "md5": message.metadata?['md5'],
      };
    } else if (message is CustomMessage) {
      payload = {...?message.metadata};
      payload['msg_type'] = 'custom';
    }

    // 处理系统提示信息
    String sysPrompt = message.metadata?['sys_prompt'] ?? '';
    if (strNoEmpty(sysPrompt)) {
      payload['sys_prompt'] = sysPrompt;
    }
    payload['peer_id'] = message.metadata?['peer_id'];

    MessageModel obj = MessageModel(
      autoId: 0,
      message.id,
      type: type,
      fromId: message.authorId,
      toId: message.metadata?['peer_id'],
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
      conversationUk3: conversationUk3,
      status: IMBoyMessageStatus.sending,
    );
    obj.status = obj.toStatus(message.status ?? MessageStatus.sending);
    return obj;
  }

  /// 添加消息到会话
  /// [fromId] 发送者ID
  /// [toId] 接收者ID
  /// [avatar] 头像
  /// [title] 标题
  /// [type] 消息类型
  /// [message] 消息对象
  /// [sendToServer] 是否发送到服务器
  Future<void> addMessage(
      String fromId,
      String toId,
      String? avatar,
      String title,
      String type,
      Message message, {
        bool sendToServer = true,
      }) async {
    // 构造会话副标题
    String subtitle = MessageModel.conversationSubtitle(message);
    String msgType = MessageModel.conversationMsgType(message);
    int createdAt = DateTimeHelper.millisecond();

    // 查找或创建会话
    ConversationRepo repo = ConversationRepo();
    ConversationModel? conversation = await repo.findByPeerId(type, toId);
    conversation ??= await Get.find<ConversationLogic>().createConversation(
      type: type,
      peerId: toId,
      avatar: avatar ?? '',
      title: title,
      subtitle: "",
      lastTime: createdAt,
    );

    // 更新会话信息
    await repo.updateById(conversation.id, {
      ConversationRepo.title: title,
      ConversationRepo.subtitle: subtitle,
      ConversationRepo.msgType: msgType,
      ConversationRepo.lastMsgId: message.id,
      ConversationRepo.lastTime: createdAt,
      ConversationRepo.lastMsgStatus: sendToServer ? 10 : 11,
      ConversationRepo.unreadNum: conversation.unreadNum,
      ConversationRepo.isShow: 1,
    });

    // 保存消息到数据库
    MessageModel obj = getMsgFromTMsg(type, conversation.uk3, message);
    String tb = MessageRepo.getTableName(conversation.type.toString());
    await (MessageRepo(tableName: tb)).insert(obj);

    // 通知会话更新
    eventBus.fire(conversation);
    iPrint("sendMessage $sendToServer : ${message.id}, type: $type, toId: $toId");
    // 发送到服务器
    if (sendToServer) {
      sendWsMsg(obj);
    }

    // 如果是图片消息，添加到画廊
    if (message is ImageMessage) {
      Get.find<ImageGalleryLogic>().pushToLast(
        message.id,
        message.source,
      );
    }
  }

  /// 从会话删除消息
  Future<bool> removeMessage(
      ConversationModel cm,
      Message msg,
      ) async {
    final repo = ConversationRepo();
    final tb = MessageRepo.getTableName(cm.type);
    final mRepo = MessageRepo(tableName: tb);

    // 获取最后一条消息用于更新会话
    final items = await mRepo.page(
      conversationUk3: cm.uk3,
      page: 2,
      size: 1,
    );
    final lastMsg = items.isEmpty ? null : items[0];

    // 删除消息
    await mRepo.delete(msg.id);

    // 更新会话最后消息信息
    if (lastMsg == null) {
      await repo.updateById(cm.id, {
        ConversationRepo.lastMsgId: '',
        ConversationRepo.lastMsgStatus: 0,
        ConversationRepo.msgType: 'empty',
        ConversationRepo.lastTime: 0,
        ConversationRepo.subtitle: '',
      });
    } else {
      Message msg2 = await lastMsg.toTypeMessage();
      await repo.updateById(cm.id, {
        ConversationRepo.lastMsgId: lastMsg.id,
        ConversationRepo.lastMsgStatus: lastMsg.status,
        ConversationRepo.msgType: MessageModel.conversationMsgType(msg2),
        ConversationRepo.subtitle: MessageModel.conversationSubtitle(msg2),
      });
    }

    // 通知会话更新
    ConversationModel? cm2 = await repo.findById(cm.id);
    if (cm2 != null) {
      eventBus.fire(cm2);
    }

    // 如果是图片消息，从画廊移除
    if (msg is ImageMessage) {
      Get.find<ImageGalleryLogic>().remoteFromGallery(msg.id);
    }
    return true;
  }

  /// 直接发送消息(不经过数据库)
  Future<bool> sendMessage(Map<String, dynamic> msg) async {
    return WebSocketService.to.sendMessage(json.encode(msg));
  }

  /// 标记消息为已读
  Future<bool> markAsRead(
      String type,
      String peerId,
      List<String> msgIds,
      ) async {
    Database? db = await SqliteService.to.db;
    if (db == null) {
      return false;
    }

    // 查找会话
    ConversationModel? c = await ConversationRepo().findByPeerId(type, peerId);
    if (c == null) {
      return false;
    }

    String tb = MessageRepo.getTableName(c.type);
    int newUnreadNum = c.unreadNum - msgIds.length;
    c.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;

    // 使用事务更新数据库
    bool res = await db.transaction((txn) async {
      // 更新会话未读计数
      await txn.update(
        ConversationRepo.tableName,
        {
          ConversationRepo.unreadNum: c.unreadNum,
        },
        where: "${ConversationRepo.id}=?",
        whereArgs: [c.id],
      );

      // 批量更新消息状态为已读
      for (var id in msgIds) {
        await txn.update(
          tb,
          {
            MessageRepo.status: IMBoyMessageStatus.seen,
          },
          where: "${MessageRepo.id}=?",
          whereArgs: [id],
        );
      }
      return true;
    });

    if (res) {
      // 通知会话逻辑更新
      ConversationLogic conversationLogic = Get.find<ConversationLogic>();
      conversationLogic.decreaseConversationRemind(
        c,
        msgIds.length,
      );
      conversationLogic.replace(c);
      return true;
    } else {
      return false;
    }
  }

  /// 解析系统提示信息
  String parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      sysPrompt = 'send_msg_rejected'.tr;
    } else if (sysPrompt == 'not_a_friend') {
      sysPrompt = 'send_msg_not_friend_tips'.tr;
    }
    return sysPrompt;
  }

  /// 设置系统提示信息
  Future<void> setSysPrompt(String tableName, String msgId, String sysPrompt) async {
    var repo = MessageRepo(tableName: tableName);
    MessageModel? msg = await repo.find(msgId);
    if (msg == null) return;
    Map<String, dynamic> payload = msg.payload ?? {};
    payload['msg_type'] = payload['msg_type'].toString();
    payload['sys_prompt'] = sysPrompt;

    // 更新消息状态
    await repo.update({
      'id': msgId,
      MessageRepo.status: IMBoyMessageStatus.error,
      MessageRepo.payload: payload,
    });

    msg.status = IMBoyMessageStatus.error;
    msg.payload = payload;

    // 通知消息状态更新
    eventBus.fire([await msg.toTypeMessage()]);

    // 更新会话状态
    Get.find<ConversationLogic>().updateConversationByMsgId(
      msgId,
      {
        ConversationRepo.payload: {'sys_prompt': sysPrompt},
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
      },
    );
  }

  /// 获取消息长按菜单项
  List<popupmenu.MenuItemProvider> getPopupMenuItems(Message message) {
    List<popupmenu.MenuItemProvider> items = [];

    // 检查是否可以复制
    bool canCopy = false;
    String customType = message.metadata?['custom_type'] ?? '';
    if (message is TextMessage) {
      canCopy = true;
    } else if (customType == 'quote') {
      canCopy = true;
    }

    // 添加复制菜单项
    if (canCopy) {
      items.add(popupmenu.MenuItem(
        title: 'button_copy'.tr,
        userInfo: {"id": "copy", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.copy,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 检查是否可以保存
    bool canSave = false;
    if (message is ImageMessage) {
      canSave = true;
    } else if (message is FileMessage) {
      canSave = true;
    } else if (customType == 'video') {
      canSave = true;
    } else if (customType == 'audio') {
      canSave = true;
    }

    // 添加保存菜单项
    if (canSave) {
      items.add(popupmenu.MenuItem(
        title: 'button_save'.tr,
        userInfo: {"id": "save", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.save_alt,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 检查是否可以收藏
    bool canCollect =
    UserCollectLogic.getCollectKind(message) > 0 ? true : false;
    if (canCollect) {
      items.add(popupmenu.MenuItem(
        title: 'favorites'.tr,
        userInfo: {"id": "collect", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.collections_bookmark,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 检查是否已撤回
    bool isRevoked = (message is CustomMessage) && customType == 'revoked';
    if (customType == 'webrtc_audio' || customType == 'webrtc_video') {
      isRevoked = true;
    }

    // 添加转发和引用菜单项
    if (!isRevoked) {
      items.add(popupmenu.MenuItem(
        title: 'forward'.tr,
        userInfo: {"id": "transpond", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          fontSize: 10.0,
          color: Color(0xffc5c5c5),
        ),
        image: const Icon(
          Icons.moving,
          color: Color(0xffc5c5c5),
        ),
      ));
      items.add(popupmenu.MenuItem(
        title: 'quote'.tr,
        userInfo: {"id": "quote", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: const Icon(
          Icons.format_quote,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 如果是自己发送的消息且未撤回，添加撤回菜单项
    if (message.authorId == UserRepoLocal.to.currentUid &&
        !isRevoked) {
      items.add(
        popupmenu.MenuItem(
          title: 'revoke'.tr,
          userInfo: {"id": "revoke", "msg": message},
          textAlign: TextAlign.center,
          textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: const Icon(
            Icons.layers_clear_rounded,
            size: 16,
            color: Color(0xffc5c5c5),
          ),
        ),
      );
    }

    // 添加删除菜单项
    items.add(popupmenu.MenuItem(
      title: 'button_delete'.tr,
      userInfo: {"id": "delete", "msg": message},
      textAlign: TextAlign.center,
      textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
      image: const Icon(
        Icons.remove_circle_outline_rounded,
        size: 16,
        color: Color(0xffc5c5c5),
      ),
    ));
    return items;
  }

  /// 保存文件到本地
  Future<void> saveFile(String name, String uri) async {
    File? tmpF = await IMBoyCacheManager().getSingleFile(
      uri,
      key: EncrypterService.md5(uri),
    );

    String ext = StringHelper.ext(uri);
    MimeType? mt = MimeType.get(ext.toUpperCase());

    // 使用FileSaver保存文件
    String? path = await FileSaver.instance.saveAs(
      name: name,
      file: tmpF,
      fileExtension: ext,
      mimeType: mt ?? MimeType.get('Other')!,
    );

    if (path != null) {
      EasyLoading.showToast('save_success'.tr);
    }
  }


  /// 加载更多消息（可用于初始加载和分页加载）
  /// [isInitial] 是否首次加载（首次清空消息及游标）
  /// 返回新加载的消息列表
  Future<List<Message>> loadMoreMessages(ConversationModel obj, {bool isInitial = false}) async {
    iPrint('_loadMoreMessages: isInitial=$isInitial, hasMore=${state.hasMoreMessage.value}, loading=${state.isLoading.value}');
    // 初始化时清空游标和消息
    if (isInitial) {
      state.nextAutoId.value = 0;
      state.hasMoreMessage.value = true;
      chatController.setMessages([]);
    }
    if (state.isLoading.value || !state.hasMoreMessage.value) return [];

    state.isLoading.value = true;
    final items = await pageMessages(obj, state.pageSize);
    state.isLoading.value = false;

    if (items.isEmpty) {
      state.hasMoreMessage.value = false;
      return [];
    }

    // 去重插入
    final currentIds = chatController.messages.map((e) => e.id).toSet();
    final newItems = items.where((msg) => !currentIds.contains(msg.id)).toList();

    if (newItems.isNotEmpty) {
      chatController.insertAllMessages([
        ...chatController.messages,
        ...newItems,
      ]);
      // 更新游标（假设消息ID单调递减）
      state.nextAutoId.value =
          newItems.last.metadata?['auto_id'] ?? state.nextAutoId.value;

      // 标记新消息为已读
      // TODO _markMessagesAsRead
      // await _markMessagesAsRead(newItems);
    }

    return newItems;
  }

  /// 滚动到指定消息ID，如果消息未加载则自动加载历史消息
  Future<void> scrollToMessage(String chatType, MessageID messageId) async {
    if (messageId.isEmpty) return;

    bool messageExists() => chatController.messages.any((m) => m.id == messageId);

    // 1. 先查本地有没有
    if (messageExists()) {
      await chatController.scrollToMessage(messageId);
      return;
    }

    // 2. 查数据库是否有
    String tb = MessageRepo.getTableName(chatType);
    iPrint("chatType: $chatType, tableName: $tb, messageId: $messageId");
    MessageModel? msg = await (MessageRepo(tableName: tb)).find(messageId);
    if (msg == null) {
      EasyLoading.showError('未找到该消息');
      return;
    }
    String toId = msg.toId ?? '';
    ConversationModel? conversation = await (ConversationRepo()).findByPeerId(chatType, toId);

    int maxAttempts = 10;
    int attempts = 0;
    bool allMessagesLoaded = false;
    bool found = false;

    while (!allMessagesLoaded && attempts < maxAttempts) {
      // 3. 检查消息是否已加载到内存
      if (messageExists()) {
        found = true;
        break;
      }
      // 4. 触发加载更多（异步等待加载完成）
      if (conversation != null) {
        await loadMoreMessages(conversation);
      }
      // 5. 检查是否已无更多历史消息
      allMessagesLoaded = !state.hasMoreMessage.value;
      attempts++;
    }

    // 如果经过多次尝试仍未找到消息
    if (!found && !messageExists()) {
      EasyLoading.showError('未能定位到该消息');
      return;
    }

    // 等待动画完成
    await Future.delayed(const Duration(milliseconds: 100));
    await chatController.scrollToMessage(messageId);
  }
}