// ChannelDiscoverPage Widget 测试
//
// 验证依赖注入重构成果：页面 initState 即调用
// ChannelService.getSubscribedChannels / discoverChannels，重构前为
// ChannelService.to 单例不可注入而被 skip。现通过 channelServiceProvider
// override 注入 mock，使页面渲染可测且无真实网络。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_discover_page_test.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockChannelService extends Mock implements ChannelService {}

class _MockChannelApi extends Mock implements ChannelApi {}

class _LogoutTestPaths extends PathProviderPlatform {
  _LogoutTestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class _UnsubscribeNotifier extends ChannelListNotifier {
  final requests = <String>[];
  final result = Completer<bool>();

  @override
  ChannelListState build() => const ChannelListState();

  @override
  Future<bool> unsubscribeChannel(String channelId) {
    requests.add(channelId);
    return result.future;
  }
}

ChannelModel _makeChannel({required int id, required String name}) {
  return ChannelModel(
    id: id,
    name: name,
    subscriberCount: 10,
    userRole: ChannelUserRole.subscriber,
    isSubscribed: false,
    creatorId: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

Widget _buildTestApp(
  ChannelService service, {
  ChannelApi? api,
  _UnsubscribeNotifier? notifier,
}) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [
        channelServiceProvider.overrideWithValue(service),
        if (api != null) channelApiProvider.overrideWithValue(api),
        if (notifier != null) channelListProvider.overrideWith(() => notifier),
      ],
      child: const MaterialApp(home: ChannelDiscoverPage()),
    ),
  );
}

