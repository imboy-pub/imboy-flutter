/// APP-M01-A01 — 坐席上下文门（seat-contexts 驱动入口可见性）
///
/// 覆盖：
/// - `csEntryVisibleFromContexts` 纯函数：任一「active assignment +
///   enabled seat」上下文即可见；空列表 / 全 disabled seat / 全缺
///   assignment → 不可见（fail-closed）；
/// - CsSeatContext 解析：TSID String、workspaces/capabilities 宽容解析、
///   seat_enabled 非布尔不误判；
/// - CsWorkspaceEntryTile widget 行为：有合格上下文 → 渲染入口；
///   无/失败 → 零占位（SizedBox.shrink）。
///
/// 网络出口用 HttpClient.adapterForTest 注入（与 cs_api_contract_test
/// 同款机制）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/storage.dart';

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

/// 记录请求并恒返指定 statusCode + JSON envelope 的出口。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
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

CsSeatContext _context({
  String orgId = '7266418340025468901',
  String identityId = '7266418340025468902',
  bool seatEnabled = true,
}) {
  return CsSeatContext(
    organizationId: orgId,
    organizationName: '组织$orgId',
    businessIdentityId: identityId,
    seatEnabled: seatEnabled,
  );
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // bootstrap 链路会读 flutter_secure_storage（平台通道）：无 mock 时
    // fakeAsync 下 MethodChannel 永不完成，页面 bootstrap 挂起（与
    // cs_session_page_test 同款 mock：无 token 直通）。
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'readAll') return <String, String>{};
          return null;
        });
    await StorageService.init();
  });

  group('APP-M01-A01 csEntryVisibleFromContexts（纯函数四态）', () {
    test('任一 eligible 上下文 → 可见（多 Org 任一席位成立）', () {
      expect(
        csEntryVisibleFromContexts([
          _context(orgId: '1', seatEnabled: false),
          _context(orgId: '2', seatEnabled: true),
        ]),
        isTrue,
      );
    });

    test('空列表（无 active member Org）→ 不可见', () {
      expect(csEntryVisibleFromContexts(const <CsSeatContext>[]), isFalse);
    });

    test('全部 disabled seat → 不可见', () {
      expect(
        csEntryVisibleFromContexts([
          _context(seatEnabled: false),
          _context(orgId: '2', seatEnabled: false),
        ]),
        isFalse,
      );
    });

    test('全部缺 assignment（identity 为空）→ 不可见', () {
      expect(csEntryVisibleFromContexts([_context(identityId: '')]), isFalse);
    });
  });

  group('APP-M01-A01 CsSeatContext 解析', () {
    test('JSON wire → TSID String + 宽容解析', () {
      final c = CsSeatContext.fromJson({
        'organization_id': 7266418340025468901,
        'organization_name': '示例组织',
        'workspaces': [
          {'id': 7266418340025468921, 'name': '默认工作区'},
        ],
        'business_identity_id': 7266418340025468902,
        'seat_enabled': true,
        'capabilities': ['conversation.read'],
      });
      expect(c.organizationId, '7266418340025468901');
      expect(c.businessIdentityId, '7266418340025468902');
      expect(c.isEligible, isTrue);
      expect(c.workspaces.single.name, '默认工作区');
    });

    test('seat_enabled 缺失 → false（unknown fail-closed，不保守放行）', () {
      final c = CsSeatContext.fromJson({
        'organization_id': 7266418340025468901,
        'business_identity_id': 7266418340025468902,
      });
      expect(c.seatEnabled, isFalse);
      expect(c.isEligible, isFalse);
    });
  });

  group('APP-M01-A01 CsWorkspaceEntryTile widget', () {
    Future<void> pumpEntry(WidgetTester tester) async {
      await tester.pumpWidget(
        // 对齐既有 CS widget 测试：TranslationProvider 挂在
        // MaterialApp.builder 内（InheritedWidget 需在导航子树内）。
        MaterialApp(
          builder: (context, child) =>
              TranslationProvider(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: CsWorkspaceEntryTile()),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('合格坐席（active assignment + enabled seat）→ 入口渲染', (tester) async {
      HttpClient.adapterForTest = _RecordingAdapter(
        200,
        okEnvelope(
          payload: {
            'contexts': [
              {
                'organization_id': 7266418340025468901,
                'organization_name': '示例组织',
                'business_identity_id': 7266418340025468902,
                'seat_enabled': true,
              },
            ],
          },
        ),
      );
      addTearDown(() => HttpClient.adapterForTest = null);

      await pumpEntry(tester);

      expect(find.text('客服工作台'), findsOneWidget, reason: '入口可见');
    });

    testWidgets('disabled seat → 入口零占位（不渲染）', (tester) async {
      HttpClient.adapterForTest = _RecordingAdapter(
        200,
        okEnvelope(
          payload: {
            'contexts': [
              {
                'organization_id': 7266418340025468901,
                'business_identity_id': 7266418340025468902,
                'seat_enabled': false,
              },
            ],
          },
        ),
      );
      addTearDown(() => HttpClient.adapterForTest = null);

      await pumpEntry(tester);

      expect(find.text('客服工作台'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('seat-contexts 失败（403）→ fail-closed 零占位', (tester) async {
      final adapter = _RecordingAdapter(403, {'code': 403, 'msg': 'forbidden'});
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);

      await pumpEntry(tester);

      expect(adapter.paths, ['/api/v1/cs/me/seat-contexts']);
      expect(find.text('客服工作台'), findsNothing);
    });
  });
}
