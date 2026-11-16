import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

Future<int> directWebPut(
  Uri target,
  Uint8List bytes,
  Map<String, String> headers,
  CancelToken? cancel,
  Duration timeout,
  void Function(void Function()) registerAbort,
  void Function(void Function()) unregisterAbort,
) => directWebPutUrl(
  target.toString(),
  bytes,
  headers,
  cancel,
  timeout,
  registerAbort,
  unregisterAbort,
);

/// 原始签名 URL 原样交给 Fetch；不经 Uri 再序列化或改写。
Future<int> directWebPutUrl(
  String target,
  Uint8List bytes,
  Map<String, String> headers,
  CancelToken? cancel,
  Duration timeout,
  void Function(void Function()) registerAbort,
  void Function(void Function()) unregisterAbort, {
  void Function()? beforeDispatch,
}) async {
  if (cancel?.isCancelled == true) throw cancel!.cancelError!;
  final controller = web.AbortController();
  void abort() => controller.abort();
  registerAbort(abort);
  final timer = Timer(timeout, abort);
  var finished = false;
  cancel?.whenCancel.then((_) {
    if (!finished) controller.abort();
  });
  try {
    final requestHeaders = web.Headers();
    headers.forEach((key, value) => requestHeaders.set(key, value));
    final targetJs = target.toJS;
    final init = web.RequestInit(
      method: 'PUT',
      headers: requestHeaders,
      body: bytes.toJS,
      redirect: 'error',
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
      signal: controller.signal,
    );
    // All preparation is complete. No await separates owner/health from fetch.
    beforeDispatch?.call();
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    final response = await web.window.fetch(targetJs, init).toDart;
    return response.status;
  } finally {
    finished = true;
    timer.cancel();
    unregisterAbort(abort);
  }
}
