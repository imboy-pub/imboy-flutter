part of 'talk_record_ai_provider_http.dart';

/// Pinned assembled audio metadata, not arbitrary file/attachment input. The
/// authorizing backend must verify these pins against its source-purpose grant.
class TalkRecordDoubaoSource {
  TalkRecordDoubaoSource({
    required this.sha256Hex,
    required this.byteLength,
    required this.durationMs,
    this.profile = 'aac-adts-16k-mono-64kbps',
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256Hex) ||
        byteLength <= 0 ||
        byteLength >= 512000000 ||
        durationMs <= 0 ||
        durationMs >= 18000000 ||
        profile != 'aac-adts-16k-mono-64kbps') {
      throw _invalid();
    }
  }
  final String sha256Hex;
  final int byteLength;
  final int durationMs;
  final String profile;
  String get mime => 'audio/aac';
  @override
  String toString() => 'TalkRecordDoubaoSource(redacted)';
}

/// Returned provider ID differs from the submit request UUID. Store encrypted
/// immediately. Restored instances must be checked by beforeQuery against the
/// durable task checkpoint; constructing this object does not authorize a query.
class TalkRecordDoubaoTask {
  TalkRecordDoubaoTask({
    required this.taskId,
    required this.submitRequestId,
    required this.source,
  }) {
    if (!_taskId(taskId) || !_uuid(submitRequestId)) throw _invalid();
  }
  final String taskId;
  final String submitRequestId;
  final TalkRecordDoubaoSource source;
  @override
  String toString() => 'TalkRecordDoubaoTask(redacted)';
}

enum TalkRecordDoubaoQueryState { processing, queued, ready }

class TalkRecordDoubaoQueryResult {
  const TalkRecordDoubaoQueryResult(this.state, {this.transcript});
  final TalkRecordDoubaoQueryState state;
  final Map<String, Object?>? transcript;
  @override
  String toString() => 'TalkRecordDoubaoQueryResult(${state.name})';
}

typedef TalkRecordDoubaoAuthorizeSource = Future<Uri> Function(
  TalkRecordDoubaoSource source,
  String persistedSubmitRequestId,
);
typedef TalkRecordDoubaoSaveTask = Future<void> Function(
  TalkRecordDoubaoTask task,
);

extension TalkRecordDoubaoHttp on TalkRecordAiProviderHttp {
  /// Caller persists UUID BEFORE calling. authorizeSource must call the backend
  /// intent/source grant and revalidate pins/policy, not mint a local URL.
  /// No automatic retry, submit replay or fallback to the UUID as a query ID.
  Future<TalkRecordDoubaoTask> submitDoubao({
    required TalkRecordDoubaoSource source,
    required String persistedRequestId,
    required TalkRecordDoubaoAuthorizeSource authorizeSource,
    required TalkRecordDoubaoSaveTask saveTask,
    required CancelToken cancelToken,
  }) async {
    if (!_uuid(persistedRequestId)) throw _invalid();
    Uri url;
    try {
      _guard(cancelToken);
      url = await authorizeSource(source, persistedRequestId);
      _guard(cancelToken);
      _sourceUrl(url, credentials.scope.deploymentOrigin);
    } catch (_) {
      throw _invalid();
    }
    final data = _doubaoBody(url);
    final intent = _doubaoIntent(source, persistedRequestId, 'submit');
    final key = await _prepare(intent, cancelToken);
    final response = await _exchange(
      data,
      TalkRecordAiProvider.doubao,
      TalkRecordAiProvider.doubao.endpoint,
      _doubaoHeaders(key.value, persistedRequestId, submit: true),
      key,
      cancelToken,
    );
    if (_doubaoCode(response.headers) != '20000000') throw _unknown(200);
    final id = response.body['task_id'];
    if (id is! String || !_taskId(id)) throw _unknown(200);
    final task = TalkRecordDoubaoTask(
      taskId: id,
      submitRequestId: persistedRequestId,
      source: source,
    );
    try {
      await saveTask(task);
      _guard(cancelToken);
    } catch (_) {
      throw _unknown(200);
    }
    return task;
  }

