part of 'chat_network_service.dart';

// =============================================================================
// 个人云端历史域 API 客户端（MH-01 合同 v1.1 §2/§10.1/§10.2；FL-04 接入层）
//
// - 原生面 /api/v1/personal-history/*；Web N1 面 /api/v1/web/personal-history/*
//   （§10.1 两面同合同；Web 认证链只收 GET/POST，opt-in/key-package 走 POST）。
// - 错误 fail-closed（§2.7）：任何未知 envelope/错误码都抛
//   [PersonalHistoryApiException]，绝不静默吞掉或降级为「无数据」。
// - 传输层可注入（transport），真服务合验在 MH-06；本层只做合同级编解码。
// =============================================================================

/// 个人历史域机器错误码（§2.7 错误总表 + §10.2 补充）。
enum PersonalHistoryErrorCode {
  unauthenticated,
  identityRejected,
  notEnabled,
  notParticipant,
  generationStale,
  purgeInProgress,
  versionConflict,
  generationExpired,
  pageTokenExpired,
  rescanBoundExceeded,
  keyPackageMissing,
  malformedPackage,
  malformedPackageRequest,
  malformedRequest,
  nonceReused,
  transientFailure,

  /// 服务端返回了合同外错误：按不可重试处理并如实上抛（fail-closed）。
  unknown,
}

class PersonalHistoryApiException implements Exception {
  const PersonalHistoryApiException(this.code, this.httpStatus);

  final PersonalHistoryErrorCode code;
  final int httpStatus;

  /// §2.3/§2.7：仅 transient_failure 可安全重试。
  bool get retryable => code == PersonalHistoryErrorCode.transientFailure;

  @override
  String toString() =>
      'PersonalHistoryApiException: ${code.name} (http $httpStatus)';
}

/// 一次传输调用的原始结果（transport 注入面）。
class PersonalHistoryTransportResult {
  const PersonalHistoryTransportResult({
    required this.httpStatus,
    this.body,
    this.headers = const {},
  });

  final int httpStatus;
  final Map<String, dynamic>? body;
  final Map<String, String> headers;
}

/// 传输抽象：真服务（Dio）/ 合同 fixture（chrome 测试）共用同一编解码。
typedef PersonalHistoryTransport =
    Future<PersonalHistoryTransportResult> Function(
      String method,
      String path, {
      Map<String, dynamic>? queryParameters,
      Object? data,
    });

PersonalHistoryErrorCode _errorCodeFromName(String? name) {
  return switch (name) {
    'unauthenticated' => PersonalHistoryErrorCode.unauthenticated,
    'identity_rejected' => PersonalHistoryErrorCode.identityRejected,
    'not_enabled' => PersonalHistoryErrorCode.notEnabled,
    'not_participant' => PersonalHistoryErrorCode.notParticipant,
    'generation_stale' => PersonalHistoryErrorCode.generationStale,
    'purge_in_progress' => PersonalHistoryErrorCode.purgeInProgress,
    'version_conflict' => PersonalHistoryErrorCode.versionConflict,
    'generation_expired' => PersonalHistoryErrorCode.generationExpired,
    'page_token_expired' => PersonalHistoryErrorCode.pageTokenExpired,
    'rescan_bound_exceeded' => PersonalHistoryErrorCode.rescanBoundExceeded,
    'key_package_missing' => PersonalHistoryErrorCode.keyPackageMissing,
    'malformed_package' => PersonalHistoryErrorCode.malformedPackage,
    'malformed_package_request' =>
      PersonalHistoryErrorCode.malformedPackageRequest,
    'malformed_request' => PersonalHistoryErrorCode.malformedRequest,
    'nonce_reused' => PersonalHistoryErrorCode.nonceReused,
    'transient_failure' => PersonalHistoryErrorCode.transientFailure,
    _ => PersonalHistoryErrorCode.unknown,
  };
}

/// `/personal-history/status` 投影（§2.1）。
class PersonalHistoryStatus {
  const PersonalHistoryStatus({
    required this.state,
    required this.generation,
    this.domain,
    this.uploadCursor,
  });

  final String state; // OFF | ON | OFF_PURGE_PENDING | OFF_PURGED
  final int generation;
  final String? domain;
  final int? uploadCursor;

