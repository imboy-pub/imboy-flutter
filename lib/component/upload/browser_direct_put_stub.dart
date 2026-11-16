import 'dart:typed_data';

import 'package:dio/dio.dart';

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
}) => throw UnsupportedError('browser transport unavailable');
