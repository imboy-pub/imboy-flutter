import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:imboy/service/web_writer_gate.dart';

import 'http_request_policy.dart';

/// Preserve existing adapter/config/test seams; native gets the original Dio.
Dio guardWebWriterDio(Dio dio) {
  if (kIsWeb && dio.httpClientAdapter is! _WriterGuardedAdapter) {
    dio.httpClientAdapter = _WriterGuardedAdapter(dio.httpClientAdapter);
  }
  return dio;
}

class _WriterGuardedAdapter implements HttpClientAdapter {
  _WriterGuardedAdapter(this.inner);
  final HttpClientAdapter inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final stopped = Completer<void>();
    void guard() {
      try {
        requireWebWriter();
        final ownerGuard = options.extra[httpRequestGuard];
        if (ownerGuard != null) (ownerGuard as void Function())();
      } on Object {
        if (!stopped.isCompleted) stopped.complete();
        rethrow;
      }
    }

    guard();
    final pause = webWriterFailures.listen((_) {
      if (!stopped.isCompleted) stopped.complete();
    });
    final cancel = Future.any<void>([?cancelFuture, stopped.future]);
    try {
      // Cancellation aborts pending XHR; this is not an atomic xhr.send hook.
      return inner
          .fetch(
            options,
            requestStream?.map((chunk) {
              guard();
              return chunk;
            }),
            cancel,
          )
          .whenComplete(pause.cancel);
    } on Object {
      unawaited(pause.cancel());
      rethrow;
    }
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