  bool get enabled => state == 'ON';

  bool authorizesSameScope(PersonalHistoryStatus expected) =>
      enabled &&
      expected.enabled &&
      domain != null &&
      domain == expected.domain &&
      generation == expected.generation;
}

/// Backend-confirmed C2C identity and ordering facts. Content still needs
/// account-local decryption before it can be displayed.
typedef PersonalHistoryAcceptedMessage = ({
  String fromId,
  String toId,
  int sequence,
  int actionVersion,
});

PersonalHistoryAcceptedMessage? parsePersonalHistoryAcceptedMessage(
  Object? value,
) {
  if (value is! Map) return null;
  final fromId = value['from_id'];
  final toId = value['to_id'];
  final sequence = value['conv_seq'];
  final version = value['action_version'];
  if (fromId is! String ||
      toId is! String ||
      sequence is! int ||
      sequence <= 0 ||
      version is! int ||
      version < 0) {
    return null;
  }
  return (
    fromId: fromId,
    toId: toId,
    sequence: sequence,
    actionVersion: version,
  );
}

/// `/personal-history/changes` 单事件（§2.4：稳定合并版本 + tombstone）。
class PersonalHistoryEvent {
  const PersonalHistoryEvent({
    required this.seq,
    required this.conversationId,
    required this.msgId,
    required this.actionVersion,
    required this.convSeq,
    required this.keyVersion,
    required this.ciphertext,
    required this.envelopeMeta,
    required this.deleted,
    required this.createdAt,
    this.acceptedMessage,
    this.suppressed = false,
  });

  final int seq;
  final String conversationId;
  final String msgId;
  final int actionVersion;
  final int convSeq;
  final int keyVersion;
  final String ciphertext; // b64
  final Map<String, dynamic> envelopeMeta; // {alg, key_version, nonce, aad}
  final bool deleted; // tombstone（MSG-H15）
  final int createdAt;
  final PersonalHistoryAcceptedMessage? acceptedMessage;
  final bool suppressed;
}

class PersonalHistoryChangesPage {
  const PersonalHistoryChangesPage({
    required this.generation,
    required this.events,
    this.nextCursor,
    this.resetHint = false,
  });

  final int generation;
  final List<PersonalHistoryEvent> events;
  final int? nextCursor;
  final bool resetHint;
}

typedef PersonalHistoryAccountPage = ({
  int generation,
  List<PersonalHistoryEvent> events,
  String? pageToken,
  int? recoveryCursor,
  String? completionToken,
});

/// key-package 读取响应（mh04 addendum：当前 generation 同域数字校验）。
class PersonalHistoryKeyPackageRead {
  const PersonalHistoryKeyPackageRead({
    required this.generation,
    required this.keyVersion,
    required this.wrappedKey,
    required this.kdfMeta,
    required this.integrityHash,
  });

  final int generation;
  final int keyVersion;
  final String wrappedKey; // b64 原样
  final Map<String, dynamic> kdfMeta;
  final String integrityHash;
}

/// 合同级 /personal-history/* 客户端。
class PersonalHistoryApiClient {
  PersonalHistoryApiClient({
    required this.transport,
    this.webFace = false,
    this.clientInstance,
  });

  final PersonalHistoryTransport transport;
  final bool webFace;
  final String? clientInstance;

  static const String _nativeBase = '/api/v1/personal-history';
  static const String _webBase = '/api/v1/web/personal-history';

  /// JS 安全整数上界（与 276-279 DDL / mh04 addendum 同域）。
  static const int maxSafeInteger = 9007199254740991;

  String get _base => webFace ? _webBase : _nativeBase;

  /// §10.1：Web 认证链只收 GET/POST；原生面 opt-in/key-package 为 PUT。
  String get _optInMethod => webFace ? 'POST' : 'PUT';
  String get _keyPackagePutMethod => webFace ? 'POST' : 'PUT';

