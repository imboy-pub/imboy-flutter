import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_provider.dart';
import 'package:imboy/page/mine/denylist/denylist_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedAdapter implements HttpClientAdapter {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    entered.complete();
    await release.future;
    return ResponseBody.fromString(
      '{"code":0,"msg":"success","payload":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _TimeoutAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'successful local toggle updates state without deleting twice',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactSettingProvider.notifier);
      expect(
        await notifier.toggleDenylist(
          peerId: '9007199254740993',
          addToDenylist: true,
          peerData: {},
        ),
        isTrue,
      );
      expect(container.read(contactSettingProvider).isInDenylist, isTrue);
      expect(
        await notifier.toggleDenylist(
          peerId: '9007199254740993',
          addToDenylist: false,
          peerData: {},
        ),
        isTrue,
      );
      expect(container.read(contactSettingProvider).isInDenylist, isFalse);
    },
  );
  test('delayed unblock response cannot delete another account row', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    final encode = base64Url.encode;
    final token =
        '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.${encode(utf8.encode('synthetic'))}';
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'read' && call.arguments['key'] == 'secure_token'
              ? token
              : null,
        );
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    await db.execute(
      'CREATE TABLE user_denylist (user_id INTEGER, denied_user_id INTEGER)',
    );
    await db.insert('user_denylist', {
      'user_id': '1002',
      'denied_user_id': '9007199254740993',
    });
    final adapter = _DelayedAdapter();
    HttpClient.adapterForTest = adapter;
    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      HttpClient.adapterForTest = null;
      SqliteService.setDbForTest(null);
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final pending = container
        .read(denylistProvider.notifier)
        .removeDenylist('9007199254740993');
    await adapter.entered.future.timeout(const Duration(seconds: 5));
    await StorageService.to.setString(Keys.currentUid, '1002');
    adapter.release.complete();
    expect(await pending, DenylistMutationResult.sessionChanged);
    expect(await db.query('user_denylist'), hasLength(1));
  });
  test('server unblock success and local database failure reports partial', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '1001');
    final encode = base64Url.encode;
    final token =
        '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.${encode(utf8.encode('synthetic'))}';
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'read' && call.arguments['key'] == 'secure_token'
              ? token
              : null,
        );
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    await db.execute(
      'CREATE TABLE user_denylist (user_id INTEGER, denied_user_id INTEGER)',
    );
    await db.insert('user_denylist', {
      'user_id': '1001',
      'denied_user_id': '9007199254740993',
    });
    final adapter = _DelayedAdapter();
    HttpClient.adapterForTest = adapter;
    final container = ProviderContainer();
    final subscription = container.listen(denylistProvider, (_, _) {});
    addTearDown(() async {
      subscription.close();
      container.dispose();
      HttpClient.adapterForTest = null;
      SqliteService.setDbForTest(null);
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final pending = container
        .read(denylistProvider.notifier)
        .removeDenylist('9007199254740993');
    await adapter.entered.future.timeout(const Duration(seconds: 5));
    adapter.release.complete();
    expect(await pending, DenylistMutationResult.partial);
    expect(await db.query('user_denylist'), isEmpty);
  });
  test('unblock timeout reports unknown and does not modify local row', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '1001');
    final encode = base64Url.encode;
    final token =
        '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.${encode(utf8.encode('synthetic'))}';
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'read' && call.arguments['key'] == 'secure_token'
              ? token
              : null,
        );
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    await db.execute(
      'CREATE TABLE user_denylist (user_id INTEGER, denied_user_id INTEGER)',
    );
    await db.insert('user_denylist', {
      'user_id': '1001',
      'denied_user_id': '9007199254740993',
    });
    final adapter = _TimeoutAdapter();
    HttpClient.adapterForTest = adapter;
    final container = ProviderContainer();
    final subscription = container.listen(denylistProvider, (_, _) {});
    addTearDown(() async {
      subscription.close();
      container.dispose();
      HttpClient.adapterForTest = null;
      SqliteService.setDbForTest(null);
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final pending = container
        .read(denylistProvider.notifier)
        .removeDenylist('9007199254740993');
    expect(await pending, DenylistMutationResult.unknown);
    expect(adapter.calls, 1);
    expect(await db.query('user_denylist'), hasLength(1));
  });
}
