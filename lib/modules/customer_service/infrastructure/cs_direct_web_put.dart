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
) async {
  final controller = web.AbortController();
  void abort() => controller.abort();
  registerAbort(abort);
  final timer = Timer(timeout, abort);
  var finished = false;
  cancel?.whenCancel.then((_) {
    if (!finished) controller.abort();
  });
  final requestHeaders = web.Headers();
  headers.forEach((key, value) => requestHeaders.set(key, value));
  try {
    final response = await web.window
        .fetch(
          target.toString().toJS,
          web.RequestInit(
            method: 'PUT',
            headers: requestHeaders,
            body: bytes.toJS,
            redirect: 'error',
            credentials: 'omit',
            referrerPolicy: 'no-referrer',
            signal: controller.signal,
          ),
        )
        .toDart;
    return response.status;
  } finally {
    finished = true;
    timer.cancel();
    unregisterAbort(abort);
  }
}
