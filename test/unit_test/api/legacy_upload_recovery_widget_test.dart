import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/legacy_upload_recovery.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';

AttachmentUploadTask task(String error) => AttachmentUploadTask(
  id: 'old-id',
  userId: '101',
  scope: 'private',
  scopeRef: null,
  fileName: 'original.png',
  mime: 'image/png',
  plainSize: 3,
  plainSha256: 'hash',
  objectKey: 'old-key',
  stage: AttachmentUploadStage.putDone,
  cipher: 'AES-256-GCM',
  bindingHash: 'hash',
  keyRef: 'old-id',
  ciphertextSha256: null,
  anchorMsgId: 'anchor',
  lastError: error,
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  test('重新选择的文件必须与旧任务大小和摘要均一致', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final original = task('legacy_reselect');
    final matching = AttachmentUploadTask.fromMap({
      ...original.toMap(),
      'plain_sha256': sha256.convert(bytes).toString(),
    });
    expect(matchesLegacyUpload(matching, bytes), isTrue);
    expect(
      matchesLegacyUpload(matching, Uint8List.fromList([1, 2, 4])),
      isFalse,
    );
    expect(matchesLegacyUpload(matching, Uint8List.fromList([1, 2])), isFalse);
  });

  testWidgets('用户核对后可主动选择文件发送新消息', (tester) async {
    var chosen = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: AppLoading.init(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLegacyUploadRecovery(
              context,
              task('legacy_reselect'),
              outboxMayExist: false,
              selectAndSend: () async {
                chosen = true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('original.png'), findsOneWidget);
    expect(find.textContaining('新消息'), findsWidgets);
    await tester.tap(find.text(t.common.legacyUploadSelectOriginal));
    await tester.pumpAndSettle();
    expect(chosen, isTrue);
  });

  testWidgets('已有 outbox 的记录只提示核对，不提供再次上传', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: AppLoading.init(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLegacyUploadRecovery(
              context,
              task('legacy_outbox_check'),
              outboxMayExist: true,
              selectAndSend: () async {
                retried = true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(t.common.legacyUploadOutboxCheck), findsOneWidget);
    expect(find.text(t.common.legacyUploadSelectOriginal), findsNothing);
    expect(retried, isFalse);
  });
}
