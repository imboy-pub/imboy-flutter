import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// 离线消息处理服务
class MessageOfflineService {
  static MessageOfflineService get to => Get.find();

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

        Map<String, dynamic> payload = resp.payload['payload'] ?? {};
        bool overallHasMore = false;

        // 处理 C2C 离线消息
        Map<String, dynamic> c2cData = payload['c2c'] ?? {};
        if (c2cData.isNotEmpty) {
          List<dynamic> c2cMessages = c2cData['list'] ?? [];
          if (c2cMessages.isNotEmpty) {
            await _processOfflineMessages(c2cMessages, 'C2C');
          }
          if (c2cData['has_more'] == true) {
            overallHasMore = true;
          }
        }

        // 处理 C2G 离线消息
        Map<String, dynamic> c2gData = payload['c2g'] ?? {};
        if (c2gData.isNotEmpty) {
          List<dynamic> c2gMessages = c2gData['list'] ?? [];
          if (c2gMessages.isNotEmpty) {
            await _processOfflineMessages(c2gMessages, 'C2G');
          }
          if (c2gData['has_more'] == true) {
            overallHasMore = true;
          }
        }

        // 处理 S2C 离线消息
        Map<String, dynamic> s2cData = payload['s2c'] ?? {};
        if (s2cData.isNotEmpty) {
          List<dynamic> s2cMessages = s2cData['list'] ?? [];
          if (s2cMessages.isNotEmpty) {
            await _processOfflineMessages(s2cMessages, 'S2C');
          }
          if (s2cData['has_more'] == true) {
            overallHasMore = true;
          }
        }


        hasMore = overallHasMore;

        if (hasMore) {
          iPrint("还有更多离线消息，继续拉取");
          // 短暂延迟，避免频繁请求
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      iPrint("离线消息拉取完成，共拉取 $pullCount 次");

      return true;
    } catch (e) {
      iPrint("拉取离线消息异常: $e");
      EasyLoading.showError('拉取离线消息异常: $e');
      return false;
    }
  }

  /// 处理离线消息
  Future<void> _processOfflineMessages(List<dynamic> messages, String type) async {
    if (messages.isEmpty) return;

    iPrint("处理 $type 离线消息，共 ${messages.length} 条");

    try {
      MessageRepo messageRepo = MessageRepo(
        tableName: MessageRepo.getTableName(type),
      );

      // 转换消息数据格式
      List<Map<String, dynamic>> processedMessages = [];
      for (final msg in messages) {
        if (msg is Map<String, dynamic>) {
          // 添加消息类型字段
          msg['type'] = type;
          processedMessages.add(msg);
        }
      }

      // 批量插入消息
      List<String>? msgIds = await messageRepo.batchInsertOfflineMessages(processedMessages);

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
        iPrint("发送离线消息确认成功");
      }
    } catch (e) {
      iPrint("发送离线消息确认异常: $e");
    }
  }
}