  Map<String, dynamic> _successBody(PersonalHistoryTransportResult result) {
    final body = result.body;
    if (result.httpStatus < 200 ||
        result.httpStatus >= 300 ||
        body == null ||
        body['code'] != 0) {
      throw _toException(result);
    }
    final payload = body['payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload == null) return const {};
    throw const PersonalHistoryApiException(
      PersonalHistoryErrorCode.unknown,
      0,
    );
  }

  PersonalHistoryApiException _toException(
    PersonalHistoryTransportResult result,
  ) {
    final body = result.body;
    final Map<Object?, Object?>? envelope = body is Map
        ? body as Map<Object?, Object?>
        : null;
    final payload = envelope?['payload'];
    final errorName = payload is Map
        ? payload['error']?.toString()
        : envelope?['error']?.toString();
    return PersonalHistoryApiException(
      _errorCodeFromName(errorName),
      result.httpStatus,
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) async {
    PersonalHistoryTransportResult result;
    try {
      result = await transport(
        method,
        path,
        queryParameters: queryParameters,
        data: data,
      );
    } on PersonalHistoryApiException {
      rethrow;
    } on Object {
      // 网络层异常：合同未定义具体码，按不可归类 fail-closed 上抛。
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.unknown,
        0,
      );
    }
    return _successBody(result);
  }

  /// §2.1 GET /status。
  Future<PersonalHistoryStatus> status() async {
    final payload = await _send('GET', '$_base/status');
    final state = payload['state']?.toString() ?? '';
    final generation = payload['generation'];
    if (state.isEmpty ||
        generation is! int ||
        generation < 0 ||
        generation > maxSafeInteger) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedRequest,
        0,
      );
    }
    return PersonalHistoryStatus(
      state: state,
      generation: generation,
      domain: payload['domain'] is String ? payload['domain'] as String : null,
      uploadCursor: payload['upload_cursor'] is int
          ? payload['upload_cursor'] as int
          : null,
    );
  }

  /// §2.2 PUT /opt-in（幂等：同 generation 重复返回同状态）。
  Future<PersonalHistoryStatus> optIn(String clientInstanceId) async {
    final payload = await _send(
      _optInMethod,
      '$_base/opt-in',
      data: {'client_instance_id': clientInstanceId},
    );
    final generation = payload['generation'];
    if (payload['state'] != 'ON' ||
        generation is! int ||
        generation <= 0 ||
        generation > maxSafeInteger) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedRequest,
        0,
      );
    }
    return PersonalHistoryStatus(state: 'ON', generation: generation);
  }

  /// §2.3 POST /upload（幂等键 = account+domain+conversation+msg_id，由服务端裁决）。
  Future<Map<String, dynamic>> upload(Map<String, dynamic> item) =>
      _send('POST', '$_base/upload', data: item);

  /// §2.4 GET /changes。
  Future<PersonalHistoryChangesPage> changes({
    required int cursor,
    int limit = 50,
    bool accountRecovery = false,
  }) async {
    if (accountRecovery && clientInstance?.isNotEmpty != true) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.identityRejected,
        0,
      );
    }
    final payload = await _send(
      'GET',
      '$_base/changes',
      queryParameters: {
        'cursor': cursor,
        'limit': limit,
        if (accountRecovery) 'snapshot': 'account',
        if (clientInstance != null) 'client_instance': clientInstance,
      },
    );
    const malformed = PersonalHistoryApiException(
      PersonalHistoryErrorCode.malformedRequest,
      0,
    );
    final generation = payload['generation'];
    final rawEvents = payload['events'];
    final nextCursor = payload['next_cursor'];
    final resetHint = payload['reset_hint'];
    if (generation is! int ||
        generation < 0 ||
        generation > maxSafeInteger ||
        rawEvents is! List ||
        (nextCursor != null &&
            (nextCursor is! int ||
                nextCursor < 0 ||
                nextCursor > maxSafeInteger)) ||
        resetHint is! bool) {
      throw malformed;
    }
    final events = _readHistoryEvents(
      rawEvents,
      accountRecovery: accountRecovery,
    );
    if (accountRecovery) {
      var last = cursor;
      for (final event in events) {
        if (event.seq <= last) throw malformed;
        last = event.seq;
      }
      if ((resetHint && events.isNotEmpty) ||
          nextCursor != (events.isEmpty ? null : last)) {
        throw malformed;
      }
    }
    return PersonalHistoryChangesPage(
      generation: generation,
      events: events,
      nextCursor: nextCursor as int?,
      resetHint: resetHint,
    );
  }

  List<PersonalHistoryEvent> _readHistoryEvents(
    List<dynamic> rawEvents, {
    bool accountRecovery = false,
  }) {
    const malformed = PersonalHistoryApiException(
      PersonalHistoryErrorCode.malformedRequest,
      0,
    );
    final events = <PersonalHistoryEvent>[];
    for (final raw in rawEvents) {
      if (raw is! Map) throw malformed;
      final eventSeq = raw['event_seq'];
      final conversationId = raw['conversation_id'];
      final msgId = raw['msg_id'];
      if (eventSeq is! int ||
          eventSeq <= 0 ||
          eventSeq > maxSafeInteger ||
          conversationId is! String ||
          conversationId.isEmpty ||
          msgId is! String ||
          msgId.isEmpty) {
        throw malformed;
      }
      final suppressed = accountRecovery && raw['suppressed'] == true;
      if (raw.containsKey('suppressed') && !suppressed) throw malformed;
      final envelopeMeta = raw['envelope_meta'];
      final source = parsePersonalHistoryAcceptedMessage(
        raw['accepted_message'],
      );
      if (accountRecovery) {
        final version = raw['action_version'];
        final sequence = raw['conv_seq'];
        final keyVersion = raw['key_version'];
        final ciphertext = raw['ciphertext'];
        final deleted = raw['deleted'];
        if (version is! int ||
            version < 0 ||
            version > maxSafeInteger ||
            sequence is! int ||
            sequence <= 0 ||
            sequence > maxSafeInteger ||
            deleted is! bool) {
          throw malformed;
        }
        if (suppressed) {
          const identityFields = {
            'event_seq',
            'conversation_id',
            'msg_id',
            'conv_seq',
            'action_version',
            'created_at',
            'deleted',
            'suppressed',
          };
          if (deleted || raw.keys.any((key) => !identityFields.contains(key))) {
            throw malformed;
          }
        } else if (keyVersion is! int ||
            keyVersion <= 0 ||
            keyVersion > maxSafeInteger ||
            (!deleted &&
                (source == null ||
                    source.sequence != sequence ||
                    source.actionVersion != version ||
                    envelopeMeta is! Map<String, dynamic> ||
                    ciphertext is! String ||
                    ciphertext.isEmpty))) {
          throw malformed;
        }
      }
      events.add(
        PersonalHistoryEvent(
          seq: eventSeq,
          conversationId: conversationId,
          msgId: msgId,
          actionVersion: raw['action_version'] as int? ?? 0,
          convSeq: raw['conv_seq'] as int? ?? 0,
          keyVersion: raw['key_version'] as int? ?? 0,
          ciphertext: raw['ciphertext']?.toString() ?? '',
          envelopeMeta: envelopeMeta is Map<String, dynamic>
              ? envelopeMeta
              : const {},
          deleted: raw['deleted'] == true,
          createdAt: raw['created_at'] as int? ?? 0,
          acceptedMessage: source,
          suppressed: suppressed,
        ),
      );
    }
    return events;
  }

  /// Account-scoped projection recovery, independent of conversation paging.
  Future<PersonalHistoryAccountPage> accountSnapshot({
    String? pageToken,
  }) async {
    final instance = clientInstance;
    if (instance == null || instance.isEmpty) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.identityRejected,
        0,
      );
    }
    final payload = await _send(
      'GET',
      '$_base/page',
      queryParameters: {
        'snapshot': 'account',
        'client_instance': instance,
        'page_token': ?pageToken,
      },
    );
    final generation = payload['generation'];
    final rows = payload['events'];
    final hasMore = payload['has_more'];
    final nextToken = payload['page_token'];
    final recoveryCursor = payload['recovery_cursor'];
    final completionToken = payload['completion_token'];
    if (generation is! int ||
        generation <= 0 ||
        generation > maxSafeInteger ||
        rows is! List ||
        rows.length > 50 ||
        hasMore is! bool ||
        (hasMore
            ? rows.isEmpty ||
                  nextToken is! String ||
                  nextToken.isEmpty ||
                  nextToken == pageToken ||
                  recoveryCursor != null ||
                  completionToken != null
            : nextToken != null ||
                  recoveryCursor is! int ||
                  recoveryCursor < 0 ||
                  recoveryCursor > maxSafeInteger ||
                  completionToken is! String ||
                  completionToken.isEmpty)) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedRequest,
        0,
      );
    }
    return (
      generation: generation,
      events: _readHistoryEvents(rows, accountRecovery: true),
      pageToken: nextToken as String?,
      recoveryCursor: recoveryCursor as int?,
      completionToken: completionToken as String?,
    );
  }

  /// §2.4 GET /page（分页快照；空页≠归档齐全）。
  Future<Map<String, dynamic>> page({
    required String conversationId,
    int before = 0,
    String? pageToken,
  }) => _send(
    'GET',
    '$_base/page',
    queryParameters: {
      'conversation_id': conversationId,
      if (before > 0) 'before': before,
      if (pageToken != null && pageToken.isNotEmpty) 'page_token': pageToken,
    },
  );

  /// §10.2 POST /ack-cursor（幂等；仅推进 ≤ 服务端已发放最大值）。
  Future<void> ackCursor(
    int cursor, {
    required int generation,
    String? completionToken,
  }) async {
    if (completionToken != null &&
        (completionToken.isEmpty || clientInstance?.isNotEmpty != true)) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedRequest,
        0,
      );
    }
    final payload = await _send(
      'POST',
      '$_base/ack-cursor',
      data: {
        'cursor': cursor,
        'generation': generation,
        'client_instance': ?clientInstance,
        'completion_token': ?completionToken,
      },
    );
    final acknowledgedGeneration = payload['generation'];
    if (acknowledgedGeneration is int && acknowledgedGeneration != generation) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.generationExpired,
        0,
      );
    }
    final advancedTo = payload['advanced_to'];
    if (acknowledgedGeneration is! int ||
        payload['accepted'] != true ||
        (completionToken != null &&
            (advancedTo is! int ||
                advancedTo < cursor ||
                advancedTo > maxSafeInteger))) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedRequest,
        0,
      );
    }
  }

  /// §2.5 PUT /key-package。显式带代次，避免跨关闭/重开后写入旧包。
  Future<void> putKeyPackage(
    Map<String, dynamic> package, {
    required int generation,
  }) async {
    if (generation <= 0 || generation > maxSafeInteger) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedPackageRequest,
        422,
      );
    }
    final payload = await _send(
      _keyPackagePutMethod,
      '$_base/key-package',
      data: {...package, 'generation': generation},
    );
    if (payload['generation'] != generation) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.generationExpired,
        0,
      );
    }
    if (payload['key_version'] != package['key_version']) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedPackage,
        0,
      );
    }
  }

  /// mh04 addendum GET /key-package：查询参数恰好一份 key_version 与一份
  /// generation，十进制 ASCII 数字（无符号/前导零/指数/浮点），同域校验。
  Future<PersonalHistoryKeyPackageRead> getKeyPackage({
    required int keyVersion,
    required int generation,
  }) async {
    if (keyVersion < 1 ||
        keyVersion > maxSafeInteger ||
        generation < 0 ||
        generation > maxSafeInteger) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedPackageRequest,
        422,
      );
    }
    final payload = await _send(
      'GET',
      '$_base/key-package',
      queryParameters: {'key_version': keyVersion, 'generation': generation},
    );
    final respGeneration = payload['generation'];
    final respVersion = payload['key_version'];
    final wrapped = payload['wrapped_key']?.toString();
    if (respGeneration is! int ||
        respVersion is! int ||
        respGeneration > maxSafeInteger ||
        respVersion > maxSafeInteger ||
        wrapped == null ||
        wrapped.isEmpty) {
      throw const PersonalHistoryApiException(
        PersonalHistoryErrorCode.malformedPackage,
        0,
      );
    }
    final kdfMeta = payload['kdf_meta'];
    return PersonalHistoryKeyPackageRead(
      generation: respGeneration,
      keyVersion: respVersion,
      wrappedKey: wrapped,
      kdfMeta: kdfMeta is Map<String, dynamic> ? kdfMeta : const {},
      integrityHash: payload['integrity_hash']?.toString() ?? '',
    );
  }

  /// §2.6 POST /disable（202 受理）。
  Future<Map<String, dynamic>> disable() =>
      _send('POST', '$_base/disable', data: const {});

  /// §2.6 GET /delete-status。
  Future<Map<String, dynamic>> deleteStatus() =>
      _send('GET', '$_base/delete-status');
}
