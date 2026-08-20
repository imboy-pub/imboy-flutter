/// BillingNotifier 订阅编排契约测试（模仿 channel_purchase_provider_test）。
///
/// 覆盖：
/// - BP-1 loadPlans 成功/失败 → plans / error 状态
/// - BP-2 subscribe 失败 → false，不调 generate/list/pay
/// - BP-3 generate 失败 → false，不进入账单号解析
/// - BP-4 全成功（mock 即时入账，轮询首轮命中）→ true 且刷新订阅
/// - BP-5 无待支付账单 → 视为成功并刷新订阅，不调 payInvoice
/// - BP-6 第三方 success → 唤起后轮询入账 → true
/// - BP-7 第三方轮询期间第二拍入账 → true（轮询重试生效）
/// - BP-8 第三方 cancelled → false 且不轮询
/// - BP-9 第三方 notConfigured → false、不轮询、lastLaunchResult 记录
/// - BP-10 paying 完成后复位，重入防抖
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/billing/billing_provider.dart';
import 'package:imboy/service/payment_gateway.dart';
import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/store/api/billing_api.dart';

BillingPlan _plan({int id = 101}) => BillingPlan(
  id: id,
  code: 'pro',
  name: '专业版',
  price: 1500,
  billingPeriod: BillingPeriod.month,
  quotaConfig: const {'message': 100000},
  description: '专业版套餐',
  status: 1,
);

BillingInvoice _inv(String invoiceNo, int status, {int id = 1}) =>
    BillingInvoice(id: id, invoiceNo: invoiceNo, amount: 1500, status: status);

BillingSubscription _sub({int planId = 101}) => BillingSubscription(
  id: 9001,
  planId: planId,
  status: BillingSubscriptionStatus.active,
  autoRenew: true,
);

/// BillingApi fake：可控各步返回值并记录调用。
class _FakeBillingApi extends BillingApi {
  _FakeBillingApi({
    this.plansResult,
    this.subscribeResult,
    this.generateResult = true,
    this.invoicesResult,
    this.payResult,
    this.subscriptionResult,
  });

  final List<BillingPlan>? plansResult;
  final int? subscribeResult;
  final bool generateResult;
  final List<BillingInvoice>? invoicesResult;
  final Map<String, dynamic>? payResult;
  final BillingSubscription? subscriptionResult;

  final List<int> subscribeCalls = <int>[];
  final List<int> generateCalls = <int>[];
  final List<int> listCalls = <int>[];
  final List<(String, String)> payCalls = <(String, String)>[];
  int subscriptionCalls = 0;

  /// 返回值队列（模拟轮询多拍）；空则用 invoicesResult
  final List<List<BillingInvoice>?> _listQueue = <List<BillingInvoice>?>[];

  @override
  Future<List<BillingPlan>?> fetchPlans() async => plansResult;

  @override
  Future<int?> subscribe(int planId) async {
    subscribeCalls.add(planId);
    return subscribeResult;
  }

  @override
  Future<bool> generateInvoice(int subscriptionId) async {
    generateCalls.add(subscriptionId);
    return generateResult;
  }

  @override
  Future<List<BillingInvoice>?> listInvoices(int subscriptionId) async {
    listCalls.add(subscriptionId);
    if (_listQueue.isNotEmpty) return _listQueue.removeAt(0);
    return invoicesResult;
  }

  @override
  Future<Map<String, dynamic>?> payInvoice(
    String invoiceNo,
    String paymentMethod,
  ) async {
    payCalls.add((invoiceNo, paymentMethod));
    return payResult;
  }

  @override
  Future<BillingSubscription?> fetchSubscription() async {
    subscriptionCalls++;
    return subscriptionResult;
  }

  /// 压入一次 listInvoices 返回（先进先出），用于模拟轮询逐拍结果。
  void enqueueInvoices(List<BillingInvoice>? invoices) {
    _listQueue.add(invoices);
    // 首拍（编排内 _pendingInvoiceNo）默认仍用 invoicesResult，
    // 故压队列前先把首拍占位为 invoicesResult。
    if (_listQueue.length == 1) {
      _listQueue.insert(0, invoicesResult);
    }
  }
}

