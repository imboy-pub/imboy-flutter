/// PlanListPage Widget 测试（模仿 channel_discover_page_test 的
/// TranslationProvider + ProviderScope override 注入模式）。
///
/// 覆盖：
/// - PL-1 空列表 → 渲染空态文案
/// - PL-2 多套餐渲染：名称/价格分→元（100 → ¥1.00）/周期中文/配额/描述
/// - PL-3 加载失败 → 错误态 + 重试按钮
/// - PL-4 当前套餐标记
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/billing/billing_provider.dart';
import 'package:imboy/page/billing/plan_list_page.dart';
import 'package:imboy/store/api/billing_api.dart';

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi({
    this.plansResult,
    this.subscriptionResult,
    this.pendingSubscribe,
  });

  final Completer<int?>? pendingSubscribe;
  int subscribeCalls = 0;
  int invoiceCalls = 0;

  @override
  Future<int?> subscribe(int planId) async {
    subscribeCalls++;
    return pendingSubscribe == null ? null : await pendingSubscribe!.future;
  }

  @override
  Future<bool> generateInvoice(int subscriptionId) async {
    invoiceCalls++;
    return false;
  }

  final List<BillingPlan>? plansResult;
  final BillingSubscription? subscriptionResult;

  @override
  Future<List<BillingPlan>?> fetchPlans() async => plansResult;

  @override
  Future<BillingSubscription?> fetchSubscription() async => subscriptionResult;
}

BillingPlan _plan({
  required int id,
  required String name,
  required int price,
  required String billingPeriod,
}) {
  return BillingPlan(
    id: id,
    code: 'pro-$id',
    name: name,
    price: price,
    billingPeriod: billingPeriod,
    quotaConfig: const {'message': 100000, 'storage': -1},
    description: '专业版套餐说明',
    status: 1,
  );
}

Widget _buildTestApp(BillingApi api, {bool withLoading = false}) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [billingApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        builder: withLoading ? AppLoading.init() : null,
        home: const PlanListPage(),
      ),
    ),
  );
}

