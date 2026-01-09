import 'dart:async';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/websocket.dart';

/// ACK管理器 - 负责ACK的发送和重试
///
/// 功能：
/// 1. 发送ACK并记录待确认ACK
/// 2. 自动重试失败的ACK（最多3次）
/// 3. 提供ACK状态查询
class AckManager extends GetxService {
  static AckManager get to => Get.find();

  /// 待确认的ACK映射表
  /// Key: msgId, Value: _PendingAck
  final Map<String, _PendingAck> _pendingAcks = {};

  /// 最大重试次数
  static const int _maxRetries = 3;

  /// 重试间隔（毫秒）
  static const int _retryInterval = 3000; // 3秒

  @override
  void onInit() {
    super.onInit();
    iPrint('✅ [ACK_MANAGER] AckManager initialized');
  }

  /// 发送ACK（带重试机制）
  ///
  /// [type] 消息类型（C2C、C2G、S2C等）
  /// [msgId] 消息ID
  void sendAck(String type, String msgId) {
    // 检查deviceId
    if (deviceId.isEmpty) {
      iPrint('❌ [ACK_MANAGER] deviceId 为空，跳过ACK: msgId=$msgId');
      return;
    }

    // 【修复】移除去重逻辑，每次都发送 ACK 确保服务器收到
    // 如果服务器多次发送同一条消息（网络重试），客户端应该每次都返回 ACK

    final ackMsg = generateAckMessage(type, msgId);

    // 记录待确认的ACK
    _pendingAcks[msgId] = _PendingAck(
      msgId: msgId,
      type: type,
      content: ackMsg,
      sendTime: DateTimeHelper.millisecond(),
      retryCount: 0,
    );

    iPrint('📤 [ACK_MANAGER] 发送ACK: msgId=$msgId, type=$type, retryCount=0');
    _sendAckInternal(msgId);

    // 设置重试定时器
    _scheduleRetry(msgId);
  }

  /// 生成 ACK 消息格式（唯一维护点）
  ///
  /// [type] 消息类型（C2C、C2G、S2C等）
  /// [msgId] 消息ID
  ///
  /// 返回格式：CLIENT_ACK,type,msgId,deviceId
  ///
  /// 抛出 [ArgumentError] 当参数无效时
  String generateAckMessage(String type, String msgId) {
    // 参数验证：防止空值导致格式错误
    if (type.isEmpty || msgId.isEmpty) {
      iPrint('❌ [ACK_MANAGER] generateAckMessage 参数无效: type=$type, msgId=$msgId');
      throw ArgumentError('ACK type and msgId cannot be empty');
    }
    if (deviceId.isEmpty) {
      iPrint('⚠️ [ACK_MANAGER] deviceId 为空，ACK 可能无效');
    }
    return 'CLIENT_ACK,$type,$msgId,$deviceId';
  }

  /// 直接发送 ACK（不经过重试队列，用于需要立即发送的场景）
  void sendAckDirect(String type, String msgId) {
    try {
      // 【新增】检查 deviceId 是否为空
      if (deviceId.isEmpty) {
        iPrint('❌ [WS_ACK] deviceId 为空，无法发送ACK: msgId=$msgId, type=$type');
        return;
      }

      final ackMsg = generateAckMessage(type, msgId);
      iPrint('📤 [WS_ACK] 准备发送ACK: msgId=$msgId, type=$type, content=$ackMsg');

      // 【新增】检查 WebSocket 连接状态
      if (!Get.isRegistered<WebSocketService>()) {
        iPrint('❌ [WS_ACK] WebSocketService 未注册，无法发送ACK: msgId=$msgId');
        return;
      }

      final wsStatus = WebSocketService.to.status.value;
      iPrint('🔌 [WS_ACK] WebSocket 状态: $wsStatus');

      final success = WebSocketService.to.sendDirect(ackMsg);
      if (success) {
        iPrint('⚡ [WS_ACK] 直接发送ACK成功: msgId=$msgId, type=$type');
      } else {
        iPrint('⚠️ [WS_ACK] ACK发送失败: msgId=$msgId, type=$type, wsStatus=$wsStatus');
      }
    } catch (e) {
      iPrint('❌ [WS_ACK] ACK发送失败: msgId=$msgId, type=$type, error=$e');
    }
  }

