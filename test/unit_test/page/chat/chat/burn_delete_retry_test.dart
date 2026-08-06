import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// 阅后即焚销毁失败必须重试，不得静默放弃
///
/// 反转断言（Rule 7）：原实现 `deleteBurnMessage` 外层是 `catch (_) {}`，
/// 吞掉异常后照样把定时器从 map 里摘掉 —— 销毁失败即永久失败，消息留在
/// 本地 SQLite 可被取证。本测试锁定"失败后仍排着重试"这一不变量。
///
/// 触发失败的手法：测试环境未初始化 sqflite，`MessageRepo.find` 必然抛异常，
/// 正好落进销毁失败分支，无需 mock。
/// （`deleteBurnMessage` 只用到 `conversation.type`，不触碰依赖登录态的 uk3。）
/// 未知 type → `MessageRepo.getTableName` 返回空表名 → 查询必然失败，
/// 以此把执行流打进 `deleteBurnMessage` 的销毁失败分支。
ConversationModel unknownTypeConversation() => ConversationModel(
  id: 0,
  peerId: 0,
  avatar: '',
  title: '',
  subtitle: '',
  type: 'NO_SUCH_TYPE',
  msgType: 'empty',
  unreadNum: 0,
);

void main() {
  test('销毁失败时排下重试定时器，不把消息从定时器表里摘掉', () async {
    final Map<String, Timer> timers = {};
    const service = ChatBurnService();

    await service.deleteBurnMessage(
      burnDeleteTimers: timers,
      chatService: null,
      conversation: unknownTypeConversation(),
      messageId: 'msg-1',
      onExpire: (_, __) async {},
    );

    expect(
      timers.containsKey('msg-1'),
      isTrue,
      reason: '销毁失败后必须保留重试定时器，否则消息永远留在本地库',
    );
    expect(timers['msg-1']!.isActive, isTrue);

    timers['msg-1']!.cancel();
  });

  test('重试次数耗尽后停止重试，不无限占用定时器表', () async {
    final Map<String, Timer> timers = {};
    const service = ChatBurnService();

    await service.deleteBurnMessage(
      burnDeleteTimers: timers,
      chatService: null,
      conversation: unknownTypeConversation(),
      messageId: 'msg-2',
      onExpire: (_, __) async {},
      attempt: ChatBurnService.maxBurnDeleteAttempts - 1,
    );

    expect(
      timers.containsKey('msg-2'),
      isFalse,
      reason: '最后一次尝试失败后应清理定时器，避免无限重试',
    );
  });
}
