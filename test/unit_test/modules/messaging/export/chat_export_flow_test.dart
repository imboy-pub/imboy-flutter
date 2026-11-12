/// W5-G3-1 / G3-2 平台组装层（runChatExportFlow）验收：
/// - flag 关闭 → 入口直接 flagDisabled，逐消息映射零调用（G3-2）；
/// - confirm 闭包跨 await 后 context 已卸载 → fail-closed 拒绝、
///   不弹窗、不炸（G3-1）。
///
/// 注：两用例都停在零副作用终态（flagDisabled / e2eeDeclined），不触达
/// 真实落盘（testWidgets fake-async 里 dart:io 异步不完成）；落盘与分享
/// 由 controller 单测（注入 fake）覆盖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_controller.dart';
import 'package:imboy/modules/messaging/presentation/export/chat_export_e2ee_confirm_dialog.dart';
import 'package:imboy/modules/messaging/presentation/export/chat_export_flow.dart';
import 'package:imboy/service/encryption_mode.dart';

core.Message _textMessage() => core.TextMessage(
  authorId: '42',
  createdAt: DateTime(2026, 11, 11, 9, 0, 0),
  id: 'm1',
  text: '机密内容',
);

void main() {
  tearDown(() {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  testWidgets('flag 关闭：入口直接 flagDisabled，逐消息映射零调用（W5-G3-2）', (tester) async {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
    var resolverCalls = 0;

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            captured = ctx;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final result = await runChatExportFlow(
      captured,
      conversationUk3: 'conv-uk3',
      conversationTitle: '张三',
      messages: [_textMessage()],
      chatType: 'C2C',
      senderNameResolver: (authorId) async {
        resolverCalls++;
        return '张三';
      },
    );

    expect(result.status, ChatExportStatus.flagDisabled);
    // 逐消息映射（含发送者名 DB 查询）必须零调用：flag 判定前置于映射。
    expect(resolverCalls, 0, reason: 'flag 关闭时不得进入逐消息映射');
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm 闭包跨 await 后 context 已卸载：fail-closed 拒绝（W5-G3-1）', (
    tester,
  ) async {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
      FeatureKeys.chatExportShareV1: true,
    });
    // strictE2ee + 已初始化：C2C 判定为加密会话（无 AiPlaintextGate 分支，
    // toId 缺省跳过），controller 必然走到 confirm 一步。
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            captured = ctx;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    // 卸载捕获的 context（真实场景 = 用户在映射/加密判定的 await 期间退出页面）。
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final result = await runChatExportFlow(
      captured,
      conversationUk3: 'conv-uk3',
      conversationTitle: '张三',
      messages: [_textMessage()],
      chatType: 'C2C',
      senderNameResolver: (authorId) async => '张三',
    );

    expect(result.status, ChatExportStatus.e2eeDeclined);
    // 不得尝试弹窗（卸载 context 上弹窗即抛「deactivated widget」），
    // 也不得产生未处理异常。
    expect(find.byKey(ChatExportDialogKeys.confirm), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
