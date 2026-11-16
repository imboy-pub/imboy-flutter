part of 'message_offline.dart';

/// 处理离线消息
Future<bool> _writeOfflineBatch(
  MessageOfflineService service,
  List<dynamic> messages,
  String type,
  void Function() requireCurrent,
  HttpClient client,
) async {
  if (messages.isEmpty) {
    return true;
  }

  iPrint('开始处理 $type 离线消息，共 ${messages.length} 条');

  try {
    // 转换消息数据格式，避免修改原始数据
    final processedMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg is Map<String, dynamic>) {
        processedMessages.add(
          MessageOfflineService.normalizeForReceive(msg, type),
        );
      }
    }

    final encryptedAckIds = <String>[];
    final ordinaryMessages = <Map<String, dynamic>>[];
    for (final msg in processedMessages) {
      requireCurrent();
      if (!MessageOfflineService.requiresSecureReceivePath(msg)) {
        ordinaryMessages.add(msg);
        continue;
      }

      // 毒丸隔离：单条加密消息入库失败只跳过本条（不入 ACK，服务端
      // 保留 pending 下次重拉重试），不再让整批消息（含已入库的普通
      // 消息）都卡住不 ACK，避免同批消息每次上线被反复重拉
      final msgId = (msg['msg_id'] ?? msg['id'])?.toString() ?? '';
      try {
        final committed = await MessageService.to.persistInboundMessage(msg);
        requireCurrent();
        if (!committed) {
          throw StateError('encrypted offline message not committed');
        }
        if (msgId.isNotEmpty) encryptedAckIds.add(msgId);
      } on Object catch (e) {
        requireCurrent();
        iPrint('加密离线消息入库失败已隔离 msgId=$msgId err=${e.runtimeType}');
      }
    }

    final ordinaryAckIds = <String>[];
    Object? ordinaryFailure;
    StackTrace? ordinaryFailureStack;
    if (ordinaryMessages.isNotEmpty) {
      requireCurrent();
      try {
        final ids = await MessageRepo(tableName: MessageRepo.getTableName(type))
            .batchInsertOfflineMessages(
              ordinaryMessages,
              onS2CMessage: (msgData) async {
                // 处理 S2C 消息
                await MessageS2CService.switchS2C(
                  msgData,
                  propagateErrors: true,
                );
              },
            );
        requireCurrent();
        ordinaryAckIds.addAll(ids ?? <String>[]);
      } on Object catch (e, stack) {
        requireCurrent();
        // 批量入库失败：普通消息不入 ACK（服务端保留 pending 下次重拉，
        // msg_id 幂等兜底重复插入），已入库的加密消息仍正常 ACK
        iPrint('普通离线消息批量入库失败本批不ACK err=${e.runtimeType}');
        ordinaryFailure = e;
        ordinaryFailureStack = stack;
      }
    }
    final msgIds = {...encryptedAckIds, ...ordinaryAckIds}.toList();

    if (msgIds.isNotEmpty) {
      requireCurrent();
      // 发送确认消息
      await service._sendOfflineAck(type, msgIds, client, requireCurrent);
      requireCurrent();
    }
    // 已提交的安全消息仍可 ACK，但失败批次不能推进游标或计为成功。
    if (ordinaryFailure != null) {
      Error.throwWithStackTrace(ordinaryFailure, ordinaryFailureStack!);
    }
    iPrint('$type 离线消息处理完成');
    final acknowledged = msgIds.toSet();
    return processedMessages.length == messages.length &&
        processedMessages.every((message) {
          final id = (message['msg_id'] ?? message['id'])?.toString() ?? '';
          return id.isNotEmpty && acknowledged.contains(id);
        });
  } on Object catch (e) {
    iPrint('处理 $type 离线消息失败: ${e.runtimeType}');
    rethrow;
  }
}
