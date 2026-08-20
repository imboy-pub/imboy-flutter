import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/payment_config.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/billing/billing_provider.dart';
import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/store/api/billing_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 套餐订阅页：数据驱动渲染后端可配置的套餐卡片。
///
/// 编排（订阅 → 生成账单 → 支付 → 轮询入账 → 刷新）在
/// [BillingNotifier.subscribePlan]，本页只负责展示与触发。
class PlanListPage extends ConsumerStatefulWidget {
  const PlanListPage({super.key});

  @override
  ConsumerState<PlanListPage> createState() => _PlanListPageState();
}

class _PlanListPageState extends ConsumerState<PlanListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(billingProvider.notifier).loadPlans();
      ref.read(billingProvider.notifier).loadSubscription();
    });
  }

  /// 支付方式选择（同钱包充值范式：mock 仅开发环境展示）。
  void _showPayMethodSheet(BillingPlan plan) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.billing.payMethodTitle),
        actions: [
          if (PaymentConfig.isMockPayAllowed)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _doSubscribe(plan, 'mock');
              },
              child: Text(t.billing.payMethodMock),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doSubscribe(plan, 'alipay');
            },
            child: Text(t.billing.payMethodAlipay),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doSubscribe(plan, 'wechat');
            },
            child: Text(t.billing.payMethodWechat),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  /// 执行订阅：编排成功/失败按第三方唤起结果差异化提示（同钱包）。
  Future<void> _doSubscribe(BillingPlan plan, String method) async {
    AppLoading.show(status: t.main.payingDots);
    final ok = await ref
        .read(billingProvider.notifier)
        .subscribePlan(plan, paymentMethod: method);
    AppLoading.dismiss();
    if (!mounted) return;
    if (ok) {
      AppLoading.showSuccess(t.billing.paySuccess);
      return;
    }
    switch (ref.read(billingProvider).lastLaunchResult) {
      case PaymentLaunchResult.notConfigured:
        AppLoading.showToast(t.billing.payMethodComingSoon);
      case PaymentLaunchResult.cancelled:
        AppLoading.showToast(t.billing.payCancelled);
      case PaymentLaunchResult.failed:
      case PaymentLaunchResult.success:
      case null:
        AppLoading.showError(t.billing.payFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.billing.title,
      useLargeTitle: false,
      backgroundColor: isDark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => Future.wait([
            ref.read(billingProvider.notifier).loadPlans(),
            ref.read(billingProvider.notifier).loadSubscription(),
          ]),
        ),
        SliverToBoxAdapter(child: _buildBody(context, state, isDark)),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.large)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, BillingState state, bool isDark) {
    if (state.isLoading && state.plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxxLarge),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (state.error != null && state.plans.isEmpty) {
      return _buildErrorView(context);
    }
    if (state.plans.isEmpty) {
      return _buildEmptyView(context, isDark);
    }
    return Column(
      children: [
        for (final plan in state.plans)
          _buildPlanCard(context, plan, state, isDark),
      ],
    );
  }

  /// 错误态：文案 + 重试按钮（也支持下拉刷新）。
  Widget _buildErrorView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxxLarge),
          Text(
            t.billing.loadFailed,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalRegular,
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            onPressed: () => ref.read(billingProvider.notifier).loadPlans(),
            child: Text(t.billing.retry),
          ),
        ],
      ),
    );
  }

  /// 空态。
  Widget _buildEmptyView(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxxLarge),
          Icon(
            CupertinoIcons.rosette,
            size: 48,
            color: AppColors.iosGray.withValues(alpha: 0.6),
          ),
          AppSpacing.verticalRegular,
          Text(
            t.billing.noPlans,
            style: context.textStyle(
              FontSizeType.footnote,
              color: isDark ? AppColors.darkTextSecondary : AppColors.iosGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 套餐卡片：名称/当前套餐标记、价格（分→元）+ 周期、配额、描述、订阅按钮。
  Widget _buildPlanCard(
    BuildContext context,
    BillingPlan plan,
    BillingState state,
    bool isDark,
  ) {
    final isCurrent = state.subscription?.planId == plan.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Container(
        padding: AppSpacing.allRegular,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder(isCurrent), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(context, plan, isCurrent, isDark),
            AppSpacing.verticalSmall,
            _buildPriceRow(context, plan, isDark),
            if (plan.quotaConfig.isNotEmpty) ...[
              AppSpacing.verticalSmall,
              _buildQuotaText(context, isDark, plan.quotaConfig),
            ],
            if (plan.description.isNotEmpty) ...[
              AppSpacing.verticalSmall,
              Text(
                plan.description,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
            AppSpacing.verticalMedium,
            _buildSubscribeButton(context, plan, state, isCurrent),
          ],
        ),
      ),
    );
  }

  Color _cardBorder(bool isCurrent) => isCurrent
      ? AppColors.primary.withValues(alpha: 0.6)
      : AppColors.iosGray.withValues(alpha: 0.2);

  Widget _buildCardHeader(
    BuildContext context,
    BillingPlan plan,
    bool isCurrent,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            plan.name,
            style: context.textStyle(
              FontSizeType.large,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.small,
              vertical: AppSpacing.tiny,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.small),
            ),
            child: Text(
              t.billing.currentPlan,
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// 价格行：¥xx.xx + 周期（月付/年付）。
  Widget _buildPriceRow(BuildContext context, BillingPlan plan, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '¥${plan.priceYuan.toStringAsFixed(2)}',
          style: context
              .textStyle(
                FontSizeType.title,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              )
              .copyWith(letterSpacing: -0.5),
        ),
        AppSpacing.horizontalSmall,
        Text(
          plan.isYearly
              ? t.billing.planPeriodYearly
              : t.billing.planPeriodMonthly,
          style: context.textStyle(
            FontSizeType.footnote,
            color: isDark ? AppColors.darkTextSecondary : AppColors.iosGray,
          ),
        ),
      ],
    );
  }

  /// 配额行：后端 quota_config 逐项渲染，-1 = 不限。
  Widget _buildQuotaText(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> quotaConfig,
  ) {
    final parts = quotaConfig.entries.map((e) {
      final limit = e.value is num ? (e.value as num).toInt() : null;
      final value = (limit == null || limit < 0)
          ? t.billing.quotaUnlimited
          : '$limit';
      return '${e.key} $value';
    });
    return Text(
      parts.join(' · '),
      style: context.textStyle(
        FontSizeType.footnote,
        color: isDark ? AppColors.darkTextSecondary : AppColors.iosGray,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubscribeButton(
    BuildContext context,
    BillingPlan plan,
    BillingState state,
    bool isCurrent,
  ) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.5)
            : AppColors.primary,
        disabledColor: AppColors.primary.withValues(alpha: 0.4),
        onPressed: state.paying ? null : () => _showPayMethodSheet(plan),
        child: state.paying
            ? const CupertinoActivityIndicator(color: AppColors.onPrimary)
            : Text(
                t.billing.subscribe,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
              ),
      ),
    );
  }
}
