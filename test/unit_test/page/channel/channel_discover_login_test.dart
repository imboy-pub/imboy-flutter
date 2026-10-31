import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/runtime_feature_recovery.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _MockChannelService extends Mock implements ChannelService {}

class _MockChannelApi extends Mock implements ChannelApi {}

class _ControlledSecureStorage extends TestFlutterSecureStoragePlatform {
  _ControlledSecureStorage() : super({});

  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (key == 'secure_token') {
      if (!writeStarted.isCompleted) writeStarted.complete();
      await releaseWrite.future;
    }
    await super.write(key: key, value: value, options: options);
  }
}

class _SessionDatabase extends Fake implements Database {
  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

void main() {
  testWidgets('切换账号清除关键词和分类，不向新账号重放', (tester) async {
    // flutter_test_config.dart 已将 SharedPreferences 和网络限制在测试环境。
    final user = UserRepoLocal.to;
    final service = _MockChannelService();
    final api = _MockChannelApi();
    final secureStorage = _ControlledSecureStorage();
    FlutterSecureStoragePlatform.instance = secureStorage;
    await StorageService.to.setString(Keys.currentUid, 'account-a');
    SqliteService.setDbForTest(_SessionDatabase());
    void bindNewDatabase() {
      if (user.currentUid == 'account-b') {
        SqliteService.setDbForTest(_SessionDatabase());
      }
    }

    user.addListener(bindNewDatabase);
    final recommendations = <(String, int?)>[];
    final searches = <(String, String)>[];
    final categories = <String>[];
    when(() => service.hasPendingSubscription(any())).thenReturn(false);
    when(() => service.getSubscribedChannels(limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => service.channelCategories()).thenAnswer((_) async {
      categories.add(user.currentUid);
      if (user.currentUid == 'account-b') {
        throw const FormatException('categories');
      }
      return [
        {'id': 7, 'name': '账号A分类'},
      ];
    });
    when(
      () => service.discoverChannels(
        categoryId: any(named: 'categoryId'),
        sort: any(named: 'sort'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((invocation) async {
      recommendations.add((
        user.currentUid,
        invocation.namedArguments[#categoryId] as int?,
      ));
      return [];
    });
    when(() => api.searchChannels(any())).thenAnswer((invocation) async {
      searches.add((
        user.currentUid,
        invocation.positionalArguments.single as String,
      ));
      return [
        ChannelModel(
          id: 205,
          name: '账号A结果',
          subscriberCount: 10,
          userRole: ChannelUserRole.subscriber,
          isSubscribed: false,
          creatorId: 1,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
    });

    Future<bool>? login;
    var loginFinished = false;
    try {
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              channelServiceProvider.overrideWithValue(service),
              channelApiProvider.overrideWithValue(api),
            ],
            child: const MaterialApp(home: ChannelDiscoverPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('账号A分类'));
      await tester.pumpAndSettle();
      expect(recommendations, contains(('account-a', 7)));
      verify(
        () =>
            service.discoverChannels(categoryId: 7, sort: 'popular', size: 50),
      ).called(1);
      await tester.enterText(find.byType(TextField), '私密关键词');
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(find.text('账号A结果'), findsOneWidget);
      expect(searches, [('account-a', '私密关键词')]);

      // 再输入一个尚未触发防抖的关键词，确保切换时取消旧账号的定时器。
      await tester.enterText(find.byType(TextField), '待发送关键词');
      await tester.pump(const Duration(milliseconds: 100));
      expect(searches, [('account-a', '私密关键词')]);
      expect(user.currentUid, 'account-a');

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      login = user.loginAfter('synthetic', {
        'uid': 'account-b',
        'token': 'synthetic-token',
        'refreshtoken': 'synthetic-refresh',
      });
      login.then<void>(
        (_) => loginFinished = true,
        onError: (Object _, StackTrace _) {
          loginFinished = true;
        },
      );
      expect(controller.text, isEmpty);
      await _pumpUntil(tester, () => secureStorage.writeStarted.isCompleted);
      expect(secureStorage.writeStarted.isCompleted, isTrue);
      secureStorage.releaseWrite.complete();
      await _pumpUntil(tester, () => loginFinished);
      expect(loginFinished, isTrue, reason: '登录未在限定时间内结束');
      expect(await login, isTrue);
      expect(user.currentUid, 'account-b');
      // 在新会话推进超过完整防抖窗口，检验旧定时器不会重发。
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(find.text('账号A结果'), findsNothing);
      expect(find.text('私密关键词'), findsNothing);
      expect(find.text('待发送关键词'), findsNothing);
      expect(
        searches.where((request) => request == ('account-b', '待发送关键词')),
        isEmpty,
      );
      expect(find.text('账号A分类'), findsNothing);
      expect(searches, [('account-a', '私密关键词')]);
      expect(categories.where((uid) => uid == 'account-a'), hasLength(1));
      expect(categories.where((uid) => uid == 'account-b'), hasLength(1));
      expect(
        recommendations.where((call) => call == ('account-a', null)),
        hasLength(1),
      );
      expect(
        recommendations.where((call) => call == ('account-b', null)),
        hasLength(1),
      );
      expect(
        recommendations.where((call) => call == ('account-b', 7)),
        isEmpty,
      );
      verify(
        () => service.discoverChannels(
          categoryId: null,
          sort: 'popular',
          size: 50,
        ),
      ).called(2);
    } finally {
      if (!secureStorage.releaseWrite.isCompleted) {
        secureStorage.releaseWrite.complete();
      }
      if (login != null && !loginFinished) {
        await _pumpUntil(tester, () => loginFinished);
      }
      // 不恢复真实 secure platform / DB：登录启动的 unawaited 任务可能仍在运行。
      user.removeListener(bindNewDatabase);
      await tester.pumpWidget(const SizedBox.shrink());
      if (login == null || loginFinished) {
        RuntimeFeatureRecovery.dispose();
        WebSocketService.to.dispose();
        // unit_test 配置使用 SharedPreferences mock，因此此处清空仅影响测试数据。
        final queue = PersistentMessageQueue.to;
        queue.dispose();
        await queue.flushPersistence();
      } else {
        fail('登录后台工作未在限定时间结束；保留测试平台直至 isolate 退出');
      }
    }
  });
}
