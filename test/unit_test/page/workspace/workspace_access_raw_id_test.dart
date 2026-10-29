import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RawAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = options.path.endsWith('/messages')
        ? '{"list":[{"id":9007199254740995,"channel_id":9007199254740993,"content":"synthetic"}]}'
        : '{"id":9007199254740993,"scope":"workspace","workspace_id":100,"name":"synthetic"}';
    return ResponseBody.fromString(
      '{"code":0,"msg":"success","payload":$payload}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    HttpClient.adapterForTest = _RawAdapter();
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  test(
    'workspace access accepts an exact channel ID from raw message JSON',
    () async {
      const target = (workspaceId: '100', resource: 'channel:9007199254740993');
      const context = (
        origin: 'https://synthetic.invalid',
        uid: '1',
        session: 1,
        featureScope: 'x',
        featureEpoch: 1,
        featureRevision: 1,
        channelEnabled: true,
      );
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(ChannelApi()),
          workspaceAccessContextReaderProvider.overrideWithValue(() => context),
        ],
      );
      addTearDown(container.dispose);
      final done = Completer<WorkspaceAccessState>();
      final listener = container.listen(workspaceAccessProvider(target), (
        _,
        state,
      ) {
        if (state.phase == WorkspaceAccessPhase.authorized &&
            !done.isCompleted) {
          done.complete(state);
        }
      });
      addTearDown(listener.close);
      container.read(workspaceAccessProvider(target).notifier).resume();
      final state = await done.future.timeout(const Duration(seconds: 8));
      expect(state.channel?.id, '9007199254740993');
      expect(state.canRenderProtectedContent, isTrue);
    },
  );
}
