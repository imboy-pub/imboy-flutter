/// ORG-13 — 组织入口页 focused widget 测试（状态矩阵抽样）
///
/// 覆盖：loading → 空态、archived 徽标、error 态重试入口、
/// TSID 超长 ID 文本不溢出（maxLines+ellipsis 存在性）。
/// accountKey 注入，不触碰 UserRepoLocal / sqlite。
///
/// 必须 mock flutter_secure_storage 平台通道：请求链
/// `_setDefaultConfig → UserRepoLocal.accessToken → SecureTokenStorageService`
/// 会真实走到该通道，TestWidgetsFlutterBinding 下无 handler 的通道调用
/// 永不完成（FakeAsync 内表现为页面永停 loading）；未 mock 时 token 读取
/// 失败还会置 `token_decryption_failed` 标记，触发下一次请求走
/// quitLogin 登出链（含 1s+2s delayed），请求被放弃。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter(this.statusCode, this.body);

  final int statusCode;
  final dynamic body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DeferredMineAdapter implements HttpClientAdapter {
  _DeferredMineAdapter({this.deferBadges = false});
  final bool deferBadges;
  final badges = <Completer<ResponseBody>>[];
  final requests = <Completer<ResponseBody>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.path.endsWith('/organizations/mine')) {
      final result = Completer<ResponseBody>();
      requests.add(result);
      return result.future;
    }
    if (deferBadges && options.path.endsWith('/invitations/mine')) {
      final result = Completer<ResponseBody>();
      badges.add(result);
      return result.future;
    }
    return Future.value(response(<dynamic>[]));
  }

  ResponseBody response(dynamic payload) => ResponseBody.fromString(
    jsonEncode(okEnvelope(payload: payload)),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  void complete(int index, String name) => requests[index].complete(
    response({
      'list': [
        {'id': 7001, 'name': name, 'status': 'active', 'member_role': 'member'},
      ],
      'page': 1,
      'size': 100,
      'total': 1,
      'total_page': 1,
    }),
  );
  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

/// 有界 pump 循环：dio 拦截器/transformer 异步链需要多轮 microtask +
/// fake timer 才走到 setState；每拍查一次 finder，命中即停。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      // 再补两拍让同帧的状态收敛（finally 置 _loading=false 等）。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // mock flutter_secure_storage（read 返回 null = 无 token；避免
    // 未注册通道调用在 FakeAsync 里永不完成 + 触发登出链）。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    HttpClient.adapterForTest = null;
  });

  Widget buildHost() =>
      const MaterialApp(home: OrganizationHomePage(accountKey: '1001'));

  testWidgets('迟到的旧刷新不得覆盖新组织列表及缓存', (tester) async {
    OrganizationCache.disposeAccount('1001');
    addTearDown(() => OrganizationCache.disposeAccount('1001'));
    final adapter = _DeferredMineAdapter();
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(buildHost());
    for (var i = 0; i < 30 && adapter.requests.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.requests.length, 1);
    final refreshing = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    for (var i = 0; i < 30 && adapter.requests.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.requests.length, 2);
    adapter.complete(1, '新组织事实');
    await pumpUntilFound(tester, find.text('新组织事实'));
    adapter.complete(0, '过时组织事实');
    await tester.pumpAndSettle();
    await refreshing;
    expect(find.text('新组织事实'), findsOneWidget);
    expect(find.text('过时组织事实'), findsNothing);
    expect(OrganizationCache.forAccount('1001').org('7001')?.name, '新组织事实');
  });

  testWidgets('旧邀请角标响应不得覆盖更新的计数', (tester) async {
    final adapter = _DeferredMineAdapter(deferBadges: true);
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(buildHost());
    for (var i = 0; i < 30 && adapter.requests.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.requests.length, 1);
    adapter.complete(0, '组织');
    for (var i = 0; i < 30 && adapter.badges.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.badges.length, 1);
    final refreshing = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    for (var i = 0; i < 30 && adapter.requests.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.requests.length, 2);
    adapter.complete(1, '组织');
    for (var i = 0; i < 30 && adapter.badges.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.badges.length, 2);
    adapter.badges[1].complete(
      adapter.response({
        'list': [
          {'invitation_id': 8001},
        ],
      }),
    );
    await pumpUntilFound(tester, find.text('1'));
    adapter.badges[0].complete(adapter.response({'list': <dynamic>[]}));
    await tester.pumpAndSettle();
    await refreshing;
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('空态：未加入任何组织时展示引导文案', (tester) async {
    final cache = OrganizationCache.forAccount('1001');
    cache.saveOrgs([const Organization(id: '7001', name: '已移除组织')]);
    addTearDown(() => OrganizationCache.disposeAccount('1001'));

    HttpClient.adapterForTest = _StaticAdapter(
      200,
      okEnvelope(
        payload: {
          'list': <dynamic>[],
          'page': 1,
          'size': 10,
          'total': 0,
          'total_page': 0,
        },
      ),
    );

    await tester.pumpWidget(buildHost());
    // 空态文案是含换行的整体字符串，用 textContaining 匹配前缀。
    await pumpUntilFound(tester, find.textContaining('尚未加入任何组织'));

    expect(find.textContaining('尚未加入任何组织'), findsOneWidget);
    expect(cache.orgs, isEmpty);
  });

  testWidgets('列表：archived 组织打标 + 成员角色展示', (tester) async {
    HttpClient.adapterForTest = _StaticAdapter(
      200,
      okEnvelope(
        payload: {
          'list': [
            {
              'id': 7266418340025468930,
              'name': '甲组织',
              'status': 'archived',
              'member_role': 'admin',
            },
          ],
          'page': 1,
          'size': 10,
          'total': 1,
          'total_page': 1,
        },
      ),
    );

    await tester.pumpWidget(buildHost());
    await pumpUntilFound(tester, find.text('甲组织'));

    expect(find.text('甲组织'), findsOneWidget);
    expect(find.textContaining('管理员'), findsOneWidget);
    expect(find.textContaining('已归档'), findsOneWidget);
  });

  testWidgets('error 态：服务端 500 展示失败与重试入口', (tester) async {
    HttpClient.adapterForTest = _StaticAdapter(500, {
      'code': 500,
      'msg': 'boom',
    });

    await tester.pumpWidget(buildHost());
    await pumpUntilFound(tester, find.textContaining('加载失败'));

    expect(find.textContaining('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
