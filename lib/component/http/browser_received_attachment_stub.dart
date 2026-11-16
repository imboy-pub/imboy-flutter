import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<Uint8List> readBrowserResourceBytes(
  String url, {
  required CancelToken cancelToken,
  required void Function() requireCurrent,
}) => throw UnsupportedError('Browser resource reads require a browser');

void saveBrowserResourceBytes(
  Uint8List bytes,
  String fileName, {
  required void Function() requireCurrent,
}) => throw UnsupportedError('Browser downloads require a browser');
