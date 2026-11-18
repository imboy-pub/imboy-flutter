import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:web/web.dart' as web;

import 'browser_received_attachment.dart' show browserResourceByteBudget;

Future<Uint8List> readBrowserResourceBytes(
  String url, {
  required CancelToken cancelToken,
  required void Function() requireCurrent,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !{'https', 'http'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('Invalid resource URL');
  }
  final options = RequestOptions(path: '/browser-resource', method: 'GET');
  final controller = web.AbortController();
  var finished = false;
  var expired = false;
  void check() {
    requireWebWriter();
    requireCurrent();
    requireWebWriter();
    if (cancelToken.isCancelled) {
      throw cancelToken.cancelError!;
    }
    if (expired) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      );
    }
  }

  final timer = Timer(const Duration(seconds: 30), () {
    expired = true;
    controller.abort();
  });
  final health = webWriterFailures.listen((_) => controller.abort());
  unawaited(
    cancelToken.whenCancel.then((_) {
      if (!finished) controller.abort();
    }),
  );
  late Uint8List bytes;
  try {
    final target = url.toJS;
    final init = web.RequestInit(
      method: 'GET',
      credentials: 'omit',
      redirect: 'error',
      referrerPolicy: 'no-referrer',
      signal: controller.signal,
    );
    check(); // No await separates the owner check from Fetch.
    final response = await web.window.fetch(target, init).toDart;
    check();
    if (response.status != 200) {
      throw DioException.badResponse(
        statusCode: response.status,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: response.status,
        ),
      );
    }
    bytes = await _readBody(response, check);
  } on DioException {
    rethrow;
  } on FormatException {
    rethrow;
  } on Object {
    check();
    throw DioException(
      requestOptions: options,
      message: 'Resource transfer failed',
    );
  } finally {
    finished = true;
    timer.cancel();
    controller.abort();
    await health.cancel();
  }
  check();
  return bytes;
}

Future<Uint8List> _readBody(
  web.Response response,
  void Function() check,
) async {
  final length = int.tryParse(response.headers.get('content-length') ?? '');
  if (length != null && length > browserResourceByteBudget) {
    throw const FormatException('Resource exceeds browser byte budget');
  }
  final reader = response.body?.getReader() as web.ReadableStreamDefaultReader?;
  if (reader == null) {
    return Uint8List(0);
  }
  final bytes = BytesBuilder(copy: false);
  try {
    while (true) {
      final part = await reader.read().toDart;
      check();
      if (part.done) {
        break;
      }
      final chunk = (part.value! as JSUint8Array).toDart;
      if (chunk.length > browserResourceByteBudget - bytes.length) {
        throw const FormatException('Resource exceeds browser byte budget');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  } finally {
    try {
      await reader.cancel().toDart;
    } on Object {
      // Abort may already have failed the reader; keep the original failure.
    }
    reader.releaseLock();
  }
}

void saveBrowserResourceBytes(
  Uint8List bytes,
  String fileName, {
  required void Function() requireCurrent,
}) {
  if (fileName.isEmpty ||
      fileName.contains('\u0000') ||
      bytes.length > browserResourceByteBudget) {
    throw const FormatException('Invalid browser download');
  }
  requireWebWriter();
  requireCurrent();
  requireWebWriter();
  final blob = web.Blob(
    <web.BlobPart>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  var clicked = false;
  try {
    requireWebWriter();
    requireCurrent();
    requireWebWriter();
    anchor.style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    clicked = true;
  } finally {
    anchor.remove();
    // Let the browser consume this download before releasing our own URL.
    if (clicked) {
      Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
    } else {
      web.URL.revokeObjectURL(url);
    }
  }
}
