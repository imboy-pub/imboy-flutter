import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../page/conversation/conversation_logic.dart';
import 'message_s2c.dart';

/// 离线消息处理服务
class MessageOfflineService {
  static MessageOfflineService get to => Get.find();

  /// 离线消息拉取请求事件的订阅
  StreamSubscription<OfflineMessagesPullRequestedEvent>? _pullRequestedSubscription;

  /// 初始化服务（订阅事件）
  void onInit() {
    // 订阅离线消息拉取请求事件（解耦：通过事件总线接收拉取请求）
    _pullRequestedSubscription = AppEventBus.on<OfflineMessagesPullRequestedEvent>().listen((event) {
      // 异步处理，避免阻塞事件总线
      Future.microtask(() async {
        try {
          await pullOfflineMessages();
          iPrint("离线消息处理完成，来源: ${event.source}");
        } catch (e) {
          iPrint("离线消息处理失败: $e");
        }
      });
    });
  }

  /// 释放资源（取消订阅）
  void onDispose() {
    _pullRequestedSubscription?.cancel();
  }

  /// 拉取离线消息
  Future<bool> pullOfflineMessages() async {
    try {
      iPrint("开始拉取离线消息");

      bool hasMore = true;
      int pullCount = 0;
      const int maxPullCount = 20; // 防止无限循环

      while (hasMore && pullCount < maxPullCount) {
        pullCount++;
        iPrint("第 $pullCount 次拉取离线消息");

        // 调用 /msg/offline 接口
        final resp = await HttpClient.client.get(API.msgOffline);

        if (resp.code != 0) {
          iPrint("拉取离线消息失败: ${resp.msg}");
          EasyLoading.showError('拉取离线消息失败: ${resp.msg}');
          return false;
        }

        // 修复双重嵌套问题：根据日志，resp.payload已经包含payload数据
        Map<String, dynamic> payload = resp.payload ?? {};
        iPrint("解析离线消息payload: ${payload.keys}");
        iPrint("完整响应数据结构: ${resp.payload}");
        bool overallHasMore = false;

        // 处理 C2C 离线消息
        Map<String, dynamic> c2cData = payload['c2c'] ?? {};
        iPrint("C2C数据: $c2cData");
        if (c2cData.isNotEmpty) {
          List<dynamic> c2cMessages = c2cData['list'] ?? [];
          iPrint("C2C消息列表长度: ${c2cMessages.length}");
          if (c2cMessages.isNotEmpty) {
            await _processOfflineMessages(c2cMessages, 'C2C');
          }
          if (c2cData['has_more'] == true) {
            overallHasMore = true;
          }
        } else {
          iPrint("C2C数据为空");
        }

        // 处理 C2G 离线消息
        Map<String, dynamic> c2gData = payload['c2g'] ?? {};
        iPrint("C2G数据: $c2gData");
        if (c2gData.isNotEmpty) {
          List<dynamic> c2gMessages = c2gData['list'] ?? [];
          iPrint("C2G消息列表长度: ${c2gMessages.length}");
          if (c2gMessages.isNotEmpty) {
            await _processOfflineMessages(c2gMessages, 'C2G');
          }
          if (c2gData['has_more'] == true) {
            overallHasMore = true;
          }
        } else {
          iPrint("C2G数据为空");
        }

        // 处理 S2C 离线消息
        Map<String, dynamic> s2cData = payload['s2c'] ?? {};
        iPrint("S2C数据: $s2cData");
        if (s2cData.isNotEmpty) {
          List<dynamic> s2cMessages = s2cData['list'] ?? [];
          iPrint("S2C消息列表长度: ${s2cMessages.length}");
          if (s2cMessages.isNotEmpty) {
            await _processOfflineMessages(s2cMessages, 'S2C');
          }
          if (s2cData['has_more'] == true) {
            overallHasMore = true;
          }
        } else {
          iPrint("S2C数据为空");
        }


        hasMore = overallHasMore;

        if (hasMore) {
          iPrint("还有更多离线消息，继续拉取");
          // 短暂延迟，避免频繁请求
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      iPrint("离线消息拉取完成，共拉取 $pullCount 次");

      // 主动刷新会话列表，确保UI及时更新
      try {
        final conversationLogic = Get.find<ConversationLogic>();
        await conversationLogic.conversationsList();
        iPrint("已主动刷新会话列表");
      } catch (e) {
        iPrint("刷新会话列表失败: $e");
      }

      return true;
    } catch (e) {
      iPrint("拉取离线消息异常: $e");
      EasyLoading.showError('拉取离线消息异常: $e');
      return false;
    }
  }

  /// 处理离线消息
  Future<void> _processOfflineMessages(List<dynamic> messages, String type) async {
    iPrint("进入 _processOfflineMessages 方法，类型: $type, 消息数量: ${messages.length}");
    if (messages.isEmpty) {
      iPrint("消息列表为空，直接返回");
      return;
    }

    iPrint("开始处理 $type 离线消息，共 ${messages.length} 条");

    try {
      // 直接调用批量插入，无需创建 MessageRepo 实例
      // 转换消息数据格式，避免修改原始数据
      List<Map<String, dynamic>> processedMessages = [];
      for (final msg in messages) {
        if (msg is Map<String, dynamic>) {
          // 创建新的消息副本，避免修改原始数据
          Map<String, dynamic> msgCopy = Map<String, dynamic>.from(msg);
          msgCopy['type'] = type;
          processedMessages.add(msgCopy);
        }
      }

      // 使用静态方法批量插入消息
      List<String>? msgIds = await MessageRepo(
        tableName: MessageRepo.getTableName(type),
      ).batchInsertOfflineMessages(
        processedMessages,
        onS2CMessage: (msgData) async {
          // 处理 S2C 消息
          await MessageS2CService.switchS2C(msgData);
        },
      );

      if (msgIds != null && msgIds.isNotEmpty) {
        // 发送确认消息
        await _sendOfflineAck(type, msgIds);
      }
      iPrint("$type 离线消息处理完成");
    } catch (e) {
      iPrint("处理 $type 离线消息失败: $e");
      rethrow;
    }
  }

  /// 发送离线消息确认
  Future<void> _sendOfflineAck(String type, List<String> msgIds) async {
    try {
      final resp = await HttpClient.client.post(API.msgOfflineAck, data: {
        "type": type,
        "msg_ids": msgIds,
      });
      if (resp.code != 0) {
        iPrint("发送离线消息确认失败: ${resp.msg}");
      } else {
        // iPrint("发送离线消息确认成功");
      }
    } catch (e, s) {
      iPrint("发送离线消息确认异常: $e $s");
    }
  }
}