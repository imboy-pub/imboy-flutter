import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'talk_record_ai_credentials.dart';
import 'talk_record_minimax_result.dart';
import 'talk_record_doubao_result.dart';

part 'talk_record_doubao_http.dart';

enum TalkRecordAiFailureCode {
  inputInvalid,
  credentialsUnavailable,
  contextChanged,
  unauthorized,
  insufficientBalance,
  rateLimited,
  requestRejected,
  providerOutcomeUnknown,
}

enum TalkRecordAiRequestOutcome { notDispatched, rejected, unknown }

/// No provider payload, headers, key, request options or raw exception escapes.
class TalkRecordAiProviderException implements Exception {
  const TalkRecordAiProviderException(
    this.code,
    this.outcome, {
    this.httpStatus,
    this.retryAfterSeconds,
  });
  final TalkRecordAiFailureCode code;
  final TalkRecordAiRequestOutcome outcome;
  final int? httpStatus;
  final int? retryAfterSeconds;
  @override
  String toString() =>
      'TalkRecordAiProviderException(${code.name},status=$httpStatus)';
}

/// Safe semantic request digest; never raw audio, prompt, response or credential.
class TalkRecordAiDispatchIntent {
  const TalkRecordAiDispatchIntent({
    required this.provider,
    required this.requestHash,
    required this.inputHash,
    required this.inputBytes,
  });
  final TalkRecordAiProvider provider;
  final String requestHash;
  final String inputHash;
  final int inputBytes;
  String get model => provider.model;
}

typedef TalkRecordAiBeforeDispatch = Future<void> Function(
  TalkRecordAiDispatchIntent intent,
);

/// The coordinator MUST persist its dispatch intent/checkpoint and validate
/// permission, consent, input pins and live lease in beforeDispatch.
/// verifyCurrent MUST synchronously reject invalidated local context, including
/// auth/credential/policy generation; it is called immediately before fetch.
class TalkRecordAiProviderHttp {
  TalkRecordAiProviderHttp({
    required this.credentials,
    required this.beforeDispatch,
    required this.verifyCurrent,
    this.beforeFetch,
    this.adapterFactory,
  });

  static const maxResponseBytes = 2 * 1024 * 1024;
  static const maxRequestTextBytes = 256 * 1024;
  final TalkRecordAiCredentials credentials;
  final TalkRecordAiBeforeDispatch beforeDispatch;
  final void Function() verifyCurrent;
  final void Function()? beforeFetch;
  final HttpClientAdapter Function()? adapterFactory;

  Future<Map<String, Object?>> transcribe(
    TalkRecordAiAudioChunk chunk, {
    required CancelToken cancelToken,
  }) async {
    final data = FormData.fromMap({
      'model': 'asr-1.0',
      'response_format': 'verbose_json',
      'file': MultipartFile.fromStream(
        chunk.openRead,
        chunk.byteLength,
        filename: 'segment.aac',
        contentType: DioMediaType('audio', 'aac'),
      ),
    });
    final digest = _hash(
      jsonEncode({
        'model': 'asr-1.0',
        'response_format': 'verbose_json',
        'sha256': chunk.sha256Hex,
        'size': chunk.byteLength,
        'duration_ms': chunk.durationMs,
        'chunk_id': chunk.chunkId,
        'offset_ms': chunk.offsetMs,
      }),
    );
    final response = await _request(
      data,
      TalkRecordAiDispatchIntent(
        provider: TalkRecordAiProvider.minimax,
        requestHash: digest,
        inputHash: chunk.sha256Hex,
        inputBytes: chunk.byteLength,
      ),
      cancelToken,
    );
    try {
      return parseTalkRecordMinimaxResult(response, chunk);
    } catch (_) {
      throw _unknown(200);
    }
  }

  /// Returns only message.content's JSON object. A separate schema/reference
  /// validator must approve it before server publication; no model fields guessed.
  Future<Map<String, Object?>> summarize({
    required String systemPrompt,
    required String userText,
    required CancelToken cancelToken,
    int maxTokens = 2048,
  }) async {
    _validatePrompts(systemPrompt, userText, maxTokens);
    final body = _summaryBody(systemPrompt, userText, maxTokens);
    final encoded = jsonEncode(body);
    if (utf8.encode(encoded).length > maxRequestTextBytes) throw _invalid();
    final response = await _request(
      body,
      TalkRecordAiDispatchIntent(
        provider: TalkRecordAiProvider.zhipu,
        requestHash: _hash(encoded),
        inputHash: _hash(userText),
        inputBytes: utf8.encode(userText).length,
      ),
      cancelToken,
    );
    try {
      return _glmContent(response);
    } catch (_) {
      throw _unknown(200);
    }
  }

