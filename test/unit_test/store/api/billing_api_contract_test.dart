/// BillingApi 契约测试（2026-08-20 Phase 5）。
///
/// 以 wallet_api_fail_contract_test 为范本：注入"记录请求 + 恒返指定响应"
/// 的 HttpClientAdapter，断言四个 billing 端点（plan/list、subscribe、
/// invoice/pay、subscription）的请求路径/方法/参数形状与响应解析。
///
/// 契约依据（后端 imboy/src/api/billing_handler.erl 实证）：
/// - GET  /api/v1/billing/plan/list      → payload {list:[{id,code,name,price(分),
///     billing_period,quota_config,description,status}]}
/// - POST /api/v1/billing/subscribe       → body {plan_id:int}（后端 is_integer
///     校验，必须传 JSON 数字不能传字符串）→ payload {subscription_id:int}
/// - POST /api/v1/billing/invoice/pay     → body {invoice_no,payment_method} →
///     payload {invoice_no,payment_no,payment_method,amount,status}，
///     **不含 pay_params**（与 wallet recharge_pay 不同构）
/// - GET  /api/v1/billing/subscription    → payload 为订阅 map 或 {}（无订阅）
///
/// ⚠️ 环境坑（同 wallet 测试）：subscribe/payInvoice 失败分支内部
/// `await AppLoading.showError`（依赖 overlay 动画），必须 testWidgets +
/// AppLoading.init() + 有界 pump 循环驱动，且调完后 pump 完 toast 的
/// 2s Timer，否则报 pending timer。adapter 必须在构造 BillingApi **之前**
/// 注入（只对之后构造的 dio 实例生效）。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/billing_api.dart';

