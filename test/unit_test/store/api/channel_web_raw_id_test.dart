import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_model.dart';

class _RawChannelAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"id":9007199254740993,"name":"synthetic"}',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  test('raw channel ID retains its exact decimal value', () async {
    final dio = Dio()..httpClientAdapter = _RawChannelAdapter();
    final response = await dio.get<Object>('https://synthetic.invalid/channel');
    final channel = ChannelModel.fromJson(
      Map<String, dynamic>.from(response.data! as Map),
    );
    expect(channel.id.toString(), '9007199254740993');
  });
}
