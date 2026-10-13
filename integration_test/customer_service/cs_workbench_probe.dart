import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/domain/cs_conversation_history.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';

import 'cs_integration_runtime.dart';

/// Contract probe only: no assertion here substitutes for Page interaction.
class CsWorkbenchProbe {
  CsWorkbenchProbe(this.runtime);
  final CsIntegrationRuntime runtime;
  CsApi? _api;
  CsSeatEventsStream? _stream;
  final _event = Completer<void>();
  final _seenMessageIds = <String>{};
  String? _sentMessageId;
  final _streamCancellation = CancelToken();

  Future<void> run() async {
    await runtime.login('A');
    final api = _api = runtime.api();
    await _contexts(api);
    final claimed = await _claim(api);
    _listen(api);
    await _waitConnected();
    await _sendAndAttachment(api, claimed.conversationId);
    await _event.future.timeout(const Duration(seconds: 30));
    _stream?.dispose();
    _streamCancellation.cancel();
    expect(_streamCancellation.isCancelled, isTrue);
    expect(_stream!.isConnected, isFalse);
    await _handoff(api);
  }

  Future<void> _contexts(CsApi api) async {
    final f = runtime.fixture;
    final contexts = await api.seatContexts();
    final own = contexts.contexts.where((c) => c.organizationId == f.orgId);
    expect(own.length, 1, reason: 'CS_PROBE_ORGANIZATION_CONTEXT');
    expect(own.single.isEligible, isTrue);
    expect(own.single.workspaces.any((w) => w.id == f.workspaceId), isTrue);
  }

  Future<CsSessionDetail> _claim(CsApi api) async {
    final f = runtime.fixture;
    final queue = await api.queuePage(f.orgId, limit: 50);
    final own = queue.items.where((q) => q.sessionId == f.probeSessionId);
    expect(own.length, 1, reason: 'CS_PROBE_QUEUED_FIXTURE');
    expect(own.single.status, 'queued');
    expect(own.single.version, greaterThan(0));
    await api.claim(
      f.orgId,
      f.probeSessionId,
      expectedVersion: own.single.version,
      workspaceId: f.workspaceId,
    );
    final d = await api.sessionDetail(
      f.orgId,
      f.probeSessionId,
      workspaceId: f.workspaceId,
    );
    expect(d.status, 'active');
    expect(d.conversationId, f.probeConversationId);
    expect(d.assigneeIdentityId, f.seat('A').identity);
    return d;
  }

  void _listen(CsApi api) {
    final f = runtime.fixture;
    _stream = CsSeatEventsStream(
      orgId: f.orgId,
      workspaceId: f.workspaceId,
      opener: (org, ws, {lastEventId = '', afterId = ''}) =>
          api.openSeatEventsStream(
            org,
            ws,
            lastEventId: lastEventId,
            afterId: afterId,
            cancelToken: _streamCancellation,
          ),
    );
    _stream!.start(
      onEvent: (e) {
        if (e.organizationId == f.orgId &&
            e.workspaceId == f.workspaceId &&
            e.type == CsSseEnvelope.typeMessageAppended &&
            e.resourceType == 'message' &&
            !_event.isCompleted) {
          _seenMessageIds.add(e.resourceId);
          _completeEvent();
        }
      },
    );
  }

  void _completeEvent() {
    if (_sentMessageId != null &&
        _seenMessageIds.contains(_sentMessageId) &&
        !_event.isCompleted) {
      _event.complete();
    }
  }

