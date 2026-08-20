/// PlanListPage Widget 测试（模仿 channel_discover_page_test 的
/// TranslationProvider + ProviderScope override 注入模式）。
///
/// 覆盖：
/// - PL-1 空列表 → 渲染空态文案
/// - PL-2 多套餐渲染：名称/价格分→元（100 → ¥1.00）/周期中文/配额/描述
/// - PL-3 加载失败 → 错误态 + 重试按钮
/// - PL-4 当前套餐标记
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/billing/billing_provider.dart';
import 'package:imboy/page/billing/plan_list_page.dart';
import 'package:imboy/store/api/billing_api.dart';

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi({this.plansResult, this.subscriptionResult});

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

Widget _buildTestApp(BillingApi api) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [billingApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: PlanListPage()),
    ),
  );
}

void main() {
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
}

/// 首次 fetchPlans 失败、重试成功的 fake（驱动错误态 → 重试路径）。
class _FailOnceBillingApi extends BillingApi {
  _FailOnceBillingApi(this.onCall);

  final VoidCallback onCall;
  int calls = 0;

  @override
  Future<List<BillingPlan>?> fetchPlans() async {
    onCall();
    calls++;
    if (calls == 1) return null;
    return [_plan(id: 101, name: '标准版', price: 100, billingPeriod: 'month')];
  }

  @override
  Future<BillingSubscription?> fetchSubscription() async => null;
}
