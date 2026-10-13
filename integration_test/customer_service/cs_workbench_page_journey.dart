import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_conversation_history.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_message_bubble.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_rating_banner.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';

import 'cs_integration_runtime.dart';

/// Real Page, default authentication reader, native picker and native save.
/// External rating/revocation actors must follow the admitted actor protocol.
class CsWorkbenchPageJourney {
  CsWorkbenchPageJourney(this.tester, this.runtime);
  final WidgetTester tester;
  final CsIntegrationRuntime runtime;
  late CsApi api;
  final List<String> phases = [];

  Future<void> run() async {
    await runtime.login('A');
    api = runtime.api();
    try {
      await _historyFixture();
      await _open();
      await _olderPages();
      await _newMessage();
      await _transferCancellation();
      await _cancelPicker();
      await _nativeAttachment();
      await _transferAndContinueB();
      await _closeWithDraft();
      await _ratingAndRevocation();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.dio.close(force: true);
    }
  }

  void _phase(String phase) {
    phases.add(phase);
    // Fixed enum only: no user body, credential, file path or response.
    debugPrint('CS_NATIVE_DEVICE_PHASE:$phase');
  }

  Future<void> _until(
    bool Function() ready,
    String category, {
    int seconds = 30,
  }) async {
    await tester.pump();
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (!ready() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(ready(), isTrue, reason: category);
  }

  Future<void> _historyFixture() async {
    final f = runtime.fixture;
    final ids = <String>[];
    String? before;
    for (var page = 0; page < 4; page++) {
      final data = await fetchCsHistoryPage(
        api,
        orgId: f.orgId,
        workspaceId: f.workspaceId,
        conversationId: f.uiConversationId,
        latest: true,
        beforeId: before,
      );
      expect(data.messages.length, 50, reason: 'CS_UI_FOUR_FULL_HISTORY_PAGES');
      ids.addAll(data.messages.map((m) => m.message.id));
      before = data.messages.last.message.id;
    }
    expect(ids.reversed.toList(), f.historyIds);
    final d = await api.sessionDetail(
      f.orgId,
      f.uiSessionId,
      workspaceId: f.workspaceId,
    );
    expect(d.status, 'active');
    expect(d.assigneeIdentityId, f.seat('A').identity);
  }

  Future<void> _open() async {
    final f = runtime.fixture;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TranslationProvider(child: AppLoading.init()(context, child)),
        home: CsSessionPage(
          orgId: f.orgId,
          sessionId: f.uiSessionId,
          workspaceId: f.workspaceId,
          conversationId: f.uiConversationId,
          identityId: f.seat('A').identity,
          csApi: api,
          attachmentPreparation: runtime.preparation(),
          attachmentSave: runtime.saver(),
        ),
      ),
    );
    await _until(
      () => find.text(f.newestMarker).evaluate().isNotEmpty,
      'CS_UI_LATEST_PAGE',
    );
  }

  Future<void> _olderPages() async {
    final f = runtime.fixture;
    final older = find.byKey(const ValueKey('cs-load-older'));
    for (var page = 0; page < 3; page++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
      await tester.pump();
      await tester.ensureVisible(older);
      final bubbles = tester
          .widgetList<CsMessageBubble>(
            find.byType(CsMessageBubble).hitTestable(),
          )
          .toList();
      expect(bubbles, isNotEmpty, reason: 'CS_UI_REAL_VIEWPORT_ANCHOR');
      final anchor = bubbles.first.message.id;
      final finder = find.byWidgetPredicate(
        (w) => w is CsMessageBubble && w.message.id == anchor,
      );
      final before = tester.getTopLeft(finder).dy;
      await tester.tap(older);
      await _until(
        () => !find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
        'CS_UI_OLDER_COMPLETE',
      );
      expect(tester.getTopLeft(finder).dy, closeTo(before, 2));
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2400));
    await _until(
      () => find.text(f.oldestMarker).evaluate().isNotEmpty,
      'CS_UI_ALL_200_HISTORY',
    );
  }

  Future<void> _newMessage() async {
    final f = runtime.fixture;
    final anchor = find.text(f.oldestMarker);
    final before = tester.getTopLeft(anchor).dy;
    final sent = await api.sendConversationMessage(
      f.orgId,
      f.uiConversationId,
      workspaceId: f.workspaceId,
      identityId: f.seat('A').identity,
      body: '${f.runId}-new-message',
      clientMsgId: '${f.runId}-ui-new',
    );
    final jump = find.byKey(const ValueKey('cs-jump-to-latest'));
    await _until(() => jump.evaluate().isNotEmpty, 'CS_UI_SSE_NEW_ENTRY');
    expect(tester.getTopLeft(anchor).dy, closeTo(before, 2));
    final readBefore = await fetchCsReadState(
      api,
      f.orgId,
      f.workspaceId,
      f.uiSessionId,
    );
    expect(
      BigInt.parse(readBefore.lastReadMessageId),
      lessThan(BigInt.parse(sent.message.id)),
      reason: 'CS_UI_HIDDEN_NEW_NOT_READ',
    );
    await tester.tap(jump);
    await _until(
      () => find
          .text('${f.runId}-new-message')
          .hitTestable()
          .evaluate()
          .isNotEmpty,
      'CS_UI_JUMP_TO_VISIBLE_NEW',
    );
    await _awaitRead(sent.message.id);
  }

  Future<void> _awaitRead(String id) async {
    final f = runtime.fixture;
    for (var i = 0; i < 100; i++) {
      final state = await fetchCsReadState(
        api,
        f.orgId,
        f.workspaceId,
        f.uiSessionId,
      );
      if (BigInt.parse(state.lastReadMessageId) >= BigInt.parse(id)) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('CS_UI_VISIBLE_READ_CONFIRMATION_MISSING');
  }

  Future<void> _transferCancellation() async {
    final f = runtime.fixture;
    final before = await api.sessionDetail(
      f.orgId,
      f.uiSessionId,
      workspaceId: f.workspaceId,
    );
    final targets = await api.transferTargets(f.orgId, limit: 50);
    final b = targets.items.singleWhere(
      (t) => t.identityId == f.seat('B').identity,
    );
    await tester.tap(find.byIcon(CupertinoIcons.arrow_2_squarepath));
    await _until(
      () => find.byType(SimpleDialog).evaluate().isNotEmpty,
      'CS_UI_TRANSFER_TARGETS',
    );
    await tester.tap(
      find.text(b.displayName.isEmpty ? b.identityId : b.displayName),
    );
    await _until(
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
      'CS_UI_TRANSFER_CONFIRMATION',
    );
    await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
    await tester.pumpAndSettle();
    final after = await api.sessionDetail(
      f.orgId,
      f.uiSessionId,
      workspaceId: f.workspaceId,
    );
    expect(after.version, before.version);
    expect(after.assigneeIdentityId, before.assigneeIdentityId);
  }

  Future<void> _transferAndContinueB() async {
    final f = runtime.fixture;
    final targets = await api.transferTargets(f.orgId, limit: 50);
    final b = targets.items.singleWhere(
      (v) => v.identityId == f.seat('B').identity,
    );
    await tester.tap(find.byIcon(CupertinoIcons.arrow_2_squarepath));
    await _until(
      () => find.byType(SimpleDialog).evaluate().isNotEmpty,
      'CS_UI_SECOND_TRANSFER_TARGETS',
    );
    await tester.tap(
      find.text(b.displayName.isEmpty ? b.identityId : b.displayName),
    );
    await _until(
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
      'CS_UI_SECOND_TRANSFER_CONFIRM',
    );
    await tester.tap(find.byType(FilledButton));
    await _until(
      () => find.text(t.customerService.transferredAway).evaluate().isNotEmpty,
      'CS_UI_A_TRANSFERRED_READONLY',
    );
    final detail = await api.sessionDetail(
      f.orgId,
      f.uiSessionId,
      workspaceId: f.workspaceId,
    );
    expect(detail.assigneeIdentityId, f.seat('B').identity);
    await runtime.login('B');
    await _openBPage();
  }

  Future<void> _openBPage() async {
    final f = runtime.fixture;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TranslationProvider(child: AppLoading.init()(context, child)),
        home: CsSessionPage(
          key: const ValueKey('real-seat-B'),
          orgId: f.orgId,
          sessionId: f.uiSessionId,
          workspaceId: f.workspaceId,
          conversationId: f.uiConversationId,
          identityId: f.seat('B').identity,
          csApi: api,
          attachmentPreparation: runtime.preparation(),
          attachmentSave: runtime.saver(),
        ),
      ),
    );
    await _until(
      () =>
          find.byType(TextField).evaluate().isNotEmpty &&
          tester.widget<TextField>(find.byType(TextField).first).enabled ==
              true,
      'CS_UI_B_REAL_READWRITE',
    );
    await _sendBContinuation();
  }

  Future<void> _sendBContinuation() async {
    final f = runtime.fixture;
    final body = '${f.runId}-UI-B-continuation';
    await tester.enterText(find.byType(TextField).first, body);
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
    await _until(
      () => find.text(body).evaluate().isNotEmpty,
      'CS_UI_B_REAL_MESSAGE_RENDERED',
    );
    final history = await fetchCsHistoryPage(
      api,
      orgId: f.orgId,
      workspaceId: f.workspaceId,
      conversationId: f.uiConversationId,
      latest: true,
    );
    expect(
      history.messages.any(
        (m) =>
            m.message.content == body &&
            m.message.senderBusinessIdentityId == f.seat('B').identity,
      ),
      isTrue,
    );
  }

  Future<void> _cancelPicker() async {
    final before = Map<String, int>.from(runtime.requestCounts);
    _phase('NATIVE_PICKER_CANCEL_WITHOUT_SELECTING');
    await tester.tap(find.byIcon(CupertinoIcons.paperclip));
    await _until(
      () => find.text(t.customerService.attachCancelled).evaluate().isNotEmpty,
      'CS_UI_NATIVE_PICKER_CANCEL',
      seconds: 90,
    );
    expect(
      runtime.requestCounts,
      before,
      reason: 'CS_UI_PRE_DISPATCH_CANCEL_ZERO_WRITES',
    );
  }

  Future<void> _nativeAttachment() async {
    final f = runtime.fixture;
    await runtime.ownedFiles.assertOutputAbsent();
    _phase('NATIVE_PICKER_SELECT_RUN_FILE');
    await tester.tap(find.byIcon(CupertinoIcons.paperclip));
    await _until(
      () =>
          find.byKey(const ValueKey('cs-upload-status')).evaluate().isNotEmpty,
      'CS_UI_REAL_UPLOAD_STAGE',
      seconds: 90,
    );
    await _until(
      () => find.text(f.assetName).evaluate().isNotEmpty,
      'CS_UI_REAL_ATTACHMENT_MESSAGE',
      seconds: 90,
    );
    final latest = await fetchCsHistoryPage(
      api,
      orgId: f.orgId,
      workspaceId: f.workspaceId,
      conversationId: f.uiConversationId,
      latest: true,
    );
    final assets = latest.messages
        .expand((m) => m.assets)
        .where((a) => a.fileName == f.assetName)
        .toList();
    expect(assets.length, 1, reason: 'CS_UI_AUTHORIZED_ASSET_HISTORY');
    await _saveVerifiedAsset(assets.single.id);
  }

  Future<void> _saveVerifiedAsset(String assetId) async {
    final f = runtime.fixture;
    final content = await api.fetchAssetContent(
      f.orgId,
      assetId,
      workspaceId: f.workspaceId,
    );
    expect(content.objectHash, f.assetSha);
    expect(content.size, f.assetSize);
    await tester.tap(find.text(f.assetName).first);
    await _until(
      () => find
          .byKey(const ValueKey('cs-save-attachment'))
          .evaluate()
          .isNotEmpty,
      'CS_UI_AUTHORIZED_PREVIEW',
    );
    expect(
      find.text(t.customerService.attachBinaryNoPreview),
      findsOneWidget,
      reason: 'CS_UI_BINARY_BYTES_NOT_RENDERED_AS_UTF8',
    );
    await _cancelSave();
    _phase('NATIVE_SAVE_SELECT_RUN_DESTINATION');
    await tester.tap(find.byKey(const ValueKey('cs-save-attachment')));
    await _until(
      () => find.text(t.customerService.attachSaved).evaluate().isNotEmpty,
      'CS_UI_NATIVE_SAVE_CONFIRMED',
      seconds: 90,
    );
    final saved = await runtime.ownedFiles.readSaved();
    expect(
      saved.length == content.bytes.length &&
          List.generate(
            saved.length,
            (i) => saved[i] == content.bytes[i],
          ).every((v) => v),
      isTrue,
      reason: 'CS_UI_SAVED_EXACT_SERVER_BYTES',
    );
    expect(sha256.convert(saved).toString(), f.assetSha);
    await tester.tap(find.widgetWithText(TextButton, t.common.buttonOk));
    await tester.pumpAndSettle();
  }

  Future<void> _cancelSave() async {
    _phase('NATIVE_SAVE_CANCEL_WITHOUT_WRITING');
    await tester.tap(find.byKey(const ValueKey('cs-save-attachment')));
    await _until(
      () =>
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('cs-save-attachment')),
              )
              .onPressed !=
          null,
      'CS_UI_NATIVE_SAVE_CANCELLED',
      seconds: 90,
    );
    expect(find.text(t.customerService.attachSaved), findsNothing);
    await runtime.ownedFiles.assertOutputAbsent();
  }

  Future<void> _closeWithDraft() async {
    final f = runtime.fixture;
    await tester.enterText(
      find.byType(TextField).first,
      '${f.runId}-unsent-draft',
    );
    final before = await api.sessionDetail(
      f.orgId,
      f.uiSessionId,
      workspaceId: f.workspaceId,
    );
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
    await _until(
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
      'CS_UI_CLOSE_CONFIRMATION',
    );
    expect(find.text(t.customerService.actionDraftWarning), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
    await tester.pumpAndSettle();
    expect(
      (await api.sessionDetail(
        f.orgId,
        f.uiSessionId,
        workspaceId: f.workspaceId,
      )).version,
      before.version,
    );
    await _confirmClose();
  }

  Future<void> _confirmClose() async {
    final f = runtime.fixture;
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
    await _until(
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
      'CS_UI_CLOSE_CONFIRMATION_REOPEN',
    );
    await tester.tap(find.byType(FilledButton));
    await _until(
      () => find.text(t.customerService.closedReadonly).evaluate().isNotEmpty,
      'CS_UI_CLOSED_AUTHORITY',
    );
    expect(
      (await api.sessionDetail(
        f.orgId,
        f.uiSessionId,
        workspaceId: f.workspaceId,
      )).status,
      'closed',
    );
  }

  Future<void> _ratingAndRevocation() async {
    final f = runtime.fixture;
    _phase('EXTERNAL_VISITOR_RATE_CLOSED_SESSION');
    await _until(
      () => find
          .byWidgetPredicate(
            (w) =>
                w is CsSessionRatingBanner &&
                w.detail?.isClosed == true &&
                w.detail?.evaluationState == CsEvaluationState.rated &&
                w.detail?.rating == f.ratingScore &&
                w.detail?.ratingAt != null,
          )
          .evaluate()
          .isNotEmpty,
      'CS_UI_RATING_REFRESH',
      seconds: 90,
    );
    final rated = await api.sessionDetail(
      f.orgId,
      f.uiSessionId,
      workspaceId: f.workspaceId,
    );
    expect(rated.evaluationState, CsEvaluationState.rated);
    expect(rated.rating, f.ratingScore);
    expect(rated.ratingAt, isNotNull);
    expect(find.byType(CsMessageBubble).evaluate(), isNotEmpty);
    _phase('EXTERNAL_REVOKE_SEAT_READ_SCOPE');
    await _until(
      () => find.byType(CsMessageBubble).evaluate().isEmpty,
      'CS_UI_REVOKED_BODY_WITHDRAWN',
      seconds: 90,
    );
    expect(
      find.byType(TextField).evaluate().isEmpty ||
          tester.widget<TextField>(find.byType(TextField).first).enabled ==
              false,
      isTrue,
    );
    expect(
      find.text(t.customerService.ratingScoreLabel(score: f.ratingScore)),
      findsNothing,
      reason: 'CS_UI_REVOKED_RATING_WITHDRAWN',
    );
  }
}