  Future<void> _waitConnected() async {
    for (var i = 0; i < 100; i++) {
      if (_stream!.isConnected) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('CS_PROBE_REAL_SSE_CONNECTION_REQUIRED');
  }

  Future<void> _sendAndAttachment(CsApi api, String conv) async {
    final f = runtime.fixture;
    final bytes = await runtime.ownedFiles.readInput();
    expect(bytes.length, f.assetSize, reason: 'CS_PROBE_FILE_SIZE');
    expect(sha256.convert(bytes).toString(), f.assetSha);
    final asset = await api.uploadEnterpriseAsset(
      f.orgId,
      workspaceId: f.workspaceId,
      conversationId: conv,
      mime: f.assetMime,
      bytes: bytes,
      fileName: f.assetName,
    );
    expect(asset.status, 'active');
    final sent = await api.sendConversationMessage(
      f.orgId,
      conv,
      workspaceId: f.workspaceId,
      identityId: f.seat('A').identity,
      body: '${f.runId}-probe-asset',
      clientMsgId: '${f.runId}-probe-send',
      assetIds: [asset.id],
    );
    expect(sent.message.id, isNotEmpty);
    _sentMessageId = sent.message.id;
    _completeEvent();
    await api.ackDelivery(
      f.orgId,
      conv,
      sent.message.id,
      workspaceId: f.workspaceId,
      deviceId: f.deviceId,
      recipientRef: 'identity:${f.seat('A').identity}',
    );
    await _verifyContent(api, conv, asset.id, sent.message.id, bytes);
  }

  Future<void> _verifyContent(
    CsApi api,
    String conv,
    String assetId,
    String messageId,
    List<int> bytes,
  ) async {
    final f = runtime.fixture;
    final content = await api.fetchAssetContent(
      f.orgId,
      assetId,
      workspaceId: f.workspaceId,
    );
    expect(content.objectHash, f.assetSha);
    expect(
      content.bytes.length == bytes.length &&
          List.generate(
            bytes.length,
            (i) => content.bytes[i] == bytes[i],
          ).every((v) => v),
      isTrue,
      reason: 'CS_PROBE_FULL_CONTENT_BYTES',
    );
    final history = await fetchCsHistoryPage(
      api,
      orgId: f.orgId,
      workspaceId: f.workspaceId,
      conversationId: conv,
      latest: true,
    );
    expect(
      history.messages.any(
        (m) =>
            m.message.id == messageId && m.assets.any((a) => a.id == assetId),
      ),
      isTrue,
    );
  }

  Future<void> _handoff(CsApi api) async {
    final f = runtime.fixture;
    final targets = await api.transferTargets(f.orgId, limit: 50);
    expect(
      targets.items.any(
        (t) => t.identityId == f.seat('B').identity && t.available,
      ),
      isTrue,
    );
    final a = await api.sessionDetail(
      f.orgId,
      f.probeSessionId,
      workspaceId: f.workspaceId,
    );
    await api.transfer(
      f.orgId,
      f.probeSessionId,
      toIdentityId: f.seat('B').identity,
      expectedVersion: a.version,
      workspaceId: f.workspaceId,
    );
    await runtime.login('B');
    await _continueAndClose();
  }

  Future<void> _continueAndClose() async {
    final f = runtime.fixture;
    final bApi = runtime.api();
    try {
      final b = await bApi.sessionDetail(
        f.orgId,
        f.probeSessionId,
        workspaceId: f.workspaceId,
      );
      expect(b.assigneeIdentityId, f.seat('B').identity);
      await bApi.sendConversationMessage(
        f.orgId,
        f.probeConversationId,
        workspaceId: f.workspaceId,
        identityId: f.seat('B').identity,
        body: '${f.runId}-probe-B',
        clientMsgId: '${f.runId}-probe-B-send',
      );
      await bApi.close(
        f.orgId,
        f.probeSessionId,
        workspaceId: f.workspaceId,
        expectedVersion: b.version,
      );
      expect(
        (await bApi.sessionDetail(
          f.orgId,
          f.probeSessionId,
          workspaceId: f.workspaceId,
        )).status,
        'closed',
      );
    } finally {
      bApi.dio.close(force: true);
    }
  }

  void dispose() {
    _stream?.dispose();
    _streamCancellation.cancel();
    _api?.dio.close(force: true);
  }
}
