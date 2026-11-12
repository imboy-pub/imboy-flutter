/// W3-J ChatExportController 验收测试：fake gateway 注入全流程
/// （落盘内容/分享参数/清理删除）、flag 关闭入口拒绝、E2EE 取消零副作用、
/// 落盘失败与网关异常路径的清理（EXP-02/EXP-03、FLAG-01）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_controller.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_temp_file_writer.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart' as domain;
import 'package:imboy/modules/messaging/infrastructure/export/chat_export_temp_file_io.dart';
import 'package:imboy/service/message_type_constants.dart';

ChatExportEntry _text(
  String sender,
  DateTime at,
  String body, {
  domain.MessageStatus status = domain.MessageStatus.sent,
  String type = MessageType.text,
}) {
  return ChatExportEntry(
    msgType: type,
    senderName: sender,
    createdAt: at,
    status: status,
    text: body,
  );
}

/// 记录型 fake 网关：可配置结果或抛异常。
class _RecordingGateway implements ChatShareGateway {
  _RecordingGateway({this.outcome, this.throwOnShare});

  final ChatShareOutcome? outcome;
  final Object? throwOnShare;

  final List<ChatShareFilesRequest> fileRequests = [];
  final List<String> textCalls = [];

  /// 分享时刻的文件内容快照（清理发生在 share 返回后，事后读盘必空）。
  final List<String> sharedFileContents = [];

  int get calls => fileRequests.length + textCalls.length;

  @override
  Future<ChatShareOutcome> shareText(String text, {String? subject}) async {
    textCalls.add(text);
    if (throwOnShare != null) throw throwOnShare!;
    return outcome ?? const ChatShareOutcome.shared();
  }

  @override
  Future<ChatShareOutcome> shareFiles(ChatShareFilesRequest request) async {
    fileRequests.add(request);
    for (final path in request.filePaths) {
      sharedFileContents.add(File(path).readAsStringSync());
    }
    if (throwOnShare != null) throw throwOnShare!;
    return outcome ?? const ChatShareOutcome.shared();
  }
}

/// 记录型 fake 写入器：真实写到注入目录（验证落盘内容 + 删除）。
class _RealDirWriter implements ChatExportTempFileWriter {
  _RealDirWriter(this.dir, {this.throwOnFileNameContains});

  final Directory dir;
  final String? throwOnFileNameContains;
  final List<String> writtenFileNames = [];
  final List<String> deletedPaths = [];
  int get writeCalls => writtenFileNames.length;

