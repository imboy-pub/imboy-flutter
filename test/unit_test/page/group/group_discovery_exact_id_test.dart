import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/group/group_discovery/group_discovery_page.dart';
import 'package:imboy/page/group/group_discovery/group_discovery_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/group_discovery_api.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final payload = options.path.endsWith('/categories')
        ? '{"list":[{"id":9007199254740995,"name":"类别"}]}'
        : '{"list":[{"id":9007199254740993,"title":"精确群","member_count":12}]}';
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
  final adapter = _Adapter();
  setUp(() async {
    adapter.requests.clear();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    HttpClient.adapterForTest = adapter;
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  testWidgets('raw IDs remain exact through discovery, filter and tap', (
    tester,
  ) async {
    final container = ProviderContainer();
    ThemeManager.instance.setProviderContainer(container);
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(groupDiscoveryProvider.notifier).initData(),
    );
    final router = GoRouter(
      initialLocation: '/discover',
      routes: [
        GoRoute(
          path: '/discover',
          builder: (_, _) => const GroupDiscoveryPage(),
        ),
        GoRoute(
          path: '/group/detail/:id',
          builder: (_, state) => Text('群详情 ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('精确群'), findsOneWidget);
    await tester.tap(find.text('类别'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final request = adapter.requests.lastWhere(
      (r) => r.path.endsWith('/discover'),
    );
    expect(
      request.queryParameters['category_id'].toString(),
      '9007199254740995',
    );
    await tester.tap(find.text('精确群'));
    await tester.pumpAndSettle();
    expect(find.text('群详情 9007199254740993'), findsOneWidget);
  });

  test('search response preserves ID and non-ID count', () async {
    final payload = await GroupDiscoveryApi.to.search('群');
    final row = (payload!['list'] as List).single as Map;
    expect(row['id'], '9007199254740993');
    expect(row['member_count'], 12);
  });
}
