import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Transaction;

class TextSendMessages extends Fake implements MessageRepository {
  final rows = <String, MessageModel>{};

  @override
  Future<MessageModel?> find(String id, {Transaction? txn}) async => rows[id];
}

class TextSendChat extends ChatNotifier {
  TextSendChat(this.messages);
  final TextSendMessages messages;
  bool deliveredDuringRetry = false;
  final submitted = <Message>[];
  final retried = <String>[];
  bool succeeds = true;
  Completer<bool>? gate;
  Object? failure;

  @override
  ChatState build() => ChatState();

  @override
  Future<bool> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type,
    Message message, {
    bool sendToServer = true,
  }) async {
    submitted.add(message);
    if (failure != null) throw failure!;
    final result = gate == null ? succeeds : await gate!.future;
    messages.rows[message.id] = MessageModel(
      message.id,
      autoId: messages.rows.length + 1,
      type: type,
      status: result ? IMBoyMessageStatus.sent : IMBoyMessageStatus.error,
      fromId: fromId,
      toId: toId,
      payload: {'text': (message as TextMessage).text},
      isAuthor: 1,
      conversationUk3: '${type}_${fromId}_$toId',
    );
    return result;
  }

  @override
  Future<bool> retryMessage(String messageId, String messageType) async {
    retried.add(messageId);
    if (deliveredDuringRetry) {
      messages.rows[messageId]!.status = IMBoyMessageStatus.delivered;
      return false;
    }
    if (succeeds) messages.rows[messageId]!.status = IMBoyMessageStatus.sent;
    return succeeds;
  }
}