  @override
  Future<String> write({
    required String fileName,
    required String content,
  }) async {
    final failPattern = throwOnFileNameContains;
    if (failPattern != null && fileName.contains(failPattern)) {
      throw FileSystemException('injected write failure');
    }
    writtenFileNames.add(fileName);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  @override
  Future<void> deleteAll(Iterable<String> paths) async {
    deletedPaths.addAll(paths);
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}

Iterable<File> _exportFilesIn(Directory dir) =>
    dir.listSync().whereType<File>();

void main() {
  final t1 = DateTime(2026, 11, 11, 9, 0, 0);
  final t2 = DateTime(2026, 11, 11, 9, 30, 0);

  late Directory dir;
  late _RealDirWriter writer;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('imboy-w3j-controller');
    writer = _RealDirWriter(dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  ChatExportController controller(
    _RecordingGateway gateway, {
    bool Function()? isFlagEnabled,
    Future<bool> Function()? isEncrypted,
    Future<bool> Function()? confirm,
    Map<String, String> Function()? translations,
  }) {
    return ChatExportController(
      gateway: gateway,
      tempFileWriter: writer,
      isFlagEnabled: isFlagEnabled ?? () => true,
      isEncryptedConversation: isEncrypted,
      confirmLeaveEncryptedEnvironment: confirm,
      translations: translations,
      now: () => DateTime(2026, 11, 11, 10, 0, 0),
    );
  }

  ChatExportRequest request(List<ChatExportEntry> entries) => ChatExportRequest(
    conversationUk3: 'conv-uk3-abc',
    conversationTitle: '张三',
    entries: entries,
  );

  test('flag 关闭：入口直接拒绝，零写入零分享（FLAG-01）', () async {
    final gateway = _RecordingGateway();
    final result = await controller(
      gateway,
      isFlagEnabled: () => false,
    ).export(request([_text('张三', t1, '你好')]));

    expect(result.status, ChatExportStatus.flagDisabled);
    expect(gateway.calls, 0);
    expect(writer.writeCalls, 0);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('flag 判定缺省 = fail-closed（默认拒绝）', () async {
    final gateway = _RecordingGateway();
    final result = await ChatExportController(
      gateway: gateway,
      tempFileWriter: writer,
      now: () => DateTime(2026, 11, 11, 10, 0, 0),
    ).export(request([_text('张三', t1, '你好')]));

    expect(result.status, ChatExportStatus.flagDisabled);
    expect(gateway.calls, 0);
  });

  test('明文全流程：txt+html 落盘内容正确、分享参数正确、完成后清理（EXP-03）', () async {
    final gateway = _RecordingGateway();
    final result = await controller(gateway)
        .export(request([_text('张三', t1, '你好'), _text('李四', t2, '在吗\n第二行')]));

    expect(result.status, ChatExportStatus.shared);
    expect(result.exportedCount, 2);
    expect(result.rejectionCounts, isEmpty);

    // 分享调用参数：一 txt 一 html，文件名/ MIME 契约。
    expect(gateway.fileRequests, hasLength(1));
    final share = gateway.fileRequests.single;
    expect(share.filePaths, hasLength(2));
    expect(share.artifacts, hasLength(2));
    final names = share.artifacts.map((a) => a.fileName).toList();
    expect(
      names.first,
      matches(r'^imboy-chat-export-20261111-[0-9a-f]{6}\.txt$'),
    );
    expect(
      names.last,
      matches(r'^imboy-chat-export-20261111-[0-9a-f]{6}\.html$'),
    );
    expect(share.artifacts.first.mimeType, 'text/plain; charset=utf-8');
    expect(share.artifacts.last.mimeType, 'text/html; charset=utf-8');
    // 会话 uk3 只进产物元数据（清理圈定），不进正文/文件名。
    expect(
      share.artifacts.every((a) => a.conversationUk3 == 'conv-uk3-abc'),
      isTrue,
    );

    // 落盘内容（gateway 在分享时刻快照）：txt 行格式 + 换行保留。
    final txt = gateway.sharedFileContents.first;
    expect(txt, contains('会话: 张三'));
    expect(txt, contains('导出时间: 2026-11-11 10:00:00'));
    expect(txt, contains('条数: 2'));
    expect(txt, contains('[2026-11-11 09:00:00] 张三: 你好'));
    expect(txt, contains('[2026-11-11 09:30:00] 李四: 在吗\n第二行'));
    final html = gateway.sharedFileContents.last;
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<html lang="zh-CN">'));
    expect(html, contains('在吗<br>第二行'));

    // 完成后清理：目录清空 + 删除路径与写入路径一致。
    await Future<void>.delayed(Duration.zero);
    expect(_exportFilesIn(dir), isEmpty);
    expect(writer.deletedPaths.toSet(), share.filePaths.toSet());
  });

  test('类型准入：sending/红包被拒，拒绝计数进结果；拒绝项不落盘', () async {
    final gateway = _RecordingGateway();
    final result = await controller(gateway).export(
      request([
        _text('张三', t1, '你好'),
        _text('张三', t2, '发送中', status: domain.MessageStatus.sending),
        _text('李四', t2, '红包', type: MessageType.redPacket),
      ]),
    );

    expect(result.status, ChatExportStatus.shared);
    expect(result.exportedCount, 1);
    expect(result.rejectionCounts, {
      ChatExportAdmission.rejectedStatusSending.reasonCode: 1,
      ChatExportAdmission.rejectedPayment.reasonCode: 1,
    });
    final txt = gateway.sharedFileContents.first;
    expect(txt, contains('条数: 1'));
    expect(txt, contains('你好'));
    expect(txt, isNot(contains('发送中')));
    expect(txt, isNot(contains('红包')));
  });

  test('全部被拒：nothingToExport，不落盘不分享', () async {
    final gateway = _RecordingGateway();
    final result = await controller(gateway).export(
      request([_text('张三', t1, '发送中', status: domain.MessageStatus.sending)]),
    );

    expect(result.status, ChatExportStatus.nothingToExport);
    expect(gateway.calls, 0);
    expect(writer.writeCalls, 0);
  });

  test('E2EE 会话 + 用户取消确认：零副作用（不落盘、gateway 零调用）EXP-02', () async {
    final gateway = _RecordingGateway();
    final result = await controller(
      gateway,
      isEncrypted: () async => true,
      confirm: () async => false,
    ).export(request([_text('张三', t1, '机密')]));

    expect(result.status, ChatExportStatus.e2eeDeclined);
    expect(gateway.calls, 0);
    expect(writer.writeCalls, 0);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('E2EE 会话 + 确认回调缺失：fail-closed 拒绝（等同取消）', () async {
    final gateway = _RecordingGateway();
    final result = await controller(
      gateway,
      isEncrypted: () async => true,
      confirm: null,
    ).export(request([_text('张三', t1, '机密')]));

    expect(result.status, ChatExportStatus.e2eeDeclined);
    expect(gateway.calls, 0);
  });

  test('E2EE 确认回调抛异常：防御捕获映射 e2eeDeclined，异常不穿透（W5-G3-1）', () async {
    // UI 闭包跨 await（逐条 DB 映射 + 加密判定）后 context 可能已卸载，
    // 弹窗调用抛异常——controller 必须兜住并按用户拒绝处理，而不是让
    // 异常穿透 unawaited 的导出调用链。
    final gateway = _RecordingGateway();
    final result = await controller(
      gateway,
      isEncrypted: () async => true,
      confirm: () async => throw StateError('dialog context unmounted'),
    ).export(request([_text('张三', t1, '机密')]));

    expect(result.status, ChatExportStatus.e2eeDeclined);
    expect(gateway.calls, 0);
    expect(writer.writeCalls, 0);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('E2EE 会话 + 用户确认：继续导出，分享后仍清理', () async {
    final gateway = _RecordingGateway();
    final result = await controller(
      gateway,
      isEncrypted: () async => true,
      confirm: () async => true,
    ).export(request([_text('张三', t1, '机密')]));

    expect(result.status, ChatExportStatus.shared);
    expect(gateway.calls, 1);
    await Future<void>.delayed(Duration.zero);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('网关返回 canceled：映射 canceled 且清理', () async {
    final gateway = _RecordingGateway(
      outcome: const ChatShareOutcome.canceled(),
    );
    final result = await controller(gateway)
        .export(request([_text('张三', t1, '你好')]));

    expect(result.status, ChatExportStatus.canceled);
    await Future<void>.delayed(Duration.zero);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('网关返回 error：错误码透传且清理', () async {
    final gateway = _RecordingGateway(
      outcome: const ChatShareOutcome.error('share_failed'),
    );
    final result = await controller(gateway)
        .export(request([_text('张三', t1, '你好')]));

    expect(result.status, ChatExportStatus.error);
    expect(result.errorCode, 'share_failed');
    await Future<void>.delayed(Duration.zero);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('网关抛异常：error/share_failed 且 finally 清理（异常清理路径）', () async {
    final gateway = _RecordingGateway(throwOnShare: StateError('boom'));
    final result = await controller(gateway)
        .export(request([_text('张三', t1, '你好')]));

    expect(result.status, ChatExportStatus.error);
    expect(result.errorCode, 'share_failed');
    expect(gateway.calls, 1);
    await Future<void>.delayed(Duration.zero);
    expect(_exportFilesIn(dir), isEmpty);
  });

  test('落盘失败（第二个文件）：清理半成品、gateway 零调用、error 码稳定', () async {
    final gateway = _RecordingGateway();
    final failingWriter = _RealDirWriter(dir, throwOnFileNameContains: '.html');
    final ctrl = ChatExportController(
      gateway: gateway,
      tempFileWriter: failingWriter,
      isFlagEnabled: () => true,
      now: () => DateTime(2026, 11, 11, 10, 0, 0),
    );
    final result = await ctrl.export(request([_text('张三', t1, '你好')]));

    expect(result.status, ChatExportStatus.error);
    expect(result.errorCode, 'temp_file_write_failed');
    expect(gateway.calls, 0);
    // txt 半成品已被清理。
    await Future<void>.delayed(Duration.zero);
    expect(_exportFilesIn(dir), isEmpty);
    expect(failingWriter.deletedPaths, hasLength(1));
  });

  test('翻译缝：注入映射后 txt/html 用当前 locale 标签（zh-CN 常量为兜底）', () async {
    final gateway = _RecordingGateway();
    final result =
        await controller(
          gateway,
          translations: () => const {
            'conversation_label': 'Conversation',
            'exported_at_label': 'Exported at',
            'count_label': 'Messages',
            'html_title': 'IMBoy Chat History',
            'html_lang': 'en-US',
            'message_fallback': '[Message]',
          },
        ).export(
          request([
            ChatExportEntry(
              msgType: MessageType.text,
              senderName: 'Alice',
              createdAt: t1,
              status: domain.MessageStatus.sent,
            ),
          ]),
        );

    expect(result.status, ChatExportStatus.shared);
    final txt = gateway.sharedFileContents.first;
    expect(txt, contains('Conversation: 张三'));
    expect(txt, contains('Exported at: 2026-11-11 10:00:00'));
    expect(txt, contains('Messages: 1'));
    expect(txt, contains('Alice: [Message]'));
    final html = gateway.sharedFileContents.last;
    expect(html, contains('<html lang="en-US">'));
  });

  test('翻译缝无 provider：回落 zh-CN 兜底且不残留上次 locale（W1-C 契约）', () async {
    // 先跑一次 en 映射导出，再跑一次无 provider 导出：
    // 第二次必须回落 zh-CN（controller 显式重置，无跨导出串状态）。
    final gatewayEn = _RecordingGateway();
    await controller(
      gatewayEn,
      translations: () => const {'conversation_label': 'Conversation'},
    ).export(request([_text('张三', t1, '你好')]));

    final gatewayZh = _RecordingGateway();
    await controller(
      gatewayZh,
      translations: null,
    ).export(request([_text('张三', t1, '你好')]));
    final txt = gatewayZh.sharedFileContents.first;
    expect(txt, contains('会话: 张三'));
    expect(txt, isNot(contains('Conversation:')));
  });

  test('IoChatExportTempFileWriter：真实端口落盘与 best-effort 删除', () async {
    final ioWriter = IoChatExportTempFileWriter(
      directoryResolver: () async => dir,
    );
    final path = await ioWriter.write(
      fileName: 'imboy-chat-export-unit.txt',
      content: 'hello',
    );
    expect(await File(path).readAsString(), 'hello');
    // 删除不存在的路径不抛。
    await ioWriter.deleteAll([path, '${dir.path}/not-exist.txt']);
    expect(await File(path).exists(), isFalse);
  });
}