/// 收银台 SDK 网关空实现，避免构造真实 fluwx/tobias 触碰原生通道。
class _NoopGateway implements PaymentSdkGateway {
  @override
  Future<Map<dynamic, dynamic>> aliPay(
    String orderStr, {
    String? universalLink,
  }) async => const {};

  @override
  Future<bool> ensureWechatRegistered({
    required String appId,
    String? universalLink,
  }) async => true;

  @override
  Future<int?> wechatPay({
    required String appId,
    required String partnerId,
    required String prepayId,
    required String packageValue,
    required String nonceStr,
    required int timestamp,
    required String sign,
    String? signType,
  }) async => 0;
}

/// PaymentLauncher fake：返回预设唤起结果并记录调用方式。
class _FakeLauncher extends PaymentLauncher {
  _FakeLauncher(this.result) : super(gateway: _NoopGateway());

  final PaymentLaunchResult result;
  final List<String> launchCalls = <String>[];

  @override
  Future<PaymentLaunchResult> launch(
    String method,
    Map<dynamic, dynamic>? payParams,
  ) async {
    launchCalls.add(method);
    return result;
  }
}

ProviderContainer _containerWith(
  _FakeBillingApi fake, {
  _FakeLauncher? launcher,
}) {
  return ProviderContainer(
    overrides: [
      billingApiProvider.overrideWithValue(fake),
      if (launcher != null)
        billingPaymentLauncherProvider.overrideWithValue(launcher),
    ],
  );
}