  void _guard(CancelToken token) {
    if (token.isCancelled ||
        !credentials.scope.matches(credentials.currentScope()) ||
        credentials.currentAuthSessionEpoch() != credentials.authSessionEpoch) {
      throw const TalkRecordAiProviderException(
        TalkRecordAiFailureCode.contextChanged,
        TalkRecordAiRequestOutcome.notDispatched,
      );
    }
    verifyCurrent();
  }

  Future<TalkRecordAiDispatchCredential> _prepare(
    TalkRecordAiDispatchIntent intent,
    CancelToken token,
  ) => _prepareUsing(intent, token, beforeDispatch);

  Future<TalkRecordAiDispatchCredential> _prepareUsing(
    TalkRecordAiDispatchIntent intent,
    CancelToken token,
    TalkRecordAiBeforeDispatch gate,
  ) async {
    try {
      _guard(token);
      await gate(intent);
      final credential = await credentials.acquireForDispatch(intent.provider);
      _guard(token);
      if (credential == null) {
        throw const TalkRecordAiCredentialException('missing_key');
      }
      credential.verifyCurrent();
      return credential;
    } on TalkRecordAiProviderException {
      rethrow;
    } on TalkRecordAiCredentialException {
      throw const TalkRecordAiProviderException(
        TalkRecordAiFailureCode.credentialsUnavailable,
        TalkRecordAiRequestOutcome.notDispatched,
      );
    } catch (_) {
      throw const TalkRecordAiProviderException(
        TalkRecordAiFailureCode.contextChanged,
        TalkRecordAiRequestOutcome.notDispatched,
      );
    }
  }

  Dio _client(void Function() guard) {
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        maxRedirects: 0,
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    dio.httpClientAdapter = _GuardedAdapter(
      adapterFactory?.call() ?? dio.httpClientAdapter,
      guard,
    );
    return dio;
  }

  Future<Map<String, Object?>> _request(
    Object data,
    TalkRecordAiDispatchIntent intent,
    CancelToken token,
  ) async {
    final credential = await _prepare(intent, token);
    final result = await _exchange(
      data,
      intent.provider,
      intent.provider.endpoint,
      {
        'Authorization': 'Bearer ${credential.value}',
        'Accept': 'application/json',
      },
      credential,
      token,
    );
    return result.body;
  }

  Future<({Map<String, Object?> body, Map<String, List<String>> headers})>
  _exchange(
    Object data,
    TalkRecordAiProvider provider,
    String endpoint,
    Map<String, Object?> headers,
    TalkRecordAiDispatchCredential credential,
    CancelToken token,
  ) async {
    var attempted = false;
    Dio? dio;
    try {
      dio = _client(() {
        _guard(token);
        credential.verifyCurrent();
        beforeFetch?.call();
        attempted = true;
      });
      final response = await dio.post<ResponseBody>(
        endpoint,
        data: data,
        cancelToken: token,
        options: Options(headers: headers),
      );
      final body = response.data;
      if (body == null) throw _unknown(response.statusCode);
      final decoded = await _receive(body, credential, provider, token);
      return (body: decoded, headers: body.headers);
    } on TalkRecordAiProviderException catch (error) {
      if (attempted &&
          error.outcome == TalkRecordAiRequestOutcome.notDispatched) {
        throw _unknown(null);
      }
      rethrow;
    } catch (_) {
      if (attempted) throw _unknown(null);
      throw const TalkRecordAiProviderException(
        TalkRecordAiFailureCode.contextChanged,
        TalkRecordAiRequestOutcome.notDispatched,
      );
    } finally {
      dio?.close(force: true);
    }
  }