  /// 内部发送ACK方法
  void _sendAckInternal(String msgId) {
    final ack = _pendingAcks[msgId];
    if (ack == null) {
      iPrint('⚠️ [ACK_MANAGER] ACK不存在（可能已确认）: msgId=$msgId');
      return;
    }

    try {
      // 使用WebSocketService发送ACK
      WebSocketService.to.sendMessage(ack.content, null);
      iPrint('✅ [ACK_MANAGER] ACK发送成功: msgId=$msgId, retryCount=${ack.retryCount}');
    } catch (e) {
      iPrint('❌ [ACK_MANAGER] ACK发送异常: msgId=$msgId, error=$e');
      // 不立即重试，等待定时器触发
    }
  }

  /// 安排重试
  void _scheduleRetry(String msgId) {
    Timer(Duration(milliseconds: _retryInterval), () {
      final ack = _pendingAcks[msgId];

      // ACK已被确认，不需要重试
      if (ack == null) {
        iPrint('✅ [ACK_MANAGER] ACK已确认，取消重试: msgId=$msgId');
        return;
      }

      // 达到最大重试次数
      if (ack.retryCount >= _maxRetries) {
        iPrint('❌ [ACK_MANAGER] ACK发送失败，已达最大重试次数: msgId=$msgId');
        _pendingAcks.remove(msgId);
        return;
      }

      // 重试
      ack.retryCount++;
      iPrint('🔄 [ACK_MANAGER] ACK重试 ${ack.retryCount}/$_maxRetries: msgId=$msgId');
      _sendAckInternal(msgId);

      // 继续安排下一次重试
      if (ack.retryCount < _maxRetries) {
        _scheduleRetry(msgId);
      }
    });
  }

  /// ACK确认后删除记录（当收到服务端确认时调用）
  ///
  /// 目前服务端没有返回ACK确认，这个方法预留
  /// 未来可以通过服务端返回的ACK确认来调用
  void ackConfirmed(String msgId) {
    if (_pendingAcks.remove(msgId) != null) {
      iPrint('✅ [ACK_MANAGER] ACK已确认: msgId=$msgId');
    }
  }

  /// 获取待确认ACK数量
  int get pendingCount => _pendingAcks.length;

  /// 获取待确认ACK列表
  List<String> get pendingAckList => _pendingAcks.keys.toList();

  /// 清理所有待确认ACK
  void clear() {
    final count = _pendingAcks.length;
    _pendingAcks.clear();
    iPrint('🗑️ [ACK_MANAGER] 已清理 $count 个待确认ACK');
  }

  /// 清理过期的待确认ACK（超过30秒）
  void cleanupExpired() {
    final now = DateTimeHelper.millisecond();
    final expiredKeys = <String>[];

    _pendingAcks.forEach((msgId, ack) {
      final age = now - ack.sendTime; // 毫秒差
      if (age > 30000) { // 30秒
        expiredKeys.add(msgId);
      }
    });

    if (expiredKeys.isNotEmpty) {
      for (final msgId in expiredKeys) {
        _pendingAcks.remove(msgId);
      }
      iPrint('🗑️ [ACK_MANAGER] 清理了 ${expiredKeys.length} 个过期ACK');
    }
  }

  /// 获取ACK统计信息
  Map<String, dynamic> getStats() {
    return {
      'pending_count': _pendingAcks.length,
      'max_retries': _maxRetries,
      'retry_interval_ms': _retryInterval,
      'pending_ack_list': pendingAckList,
    };
  }
}

/// 待确认的ACK
class _PendingAck {
  final String msgId;
  final String type;
  final String content;
  final int sendTime; // 毫秒时间戳
  int retryCount;

  _PendingAck({
    required this.msgId,
    required this.type,
    required this.content,
    required this.sendTime,
    required this.retryCount,
  });

  /// 转换为JSON（用于调试）
  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'type': type,
      'content': content,
      'sendTime': sendTime, // 毫秒时间戳
      'sendTimeIso': DateTime.fromMillisecondsSinceEpoch(sendTime).toIso8601String(),
      'retryCount': retryCount,
    };
  }
}
