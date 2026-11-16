import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:web/web.dart' as web;

import 'http_request_policy.dart';
import 'web_control_fetch_types.dart';

const _jsonLimit = 1024 * 1024;
const _methods = {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'};
const _memberLimit = 25 * 1024 * 1024;

// A new Web overall contract, not three observable XHR phase timers.
Duration? _budget(RequestOptions o) {
  final values = [
    o.connectTimeout,
    o.sendTimeout,
    o.receiveTimeout,
  ].whereType<Duration>().where((v) => v > Duration.zero).toList()..sort();
  return values.isEmpty ? null : values.first;
}

// Keep the original request object only for Dio diagnostics/retry policy. No
// mutable RequestOptions field is consulted for dispatch after this capture.
class _DispatchIntent {
  _DispatchIntent(RequestOptions o)
    : uri = o.uri,
      method = o.method,
      media = (o.contentType ?? '').split(';').first.toLowerCase(),
      hasData = o.data != null,
      responseType = o.responseType,
      ownerGuard = o.extra[httpRequestGuard],
      withCredentials = o.extra['withCredentials'] == true,
      hasUploadProgress = o.onSendProgress != null,
      followRedirects = o.followRedirects,
      maxRedirects = o.maxRedirects,
      budget = _budget(o),
      cancelToken = o.cancelToken,
      headers = Map.unmodifiable(
        o.headers.map(
          (name, value) =>
              MapEntry(name, value is Iterable ? value.join(', ') : '$value'),
        ),
      );

  final Uri uri;
  final String method;
  final String media;
  final bool hasData;
  final ResponseType responseType;
  final Object? ownerGuard;
  final bool withCredentials;
  final bool hasUploadProgress;
  final bool followRedirects;
  final int maxRedirects;
  final Duration? budget;
  final CancelToken? cancelToken;
  final Map<String, String> headers;
}

void _preventRetry(RequestOptions options) {
  options.extra = {...options.extra, httpNoAutoRetry: true};
}

DioException _reject(RequestOptions options, String message) {
  _preventRetry(options);
  return DioException(
    requestOptions: options,
    message: message,
    error: const WebControlBeforeDispatch(),
  );
}

Dio guardWebControlDio(Dio dio, {required Uri apiOrigin}) {
  if (dio.httpClientAdapter is! _ControlRouter) {
    dio.httpClientAdapter = _ControlRouter(dio.httpClientAdapter, apiOrigin);
  }
  return dio;
}

Dio guardWebMemberDio(Dio dio, {required Uri apiOrigin}) {
  dio.httpClientAdapter = _ControlFetch(apiOrigin, member: true);
  return dio;
}

/// Explicit read-only binary/SSE branch is not claimed atomic by this patch.
/// A rejected control configuration never falls back to the old XHR adapter.
class _ControlRouter implements HttpClientAdapter {
  _ControlRouter(this.other, Uri origin) : control = _ControlFetch(origin);
  final HttpClientAdapter other;
  final _ControlFetch control;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) {
    final read = options.method == 'GET' || options.method == 'HEAD';
    final existingRead =
        options.responseType == ResponseType.stream ||
        options.responseType == ResponseType.bytes;
    if (read && existingRead && body == null) {
      return other.fetch(options, body, cancel);
    }
    return control.fetch(options, body, cancel);
  }

  @override
  void close({bool force = false}) {
    control.close(force: force);
    other.close(force: force);
  }
}

class _ControlFetch implements HttpClientAdapter {
  _ControlFetch(Uri origin, {this.member = false}) : origin = origin.origin;
  final String origin;
  final bool member;
  final _active = <_Request>{};
  bool _closed = false;

  void _validate(RequestOptions o, _DispatchIntent intent) {
    final uri = intent.uri;
    final media = intent.media;
    final jsonBody = media == 'application/json' || media.endsWith('+json');
    final path = member
        ? RegExp(
            r'^/api/v1/enterprise/organizations/[1-9][0-9]*/assets/presign$',
          ).hasMatch(uri.path)
        : uri.path.startsWith('/api/v1/');
    if (_closed ||
        uri.origin != origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.normalizePath().path != uri.path ||
        !path ||
        intent.responseType != ResponseType.json ||
        intent.ownerGuard is! void Function() ||
        intent.withCredentials ||
        (member ? intent.method != 'PUT' : !_methods.contains(intent.method)) ||
        (intent.hasData &&
            (member ? media != 'application/octet-stream' : !jsonBody))) {
      throw _reject(o, 'Unsupported control request');
    }
    _validateConfiguration(o, intent);
  }