/// 记录请求并恒返指定 statusCode + JSON body 的出口。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  /// 每次请求的 (method, path, data, queryParameters)
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      options.method,
      options.uri.path,
      options.data,
      Map<String, dynamic>.from(options.queryParameters),
    ));
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    // ⚠️ mock platform channel：未 mock 的 MethodChannel 在 testWidgets binding
    // 下返回永不完成的 future，HttpClient._setDefaultConfig 走 accessToken →
    // flutter_secure_storage channel，不 mock 就挂死（同 wallet 测试注释）。
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: AppLoading.init(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  /// 有界 pump 驱动一次 API 调用直到完成（覆盖 dio 异步链 + 失败分支
  /// showError 的 overlay 动画），随后 pump 完 toast 2s Timer 防
  /// pending timer。
  Future<T> drive<T>(WidgetTester tester, Future<T> Function() fn) async {
    final done = Completer<T>();
    fn().then(done.complete, onError: done.completeError);
    for (var i = 0; i < 60 && !done.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final result = await done.future;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return result;
  }

  /// 断言唯一一条被记录的请求（Record 内含 Map，== 不做深度比较，
  /// 须逐字段断言；body/query 用 equals 匹配器做深度比较）。
  void expectSingleRequest(
    _RecordingAdapter adapter, {
    required String method,
    required String path,
    Object? body,
    Map<dynamic, dynamic> query = const {},
  }) {
    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.$1, method);
    expect(req.$2, path);
    expect(req.$3, body);
    expect(req.$4, equals(query));
  }

  group('fetchPlans', () {
    testWidgets('GET plan/list 解析套餐列表（价格单位分）', (tester) async {
      await pumpApp(tester);
      final adapter = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{"list":['
        '{"id":101,"code":"pro","name":"专业版","price":1500,'
        '"billing_period":"month","quota_config":{"message":100000,"storage":-1},'
        '"description":"专业版套餐","status":1},'
        '{"id":102,"code":"pro-y","name":"专业版年付","price":15000,'
        '"billing_period":"year","quota_config":{},'
        '"description":"","status":1}]}}',
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      final plans = await drive(tester, api.fetchPlans);

      expectSingleRequest(
        adapter,
        method: 'GET',
        path: '/api/v1/billing/plan/list',
      );
      expect(plans, hasLength(2));
      final pro = plans!.first;
      expect(pro.id, 101);
      expect(pro.code, 'pro');
      expect(pro.name, '专业版');
      expect(pro.price, 1500);
      expect(pro.priceYuan, 15.0);
      expect(pro.billingPeriod, 'month');
      expect(pro.quotaConfig['message'], 100000);
      expect(pro.description, '专业版套餐');
      expect(plans[1].isYearly, true);
    });

    testWidgets('失败（非 0 业务码）返回 null（静默，页面渲染错误态）', (tester) async {
      await pumpApp(tester);
      HttpClient.adapterForTest = _RecordingAdapter(
        200,
        '{"code":1,"msg":"server error","payload":null}',
      );
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      expect(await drive(tester, api.fetchPlans), isNull);
    });
  });

  group('subscribe', () {
    testWidgets('POST subscribe 发送整型 plan_id 并返回 subscription_id', (
      tester,
    ) async {
      await pumpApp(tester);
      final adapter = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{"subscription_id":9001}}',
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      final subId = await drive(tester, () => api.subscribe(101));

      expectSingleRequest(
        adapter,
        method: 'POST',
        path: '/api/v1/billing/subscribe',
        body: {'plan_id': 101},
      );
      expect(subId, 9001);
    });

    testWidgets('失败（套餐不存在）返回 null', (tester) async {
      await pumpApp(tester);
      HttpClient.adapterForTest = _RecordingAdapter(
        200,
        '{"code":1,"msg":"套餐不存在","payload":null}',
      );
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      expect(await drive(tester, () => api.subscribe(404)), isNull);
    });
  });

  group('payInvoice', () {
    testWidgets('POST invoice/pay 发送 invoice_no + payment_method', (
      tester,
    ) async {
      await pumpApp(tester);
      final adapter = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{"invoice_no":"INV-1",'
        '"payment_no":"MOCK_INV-1","payment_method":"alipay",'
        '"amount":1500,"status":1}}',
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      final result = await drive(
        tester,
        () => api.payInvoice('INV-1', 'alipay'),
      );

      expectSingleRequest(
        adapter,
        method: 'POST',
        path: '/api/v1/billing/invoice/pay',
        body: {'invoice_no': 'INV-1', 'payment_method': 'alipay'},
      );
      expect(result, isNotNull);
      expect(result!['invoice_no'], 'INV-1');
      expect(result['payment_no'], 'MOCK_INV-1');
      expect(result['status'], 1);
      // 契约实证：billing pay 响应不含 pay_params（wallet recharge_pay 才有）
      expect(result.containsKey('pay_params'), isFalse);
    });

    testWidgets('失败（账单已支付）返回 null', (tester) async {
      await pumpApp(tester);
      HttpClient.adapterForTest = _RecordingAdapter(
        200,
        '{"code":1,"msg":"账单已支付","payload":null}',
      );
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      expect(
        await drive(tester, () => api.payInvoice('INV-1', 'alipay')),
        isNull,
      );
    });
  });

  group('fetchSubscription', () {
    testWidgets('GET subscription?tenant_id=0 解析当前订阅', (tester) async {
      await pumpApp(tester);
      final adapter = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{"id":9001,"tenant_id":0,'
        '"owner_uid":118,"plan_id":101,"status":1,'
        '"current_period_start":1755600000000,'
        '"current_period_end":1758192000000,"auto_renew":true}}',
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      final sub = await drive(tester, api.fetchSubscription);

      expectSingleRequest(
        adapter,
        method: 'GET',
        path: '/api/v1/billing/subscription',
        query: {'tenant_id': 0},
      );
      expect(sub, isNotNull);
      expect(sub!.id, 9001);
      expect(sub.planId, 101);
      expect(sub.isActive, true);
      expect(sub.autoRenew, true);
    });

    testWidgets('无订阅（空对象 payload）返回 null 而非空模型', (tester) async {
      await pumpApp(tester);
      HttpClient.adapterForTest = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{}}',
      );
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      expect(await drive(tester, api.fetchSubscription), isNull);
    });
  });

  group('invoice generate + list（编排内部步骤）', () {
    testWidgets('POST invoice/generate 发送 subscription_id，幂等视为成功', (
      tester,
    ) async {
      await pumpApp(tester);
      final adapter = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{"already_generated":true}}',
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      final ok = await drive(tester, () => api.generateInvoice(9001));

      expectSingleRequest(
        adapter,
        method: 'POST',
        path: '/api/v1/billing/invoice/generate',
        body: {'subscription_id': 9001},
      );
      expect(ok, isTrue);
    });

    testWidgets('GET invoice/list?subscription_id= 解析账单（倒序）', (tester) async {
      await pumpApp(tester);
      final adapter = _RecordingAdapter(
        200,
        '{"code":0,"msg":"success.","payload":{"list":['
        '{"id":2,"invoice_no":"INV-2","subscription_id":9001,'
        '"amount":1500,"currency":"CNY","status":0,"payment_no":null},'
        '{"id":1,"invoice_no":"INV-1","subscription_id":9001,'
        '"amount":1500,"currency":"CNY","status":1,"payment_no":"P-1"}]}}',
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = BillingApi();

      final invoices = await drive(tester, () => api.listInvoices(9001));

      expectSingleRequest(
        adapter,
        method: 'GET',
        path: '/api/v1/billing/invoice/list',
        query: {'subscription_id': 9001},
      );
      expect(invoices, hasLength(2));
      expect(invoices![0].invoiceNo, 'INV-2');
      expect(invoices[0].isPaid, false);
      expect(invoices[1].invoiceNo, 'INV-1');
      expect(invoices[1].isPaid, true);
    });
  });
}