  /// Query-only gate MUST verify encrypted saved task ID, source pins, current
  /// permission/consent and lease. It must never register a paid submit intent.
  Future<TalkRecordDoubaoQueryResult> queryDoubao({
    required TalkRecordDoubaoTask persistedTask,
    required TalkRecordAiBeforeDispatch beforeQuery,
    required CancelToken cancelToken,
  }) async {
    final intent = _doubaoIntent(
      persistedTask.source,
      persistedTask.taskId,
      'query',
    );
    final key = await _prepareUsing(intent, cancelToken, beforeQuery);
    final response = await _exchange(
      <String, Object?>{},
      TalkRecordAiProvider.doubao,
      TalkRecordAiProvider.doubao.queryEndpoint!,
      _doubaoHeaders(key.value, persistedTask.taskId),
      key,
      cancelToken,
    );
    final code = _doubaoCode(response.headers);
    if (code == '20000001' || code == '20000002') {
      return TalkRecordDoubaoQueryResult(
        code == '20000001'
            ? TalkRecordDoubaoQueryState.processing
            : TalkRecordDoubaoQueryState.queued,
      );
    }
    if (code != '20000000') throw _unknown(200);
    try {
      final transcript = parseTalkRecordDoubaoResult(
        response.body,
        durationMs: persistedTask.source.durationMs,
        providerStatusCode: code!,
      );
      return TalkRecordDoubaoQueryResult(
        TalkRecordDoubaoQueryState.ready,
        transcript: transcript,
      );
    } catch (_) {
      throw _unknown(200);
    }
  }
}

// One immutable profile feeds both the wire body and durable-intent digest.
const _doubaoAudioProfile = <String, Object?>{
  'format': 'aac',
  'rate': 16000,
  'bits': 16,
  'channel': 1,
};
const _doubaoRequestProfile = <String, Object?>{
  'model_name': 'bigmodel',
  'ssd_version': '300',
  'enable_speaker_info': true,
  'show_utterances': true,
  'enable_itn': true,
  'enable_punc': true,
  'enable_ddc': false,
};
Map<String, Object?> _doubaoBody(Uri url) => {
  'audio': {'url': url.toString(), ..._doubaoAudioProfile},
  'request': _doubaoRequestProfile,
};
TalkRecordAiDispatchIntent _doubaoIntent(
  TalkRecordDoubaoSource source,
  String id,
  String operation,
) => TalkRecordAiDispatchIntent(
  provider: TalkRecordAiProvider.doubao,
  requestHash: _hash(
    jsonEncode([
      operation,
      id,
      source.sha256Hex,
      source.byteLength,
      source.durationMs,
      source.profile,
      'volc.seedasr.auc',
      _doubaoAudioProfile,
      _doubaoRequestProfile,
    ]),
  ),
  inputHash: source.sha256Hex,
  inputBytes: source.byteLength,
);
Map<String, Object?> _doubaoHeaders(
  String key,
  String id, {
  bool submit = false,
}) => {
  'X-Api-Key': key,
  'X-Api-Resource-Id': 'volc.seedasr.auc',
  'X-Api-Request-Id': id,
  if (submit) 'X-Api-Sequence': '-1',
  'Accept': 'application/json',
};
String? _doubaoCode(Map<String, List<String>> headers) {
  final values = headers.entries
      .where((e) => e.key.toLowerCase() == 'x-api-status-code')
      .toList();
  if (values.length != 1 || values.single.value.length != 1) return null;
  final code = values.single.value.single;
  return RegExp(r'^[0-9]{8}$').hasMatch(code) ? code : null;
}

bool _uuid(String value) =>
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
        .hasMatch(value);
bool _taskId(String value) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);
void _sourceUrl(Uri url, String origin) {
  final values = url.queryParametersAll;
  if (url.scheme != 'https' ||
      url.origin != origin ||
      url.userInfo.isNotEmpty ||
      url.hasFragment ||
      url.path != '/api/v1/talk-records/client-audio-source' ||
      values.length != 1 ||
      values['ticket']?.length != 1) {
    throw _invalid();
  }
  final ticket = values['ticket']!.single;
  if (ticket.isEmpty ||
      ticket.length > 4096 ||
      RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(ticket)) {
    throw _invalid();
  }
}