  void _validateConfiguration(RequestOptions o, _DispatchIntent intent) {
    if (intent.budget == null || intent.hasUploadProgress) {
      throw _reject(
        o,
        'Positive Web deadline required; upload progress unsupported',
      );
    }
    if (member && (intent.followRedirects || intent.maxRedirects != 0)) {
      throw _reject(o, 'Member control requires redirects disabled');
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    late final _DispatchIntent intent;
    try {
      intent = _DispatchIntent(o);
      _validate(o, intent);
    } on DioException {
      _preventRetry(o);
      rethrow;
    } catch (_) {
      throw _reject(o, 'Control intent capture failed');
    }
    final request = _Request(o, intent, () => _closed);
    _active.add(request);
    var handedOff = false;
    try {
      request.start(cancel);
      final bytes = await request.collect(
        stream,
        member ? _memberLimit : _jsonLimit,
      );
      request.check();
      if ((intent.method == 'GET' || intent.method == 'HEAD') &&
          bytes.isNotEmpty) {
        throw _reject(o, 'Read body is unsupported');
      }
      request.phase = 'request-init';
      final prepared = _prepare(intent, bytes, request);
      // The owned sink: every byte/await/JS preparation is before this check.
      // No await, interceptor, callback preparation or inner adapter follows it.
      request.check();
      request.dispatched = true;
      final pending = web.window.fetch(prepared.$1, prepared.$2).toDart;
      request.phase = 'response-headers';
      final response = await request.wait(pending);
      request.check();
      final body = request.responseStream(response, () => _finish(request));
      final result = _response(response, body, () {
        request.stop(
          DioException.requestCancelled(
            requestOptions: o,
            reason: request.cancellationReason('Control response closed'),
          ),
        );
        unawaited(_finish(request));
      });
      handedOff = true;
      return result;
    } on DioException {
      if (!request.dispatched) _preventRetry(o);
      rethrow;
    } catch (_) {
      throw _failure(o, request);
    } finally {
      if (!handedOff) await _finish(request);
    }
  }

  Future<void> _finish(_Request request) async {
    try {
      await request.dispose();
    } finally {
      if (!request.dispatched || request.failure != null) {
        _preventRetry(request.options);
      }
      _active.remove(request);
    }
  }

  DioException _failure(RequestOptions options, _Request request) {
    if (request.failure != null) return request.failure!;
    if (!request.dispatched) {
      return _reject(options, 'Control preparation failed');
    }
    return DioException.connectionError(
      requestOptions: options,
      reason: 'Browser control Fetch failed',
    );
  }

  (JSString, web.RequestInit) _prepare(
    _DispatchIntent intent,
    Uint8List bytes,
    _Request request,
  ) {
    final headers = web.Headers();
    intent.headers.forEach((name, value) {
      if (name.toLowerCase() != Headers.contentLengthHeader) {
        headers.set(name, value);
      }
    });
    final url = intent.uri.toString().toJS;
    final init = web.RequestInit(
      method: intent.method,
      headers: headers,
      body: bytes.isEmpty ? null : bytes.toJS,
      credentials: member ? 'omit' : 'same-origin',
      redirect: member || !intent.followRedirects ? 'error' : 'follow',
      signal: request.controller.signal,
    );
    return (url, init);
  }

  ResponseBody _response(
    web.Response response,
    Stream<Uint8List> body,
    void Function() onClose,
  ) {
    final responseHeaders = <String, List<String>>{};
    _Headers(response.headers).forEach(
      ((String value, String name, [JSAny? _]) {
        responseHeaders[name.toLowerCase()] = [value];
      }).toJS,
    );
    // Preserve raw UTF-8/large ID tokens and the existing Dio response decoder.
    return ResponseBody(
      body,
      response.status,
      onClose: onClose,
      statusMessage: response.statusText,
      headers: responseHeaders,
      isRedirect: response.redirected,
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final request in _active.toList()) {
      request.stop(
        DioException.requestCancelled(
          requestOptions: request.options,
          reason: request.cancellationReason('Control adapter closed'),
        ),
      );
    }
  }
}

class _Request {
  _Request(this.options, this.intent, this.closed) : budget = intent.budget!;
  final RequestOptions options;
  final _DispatchIntent intent;
  final bool Function() closed;
  final Duration budget;
  final _clock = Stopwatch();
  Timer? _deadline;
  String phase = 'body-preparation';
  final controller = web.AbortController();
  final _stopped = Completer<void>();
  StreamSubscription<void>? _health;
  StreamSubscription<Uint8List>? _body;
  web.ReadableStreamDefaultReader? _reader;
  bool _responseDone = false;
  Future<void>? _disposing;
  DioException? failure;
  bool dispatched = false;