void main() {
  late _MockChannelService service;
  late _MockChannelApi api;

  setUp(() async {
    final storage = StorageService.to;
    final hadUid = storage.containsKey(Keys.currentUid);
    final oldUid = UserRepoLocal.to.currentUid;
    await storage.setString(Keys.currentUid, 'test-account');
    addTearDown(() async {
      if (hadUid) {
        await storage.setString(Keys.currentUid, oldUid);
      } else {
        await storage.remove(Keys.currentUid);
      }
    });
    service = _MockChannelService();
    api = _MockChannelApi();
    when(() => service.hasPendingSubscription(any())).thenReturn(false);
    when(() => service.channelCategories()).thenAnswer((_) async => []);
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async => []);
  });

  testWidgets('推荐频道为空时渲染空态 / renders empty view for no recommendations', (
    tester,
  ) async {
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => const []);
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    // 注入的 mock 被调用，证明 channelServiceProvider override 生效
    verify(() => service.discoverChannels(size: any(named: 'size'))).called(1);
    expect(find.text(t.channel.noRecommendedChannels), findsOneWidget);
  });

  testWidgets('待核对频道显示刷新订阅状态入口', (tester) async {
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => const []);
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async => [_makeChannel(id: 201, name: '频道')]);
    when(() => service.hasPendingSubscription('201')).thenReturn(true);
    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();
    expect(find.text(t.channel.subscribeRefresh), findsOneWidget);
  });

  testWidgets('有推荐频道时渲染频道名称 / renders recommended channel names', (
    tester,
  ) async {
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => const []);
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async => [_makeChannel(id: 201, name: '推荐频道A')]);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    expect(find.text('推荐频道A'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.textContaining(t.channel.subscribers), findsOneWidget);
  });

  testWidgets('推荐非法 ID 异常显示错误并可重试', (tester) async {
    var calls = 0;
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async {
          if (calls++ == 0) throw const FormatException('invalid channel id');
          return [_makeChannel(id: 201, name: '恢复推荐')];
        });
    await tester.pumpWidget(_buildTestApp(service, api: api));
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.channel.noRecommendedChannels), findsNothing);
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(find.text('恢复推荐'), findsOneWidget);
  });

  testWidgets('搜索非法 ID 异常显示错误，重试保留关键词', (tester) async {
    var calls = 0;
    when(() => api.searchChannels('关键字')).thenAnswer((_) async {
      if (calls++ == 0) throw const FormatException('invalid channel id');
      return [_makeChannel(id: 202, name: '搜索恢复')];
    });
    await tester.pumpWidget(_buildTestApp(service, api: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '关键字');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.channel.noResults), findsNothing);
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(find.text('搜索恢复'), findsOneWidget);
    expect(find.text('关键字'), findsOneWidget);
    verify(() => api.searchChannels('关键字')).called(2);
  });

  testWidgets('合法空搜索显示空态而非错误', (tester) async {
    when(() => api.searchChannels('空')).thenAnswer((_) async => []);
    await tester.pumpWidget(_buildTestApp(service, api: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '空');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text(t.channel.noResults), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
  });

  testWidgets('未登录挂载和交互不启动认证请求', (tester) async {
    await StorageService.to.remove(Keys.currentUid);
    when(() => api.searchChannels(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(_buildTestApp(service, api: api));
    await tester.pump();
    await tester.tap(find.text(t.channel.sortNewest));
    await tester.enterText(find.byType(TextField), '关键词');
    await tester.pump(const Duration(milliseconds: 400));

    verifyNever(
      () => service.getSubscribedChannels(limit: any(named: 'limit')),
    );
    verifyNever(() => service.channelCategories());
    verifyNever(
      () => service.discoverChannels(
        categoryId: any(named: 'categoryId'),
        sort: any(named: 'sort'),
        size: any(named: 'size'),
      ),
    );
    verifyNever(() => api.searchChannels(any()));
  });

  testWidgets('真实登出完成后不再启动认证请求', (tester) async {
    final user = UserRepoLocal.to;
    final oldPaths = PathProviderPlatform.instance;
    final oldSecureStorage = FlutterSecureStoragePlatform.instance;
    final directory = Directory.systemTemp.createTempSync(
      'channel_logout_test_',
    );
    PathProviderPlatform.instance = _LogoutTestPaths(directory.path);
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SqliteService.setDbUnavailableForTest();
    const dbChannel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          dbChannel,
          (call) async =>
              call.method == 'getDatabasesPath' ? directory.path : null,
        );
    addTearDown(() {
      SqliteService.setDbForTest(null);
      PathProviderPlatform.instance = oldPaths;
      FlutterSecureStoragePlatform.instance = oldSecureStorage;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(dbChannel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    when(() => api.searchChannels(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(_buildTestApp(service, api: api));
    await tester.pumpAndSettle();
    verify(() => service.getSubscribedChannels(limit: 200)).called(1);
    verify(() => service.channelCategories()).called(1);
    verify(() => service.discoverChannels(size: 50)).called(1);
    clearInteractions(service);
    clearInteractions(api);

    final loggedOut = await tester.runAsync(
      () => user.quitLogin().timeout(const Duration(seconds: 10)),
    );
    expect(loggedOut, isTrue);
    expect(user.currentUid, isEmpty);
    expect(user.isAuthTransitioning, isFalse);
    await tester.pump();
    await tester.tap(find.text(t.channel.sortNewest));
    await tester.enterText(find.byType(TextField), '登出后关键词');
    await tester.pump(const Duration(milliseconds: 400));

    verifyNever(
      () => service.getSubscribedChannels(limit: any(named: 'limit')),
    );
    verifyNever(() => service.channelCategories());
    verifyNever(
      () => service.discoverChannels(
        categoryId: any(named: 'categoryId'),
        sort: any(named: 'sort'),
        size: any(named: 'size'),
      ),
    );
    verifyNever(() => api.searchChannels(any()));
  });

  testWidgets('退订确认弹窗期间切号，不向新账号发送请求', (tester) async {
    final storage = StorageService.to;
    final hadUid = storage.containsKey(Keys.currentUid);
    final oldUid = UserRepoLocal.to.currentUid;
    await storage.setString(Keys.currentUid, 'account-a');
    addTearDown(() async {
      if (hadUid) {
        await storage.setString(Keys.currentUid, oldUid);
      } else {
        await storage.remove(Keys.currentUid);
      }
    });
    final notifier = _UnsubscribeNotifier();
    final channel = _makeChannel(id: 301, name: '已订阅频道');
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => [channel]);
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async => [channel]);

    await tester.pumpWidget(_buildTestApp(service, notifier: notifier));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.channel.subscribed));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(t.channel.unsubscribeConfirm), findsOneWidget);
    await storage.setString(Keys.currentUid, 'account-b');
    await tester.tap(find.text(t.common.confirm));
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.requests, isEmpty);
    expect(find.text(t.common.tipSuccess), findsNothing);
    expect(find.text(t.common.tipFailed), findsNothing);
  });

  testWidgets('退订请求晚失败不能回滚到新账号', (tester) async {
    final storage = StorageService.to;
    final hadUid = storage.containsKey(Keys.currentUid);
    final oldUid = UserRepoLocal.to.currentUid;
    await storage.setString(Keys.currentUid, 'account-a');
    addTearDown(() async {
      if (hadUid) {
        await storage.setString(Keys.currentUid, oldUid);
      } else {
        await storage.remove(Keys.currentUid);
      }
    });
    final notifier = _UnsubscribeNotifier();
    final channel = _makeChannel(id: 302, name: '待退订频道');
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => [channel]);
    when(() => service.discoverChannels(size: any(named: 'size')))
        .thenAnswer((_) async => [channel]);

    await tester.pumpWidget(_buildTestApp(service, notifier: notifier));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.channel.subscribed));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(t.common.confirm));
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.requests, ['302']);
    await storage.setString(Keys.currentUid, 'account-b');
    notifier.result.complete(false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(t.channel.subscribe), findsOneWidget);
    expect(find.text(t.channel.subscribed), findsNothing);
    expect(find.text(t.common.tipFailed), findsNothing);
    expect(find.text(t.common.tipSuccess), findsNothing);
  });

  testWidgets('旧搜索晚到不能覆盖当前关键词', (tester) async {
    final oldRequest = Completer<List<ChannelModel>>();
    when(() => api.searchChannels('旧')).thenAnswer((_) => oldRequest.future);
    when(() => api.searchChannels('新'))
        .thenAnswer((_) async => [_makeChannel(id: 203, name: '新结果')]);
    await tester.pumpWidget(_buildTestApp(service, api: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旧');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.enterText(find.byType(TextField), '新');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('新结果'), findsOneWidget);
    oldRequest.complete([_makeChannel(id: 204, name: '旧结果')]);
    await tester.pumpAndSettle();
    expect(find.text('新结果'), findsOneWidget);
    expect(find.text('旧结果'), findsNothing);
  });
}