  Future<Map<String, Object?>> _receive(
    ResponseBody body,
    TalkRecordAiDispatchCredential credential,
    TalkRecordAiProvider provider,
    CancelToken token,
  ) async {
    await _checkStatus(body);
    final bytes = await _readBounded(body.stream, token);
    _guard(token);
    credential.verifyCurrent();
    final freshKey = await credentials.readForDispatch(provider);
    _guard(token);
    credential.verifyCurrent();
    if (freshKey == null || _hash(freshKey) != _hash(credential.value)) {
      throw _unknown(body.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw _unknown(body.statusCode);
    return Map<String, Object?>.from(decoded);
  }

  Future<Uint8List> _readBounded(
    Stream<Uint8List> stream,
    CancelToken token,
  ) async {
    final buffer = BytesBuilder(copy: false);
    // Native Dio's default IO adapter returns HttpClient's decompressed stream.
    // Count actual yielded bytes, never trust compressed Content-Length.
    await for (final bytes in stream.timeout(const Duration(seconds: 120))) {
      _guard(token);
      if (buffer.length + bytes.length > maxResponseBytes) {
        token.cancel('provider_response_limit');
        throw _unknown(200);
      }
      buffer.add(bytes);
    }
    return buffer.takeBytes();
  }
}

class _GuardedAdapter implements HttpClientAdapter {
  _GuardedAdapter(this.delegate, this.guard);
  final HttpClientAdapter delegate;
  final void Function() guard;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    guard();
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

Future<void> _checkStatus(ResponseBody body) async {
  final status = body.statusCode;
  if (status == 200 && !body.isRedirect) return;
  // Cancel the stream without reading or retaining an untrusted error body.
  await body.stream.listen(null).cancel();
  final code = switch (status) {
    401 => TalkRecordAiFailureCode.unauthorized,
    402 => TalkRecordAiFailureCode.insufficientBalance,
    429 => TalkRecordAiFailureCode.rateLimited,
    400 || 404 || 413 || 422 => TalkRecordAiFailureCode.requestRejected,
    _ => TalkRecordAiFailureCode.providerOutcomeUnknown,
  };
  throw TalkRecordAiProviderException(
    code,
    code == TalkRecordAiFailureCode.providerOutcomeUnknown
        ? TalkRecordAiRequestOutcome.unknown
        : TalkRecordAiRequestOutcome.rejected,
    httpStatus: status >= 100 && status <= 599 ? status : null,
    retryAfterSeconds: status == 429 ? _retryAfter(body.headers) : null,
  );
}

int? _retryAfter(Map<String, List<String>> headers) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() != 'retry-after' || entry.value.length != 1) {
      continue;
    }
    final value = entry.value.single;
    if (value.length > 10 || !RegExp(r'^\d+$').hasMatch(value)) return null;
    final seconds = int.tryParse(value);
    return seconds?.clamp(0, 300);
  }
  return null;
}

Map<String, Object?> _glmContent(Map<String, Object?> response) {
  final choices = response['choices'];
  if (response['model'] != 'glm-5.3-flash' ||
      choices is! List ||
      choices.length != 1) {
    throw const FormatException('invalid_provider_response');
  }
  final choice = choices.single;
  if (choice is! Map || choice['finish_reason'] != 'stop') {
    throw const FormatException('invalid_finish');
  }
  final message = choice['message'];
  if (message is! Map ||
      message['role'] != 'assistant' ||
      message['tool_calls'] != null ||
      message['function_call'] != null ||
      message['content'] is! String) {
    throw const FormatException('invalid_message');
  }
  final value = jsonDecode(message['content'] as String);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('invalid_json_object');
  }
  return Map<String, Object?>.unmodifiable(value);
}

void _validatePrompts(String system, String user, int tokens) {
  if (system.isEmpty ||
      system.length > 16384 ||
      user.isEmpty ||
      user.length > TalkRecordAiProviderHttp.maxRequestTextBytes ||
      tokens < 256 ||
      tokens > 8192 ||
      system.trim().isEmpty ||
      user.trim().isEmpty ||
      utf8.encode(system).length > 16384) {
    throw _invalid();
  }
}

Map<String, Object?> _summaryBody(String system, String user, int tokens) => {
  'model': 'glm-5.3-flash',
  'stream': false,
  'messages': [
    {'role': 'system', 'content': system},
    {'role': 'user', 'content': user},
  ],
  'response_format': {'type': 'json_object'},
  'max_tokens': tokens,
  'thinking': {'type': 'enabled'},
  'reasoning_effort': 'low',
};

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
TalkRecordAiProviderException _invalid() => const TalkRecordAiProviderException(
  TalkRecordAiFailureCode.inputInvalid,
  TalkRecordAiRequestOutcome.notDispatched,
);
TalkRecordAiProviderException _unknown(int? status) =>
    TalkRecordAiProviderException(
      TalkRecordAiFailureCode.providerOutcomeUnknown,
      TalkRecordAiRequestOutcome.unknown,
      httpStatus: status != null && status >= 100 && status <= 599
          ? status
          : null,
    );