  Object cancellationReason(String reason) =>
      dispatched ? reason : const WebControlBeforeDispatch();

  void check() {
    if (failure != null) throw failure!;
    if (_clock.isRunning && _clock.elapsed >= budget) {
      _expire();
      throw failure!;
    }
    try {
      requireWebWriter();
      (intent.ownerGuard as void Function())();
      // A caller guard is synchronous but may itself cancel or close.
      requireWebWriter();
      if (closed() || intent.cancelToken?.isCancelled == true) {
        throw StateError('Control stopped');
      }
    } catch (_) {
      final error = DioException.requestCancelled(
        requestOptions: options,
        reason: cancellationReason('Control owner/storage no longer admitted'),
      );
      stop(error);
      throw error;
    }
    if (_clock.isRunning && _clock.elapsed >= budget) {
      _expire();
      throw failure!;
    }
  }

  void start(Future<void>? cancel) {
    check();
    _clock.start();
    _deadline = Timer(budget, _expire);
    _health = webWriterFailures.listen(
      (_) => stop(
        DioException.requestCancelled(
          requestOptions: options,
          reason: cancellationReason('Control storage stopped'),
        ),
      ),
    );
    unawaited(
      cancel?.then(
        (_) => stop(
          DioException.requestCancelled(
            requestOptions: options,
            reason: cancellationReason('Control cancelled'),
          ),
        ),
      ),
    );
  }

  void stop(DioException error) {
    failure ??= error;
    _preventRetry(options);
    if (!_stopped.isCompleted) _stopped.complete();
    controller.abort();
  }

  void _expire() {
    stop(
      DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: WebControlDeadlineExceeded(
          budget: budget,
          phase: phase,
          dispatched: dispatched,
        ),
        message: 'Web control overall deadline exceeded',
      ),
    );
  }

  Future<T> wait<T>(Future<T> operation) => Future.any<T>([
    operation,
    _stopped.future.then<T>((_) => throw failure!),
  ]);

  Future<Uint8List> collect(Stream<Uint8List>? stream, int limit) async {
    check();
    if (stream == null) return Uint8List(0);
    final result = Completer<Uint8List>();
    final bytes = BytesBuilder();
    _body = stream.listen(
      (chunk) {
        try {
          check();
          if (bytes.length + chunk.length > limit) {
            throw DioException(
              requestOptions: options,
              message: 'Control body limit exceeded',
              error: const WebControlBeforeDispatch(),
            );
          }
          bytes.add(chunk);
        } on DioException catch (error, stack) {
          stop(error);
          if (!result.isCompleted) result.completeError(error, stack);
        }
      },
      onError: (Object error, StackTrace stack) {
        final failure = DioException(
          requestOptions: options,
          message: 'Control body stream failed',
          error: const WebControlBeforeDispatch(),
        );
        stop(failure);
        if (!result.isCompleted) result.completeError(failure, stack);
      },
      onDone: () {
        if (!result.isCompleted) result.complete(bytes.takeBytes());
      },
    );
    return wait(result.future);
  }

  Stream<Uint8List> responseStream(
    web.Response response,
    Future<void> Function() finish,
  ) async* {
    phase = 'response-body';
    _reader = response.body?.getReader() as web.ReadableStreamDefaultReader?;
    try {
      check();
      if (_reader == null) {
        _responseDone = true;
        return;
      }
      while (true) {
        final chunk = await wait(_reader!.read().toDart);
        check();
        if (chunk.done) {
          _responseDone = true;
          return;
        }
        final value = (chunk.value! as JSUint8Array).toDart;
        yield value;
      }
    } finally {
      await finish();
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _deadline?.cancel();
    _clock.stop();
    try {
      await Future.wait<void>([
        if (_health != null) _health!.cancel(),
        if (_body != null) _body!.cancel(),
      ]);
    } finally {
      try {
        if (_reader != null && !_responseDone) {
          try {
            await _reader!.cancel().toDart;
          } catch (_) {
            // Abort can already have errored the reader; preserve the surfaced
            // owner/cancel/deadline error, but never hide an independent failure.
            if (failure == null) rethrow;
          }
        }
      } finally {
        _reader?.releaseLock();
      }
    }
  }
}

@JS()
extension type _Headers(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}