void main() {
  for (final throwing in [false, true]) {
    testWidgets(throwing ? 'PL-8 订阅异常结束加载并恢复按钮' : 'PL-7 订阅等待期间按钮禁用，失败后恢复可用', (
      tester,
    ) async {
      final pending = Completer<int?>();
      final api = _FakeBillingApi(
        pendingSubscribe: pending,
        plansResult: [
          _plan(
            id: 101,
            name: 'synthetic-plan',
            price: 100,
            billingPeriod: 'month',
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(api, withLoading: true));
      await tester.pumpAndSettle();
      final subscribe = find.byWidgetPredicate(
        (w) => w is CupertinoButton && w.color != null,
      );
      await tester.ensureVisible(find.text(t.billing.subscribe));
      await tester.tap(find.text(t.billing.subscribe));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CupertinoActionSheetAction,
          t.billing.payMethodAlipay,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.subscribeCalls, 1);
      expect(tester.widget<CupertinoButton>(subscribe).onPressed, isNull);
      expect(api.invoiceCalls, 0);
      if (throwing) {
        pending.completeError(Exception('synthetic subscription failure'));
      } else {
        pending.complete(null);
      }
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(t.main.payingDots), findsNothing);
      expect(find.text(t.billing.payFailed), findsOneWidget);
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.widget<CupertinoButton>(subscribe).onPressed, isNotNull);
      expect(api.subscribeCalls, 1);
      expect(api.invoiceCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('PL-6 取消支付方式选择不订阅、不创建账单且可重新打开', (tester) async {
    final api = _FakeBillingApi(
      plansResult: [
        _plan(
          id: 101,
          name: 'synthetic-plan',
          price: 100,
          billingPeriod: 'month',
        ),
      ],
    );
    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      final subscribe = find.widgetWithText(
        CupertinoButton,
        t.billing.subscribe,
      );
      await tester.ensureVisible(subscribe);
      await tester.tap(subscribe);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      const expectMock = bool.fromEnvironment('EXPECT_MOCK_PAYMENT');
      expect(
        find.text(t.billing.payMethodMock),
        expectMock ? findsOneWidget : findsNothing,
      );
      expect(find.text(t.billing.payMethodAlipay), findsOneWidget);
      expect(find.text(t.billing.payMethodWechat), findsOneWidget);
      await tester.tap(
        find.widgetWithText(CupertinoActionSheetAction, t.common.cancel),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(api.subscribeCalls, 0);
      expect(api.invoiceCalls, 0);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('PL-1 套餐列表为空 → 渲染空态文案', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(_FakeBillingApi(plansResult: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.billing.noPlans), findsOneWidget);
    expect(find.text(t.billing.subscribe), findsNothing);
  });

  testWidgets('PL-2 多套餐渲染：价格分→元（100 → ¥1.00）、周期与配额中文', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _FakeBillingApi(
          plansResult: [
            _plan(id: 101, name: '标准版', price: 100, billingPeriod: 'month'),
            _plan(id: 102, name: '专业版', price: 19900, billingPeriod: 'year'),
          ],
          subscriptionResult: BillingSubscription(
            id: 9001,
            planId: 101,
            status: BillingSubscriptionStatus.active,
            autoRenew: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('标准版'), findsOneWidget);
    expect(find.text('专业版'), findsOneWidget);
    // 价格单位分 → 元，两位小数
    expect(find.text('¥1.00'), findsOneWidget);
    expect(find.text('¥199.00'), findsOneWidget);
    // 周期中文
    expect(find.text(t.billing.planPeriodMonthly), findsOneWidget);
    expect(find.text(t.billing.planPeriodYearly), findsOneWidget);
    // 配额：storage=-1 → 不限（两张卡片各一条）
    expect(find.textContaining(t.billing.quotaUnlimited), findsNWidgets(2));
    // 描述
    expect(find.textContaining('专业版套餐说明'), findsNWidgets(2));
    // 两张卡片各一个订阅按钮
    expect(find.text(t.billing.subscribe), findsNWidgets(2));
    // 当前套餐标记（订阅的 planId=101）
    expect(find.text(t.billing.currentPlan), findsOneWidget);
  });

  testWidgets('PL-3 加载失败 → 错误态 + 重试按钮，重试触发重新加载', (tester) async {
    var callCount = 0;
    final api = _FailOnceBillingApi(() => callCount++);
    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    expect(find.text(t.billing.loadFailed), findsOneWidget);
    expect(find.text(t.billing.retry), findsOneWidget);

    await tester.tap(find.text(t.billing.retry));
    await tester.pumpAndSettle();

    // 重试成功后渲染套餐
    expect(find.text('标准版'), findsOneWidget);
    expect(api.calls, 2);
  });

  testWidgets('PL-4 失败后重试返回空列表应清除旧错误并显示空态', (tester) async {
    final api = _FailOnceBillingApi(() {}, emptyAfterRetry: true);
    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    expect(find.text(t.billing.loadFailed), findsOneWidget);
    await tester.tap(find.text(t.billing.retry));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text(t.billing.noPlans), findsOneWidget);
    expect(find.text(t.billing.loadFailed), findsNothing);
  });

  testWidgets('PL-5 请求异常后结束加载，重试可恢复空态', (tester) async {
    final api = _FailOnceBillingApi(
      () {},
      emptyAfterRetry: true,
      throwFirstLoad: true,
    );
    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(t.billing.loadFailed), findsOneWidget);
    await tester.tap(find.text(t.billing.retry));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text(t.billing.noPlans), findsOneWidget);
    expect(find.text(t.billing.loadFailed), findsNothing);
  });
}

/// 首次 fetchPlans 失败、重试成功的 fake（驱动错误态 → 重试路径）。
class _FailOnceBillingApi extends BillingApi {
  _FailOnceBillingApi(
    this.onCall, {
    this.emptyAfterRetry = false,
    this.throwFirstLoad = false,
  });

  final VoidCallback onCall;
  final bool emptyAfterRetry;
  final bool throwFirstLoad;
  int calls = 0;

  @override
  Future<List<BillingPlan>?> fetchPlans() async {
    onCall();
    calls++;
    if (calls == 1 && throwFirstLoad) {
      throw Exception('synthetic transport failure');
    }
    if (calls == 1) return null;
    if (emptyAfterRetry) return [];
    return [_plan(id: 101, name: '标准版', price: 100, billingPeriod: 'month')];
  }

  @override
  Future<BillingSubscription?> fetchSubscription() async => null;
}
