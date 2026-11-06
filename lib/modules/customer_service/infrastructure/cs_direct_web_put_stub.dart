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
) => throw UnsupportedError('browser transport unavailable');
