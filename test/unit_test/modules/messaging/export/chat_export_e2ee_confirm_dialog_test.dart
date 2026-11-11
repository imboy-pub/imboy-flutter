/// W3-J E2EE 导出确认弹窗 widget 测试（EXP-02）：
/// 渲染 + 稳定 Key；确认/取消两路；取消零副作用（零写入、gateway 零调用）。
///
/// 注：writer 用内存 fake——testWidgets 的 fake-async 环境里 dart:io
/// 异步 Future 不会完成；真实落盘/删除由 controller 单测覆盖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_controller.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_temp_file_writer.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart' as domain;
import 'package:imboy/modules/messaging/presentation/export/chat_export_e2ee_confirm_dialog.dart';
import 'package:imboy/service/message_type_constants.dart';

class _RecordingGateway implements ChatShareGateway {
  final List<ChatShareFilesRequest> fileRequests = [];

  @override
  Future<ChatShareOutcome> shareText(String text, {String? subject}) async =>
      const ChatShareOutcome.shared();

  @override
  Future<ChatShareOutcome> shareFiles(ChatShareFilesRequest request) async {
    fileRequests.add(request);
    return const ChatShareOutcome.shared();
  }
}

/// 内存写入 fake：记录写入/删除，无真实 IO（fake-async 安全）。
class _InMemoryWriter implements ChatExportTempFileWriter {
  final Map<String, String> files = {};
  final List<String> deletedPaths = [];
  int get writeCalls => files.length + deletedPaths.length;

  @override
  Future<String> write({
    required String fileName,
    required String content,
  }) async {
    files['/tmp/$fileName'] = content;
    return '/tmp/$fileName';
  }

  @override
  Future<void> deleteAll(Iterable<String> paths) async {
    deletedPaths.addAll(paths);
    for (final path in paths) {
      files.remove(path);
    }
  }
}

ChatExportRequest _request() => ChatExportRequest(
  conversationUk3: 'conv-uk3',
  conversationTitle: '张三',
  entries: [
    ChatExportEntry(
      msgType: MessageType.text,
      senderName: '张三',
      createdAt: DateTime(2026, 11, 11, 9, 0, 0),
      status: domain.MessageStatus.sent,
      text: '机密内容',
    ),
  ],
);

Widget _host(void Function(BuildContext ctx) onRun) => MaterialApp(
  home: Builder(
    builder: (ctx) => Scaffold(
      body: ElevatedButton(
        onPressed: () => onRun(ctx),
        child: const Text('run-export'),
      ),
    ),
  ),
);

void main() {
  testWidgets('渲染：标题/正文含「离开加密环境」+ 三个稳定 Key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatExportE2eeConfirmDialog(onConfirm: () {}, onCancel: () {}),
        ),
      ),
    );

    expect(find.byKey(ChatExportDialogKeys.confirm), findsOneWidget);
    expect(find.byKey(ChatExportDialogKeys.ok), findsOneWidget);
    expect(find.byKey(ChatExportDialogKeys.cancel), findsOneWidget);
    expect(find.textContaining('离开加密环境'), findsWidgets);
    expect(find.text('仍要导出'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('showChatExportE2eeConfirmDialog：确认返回 true、取消返回 false', (
    tester,
  ) async {
    late BuildContext captured;
    late Future<bool> confirmed;
    late Future<bool> canceled;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            captured = ctx;
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {},
                child: const Text('anchor'),
              ),
            );
          },
        ),
      ),
    );

    confirmed = showChatExportE2eeConfirmDialog(captured);
    await tester.pump();
    await tester.tap(find.byKey(ChatExportDialogKeys.ok));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);

    canceled = showChatExportE2eeConfirmDialog(captured);
    await tester.pump();
    await tester.tap(find.byKey(ChatExportDialogKeys.cancel));
    await tester.pumpAndSettle();
    expect(await canceled, isFalse);
  });

  testWidgets('E2EE 取消确认 = 零副作用：零写入、gateway 零调用（EXP-02）', (tester) async {
    final gateway = _RecordingGateway();
    final writer = _InMemoryWriter();
    late Future<ChatExportResult> pending;

    await tester.pumpWidget(
      _host((ctx) {
        pending = ChatExportController(
          gateway: gateway,
          tempFileWriter: writer,
          isFlagEnabled: () => true,
          isEncryptedConversation: () async => true,
          confirmLeaveEncryptedEnvironment: () =>
              showChatExportE2eeConfirmDialog(ctx),
          now: () => DateTime(2026, 11, 11, 10, 0, 0),
        ).export(_request());
      }),
    );

    await tester.tap(find.text('run-export'));
    await tester.pump();

    // 弹窗已弹出；点取消。
    expect(find.byKey(ChatExportDialogKeys.confirm), findsOneWidget);
    await tester.tap(find.byKey(ChatExportDialogKeys.cancel));
    await tester.pumpAndSettle();

    final result = await pending;
    expect(result.status, ChatExportStatus.e2eeDeclined);
    expect(gateway.fileRequests, isEmpty, reason: '取消路径 gateway 零调用');
    expect(writer.files, isEmpty, reason: '取消路径不得产生任何临时文件');
    expect(writer.deletedPaths, isEmpty);
  });

  testWidgets('E2EE 确认后完成分享：分享携带 txt+html、完成后清理（EXP-02/03 正向）', (tester) async {
    final gateway = _RecordingGateway();
    final writer = _InMemoryWriter();
    late Future<ChatExportResult> pending;

    await tester.pumpWidget(
      _host((ctx) {
        pending = ChatExportController(
          gateway: gateway,
          tempFileWriter: writer,
          isFlagEnabled: () => true,
          isEncryptedConversation: () async => true,
          confirmLeaveEncryptedEnvironment: () =>
              showChatExportE2eeConfirmDialog(ctx),
          now: () => DateTime(2026, 11, 11, 10, 0, 0),
        ).export(_request());
      }),
    );

    await tester.tap(find.text('run-export'));
    await tester.pump();
    await tester.tap(find.byKey(ChatExportDialogKeys.ok));
    await tester.pumpAndSettle();

    final result = await pending;
    expect(result.status, ChatExportStatus.shared);
    // 分享调用发生在清理前：请求携带 txt+html 两文件。
    expect(gateway.fileRequests.single.filePaths, hasLength(2));
    expect(writer.files, isEmpty, reason: '分享完成后临时文件必须清理');
    expect(writer.deletedPaths, hasLength(2));
  });
}