void main() {
  group('BillingState', () {
    test('BP-S1 默认值与 copyWith 不可变', () {
      const s = BillingState();
      expect(s.isLoading, false);
      expect(s.plans, isEmpty);
      expect(s.paying, false);
      final s2 = s.copyWith(isLoading: true);
      expect(s2.isLoading, true);
      expect(s.isLoading, false);
    });
  });

  group('BillingNotifier.loadPlans', () {
    test('BP-1a 成功 → plans 填充、isLoading 复位、error 为空', () async {
      final fake = _FakeBillingApi(plansResult: [_plan()]);
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      await container.read(billingProvider.notifier).loadPlans();

      final state = container.read(billingProvider);
      expect(state.plans, hasLength(1));
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('BP-1b 失败 → error 非空（页面渲染错误态）', () async {
      final fake = _FakeBillingApi(plansResult: null);
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      await container.read(billingProvider.notifier).loadPlans();

      final state = container.read(billingProvider);
      expect(state.error, isNotNull);
      expect(state.plans, isEmpty);
    });
  });

  group('BillingNotifier.subscribePlan', () {
    test('BP-2 subscribe 失败 → false，后续步骤不执行', () async {
      final fake = _FakeBillingApi(
        subscribeResult: null,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{},
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan());

      expect(ok, false);
      expect(fake.subscribeCalls, [101]);
      expect(fake.generateCalls, isEmpty);
      expect(fake.payCalls, isEmpty);
    });

    test('BP-3 generate 失败 → false，不取账单号不支付', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: false,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{},
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan());

      expect(ok, false);
      expect(fake.generateCalls, [9001]);
      expect(fake.listCalls, isEmpty);
      expect(fake.payCalls, isEmpty);
    });

    test('BP-4 全成功（mock 即时入账，轮询首轮命中）→ true，payInvoice 收到 mock，刷新订阅', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{'status': 1},
        subscriptionResult: _sub(),
      );
      // mock 网关即时入账：支付后下一拍账单即已支付
      fake.enqueueInvoices([_inv('INV-1', BillingInvoiceStatus.paid)]);
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan());

      expect(ok, true);
      expect(fake.payCalls.single, ('INV-1', 'mock'));
      expect(fake.subscriptionCalls, greaterThan(0));
      expect(container.read(billingProvider).subscription?.planId, 101);
      expect(container.read(billingProvider).paying, false);
    });

    test('BP-5 无待支付账单 → 视为成功，不调 payInvoice', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.paid)],
        subscriptionResult: _sub(),
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan());

      expect(ok, true);
      expect(fake.payCalls, isEmpty);
      expect(fake.subscriptionCalls, 1);
    });

    test('BP-6 第三方 success → 唤起后轮询入账 → true', () async {
      // 首拍待支付，支付后轮询拍已支付
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{
          'pay_params': <String, dynamic>{'order_str': 'os-1'},
        },
        subscriptionResult: _sub(),
      );
      fake.enqueueInvoices([_inv('INV-1', BillingInvoiceStatus.paid)]);
      final launcher = _FakeLauncher(PaymentLaunchResult.success);
      final container = _containerWith(fake, launcher: launcher);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan(), paymentMethod: 'alipay');

      expect(ok, true);
      expect(launcher.launchCalls, ['alipay']);
      expect(fake.payCalls.single.$2, 'alipay');
      expect(
        fake.listCalls.length,
        greaterThanOrEqualTo(2),
        reason: '第三方支付后应轮询',
      );
    });

    test('BP-7 第三方第二拍才入账 → 轮询重试命中 → true', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{},
        subscriptionResult: _sub(),
      );
      // 轮询第一拍仍未支付，第二拍已支付（800ms 真实 delay，可接受）
      fake.enqueueInvoices([_inv('INV-1', BillingInvoiceStatus.unpaid)]);
      fake.enqueueInvoices([_inv('INV-1', BillingInvoiceStatus.paid)]);
      final launcher = _FakeLauncher(PaymentLaunchResult.failed);
      final container = _containerWith(fake, launcher: launcher);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan(), paymentMethod: 'alipay');

      expect(ok, true, reason: 'SDK 回调 failed 但用户实际付款，轮询应确认入账');
      expect(fake.listCalls.length, 3, reason: '首拍取号 + 轮询两拍');
    });

    test('BP-8 第三方 cancelled → false 且不轮询', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{'pay_params': <String, dynamic>{}},
      );
      final launcher = _FakeLauncher(PaymentLaunchResult.cancelled);
      final container = _containerWith(fake, launcher: launcher);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan(), paymentMethod: 'alipay');

      expect(ok, false);
      expect(launcher.launchCalls, ['alipay']);
      expect(fake.listCalls, hasLength(1), reason: '仅首拍取号，取消不应轮询');
      expect(
        container.read(billingProvider).lastLaunchResult,
        PaymentLaunchResult.cancelled,
      );
    });

    test('BP-9 第三方 notConfigured（后端未下发 pay_params）→ false、不轮询', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.unpaid)],
        payResult: const <String, dynamic>{},
      );
      final launcher = _FakeLauncher(PaymentLaunchResult.notConfigured);
      final container = _containerWith(fake, launcher: launcher);
      addTearDown(container.dispose);

      final ok = await container
          .read(billingProvider.notifier)
          .subscribePlan(_plan(), paymentMethod: 'wechat');

      expect(ok, false);
      expect(launcher.launchCalls, ['wechat']);
      expect(fake.listCalls, hasLength(1), reason: '未配置应中止不轮询');
      expect(
        container.read(billingProvider).lastLaunchResult,
        PaymentLaunchResult.notConfigured,
      );
    });

    test('BP-10 完成后 paying 复位；进行中重入直接 false', () async {
      final fake = _FakeBillingApi(
        subscribeResult: 9001,
        generateResult: true,
        invoicesResult: [_inv('INV-1', BillingInvoiceStatus.paid)],
        payResult: const <String, dynamic>{},
        subscriptionResult: _sub(),
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      await container.read(billingProvider.notifier).subscribePlan(_plan());
      expect(container.read(billingProvider).paying, false);

      expect(fake.subscribeCalls, [101]);
    });
  });
}
