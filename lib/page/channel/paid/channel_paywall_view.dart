import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_payment_method_sheet.dart';
import 'package:imboy/page/channel/channel_purchase_provider.dart';
import 'package:imboy/service/payment_launcher.dart' show PaymentLaunchResult;
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/channel_service.dart';

/// 付费频道锁定视图
///
/// 从详情页 [_buildPaidLockedView] + 支付编排逻辑（~390 行）抽出。
/// 对标公众号付费阅读：封面模糊 + 试读引导 + 解锁入口 + 我的订单。
class ChannelPaywallView extends ConsumerStatefulWidget {
  final ChannelModel channel;

  /// 支付成功后回调（详情页刷新数据）
  final VoidCallback? onPurchased;

  const ChannelPaywallView({
    super.key,
    required this.channel,
    this.onPurchased,
  });

  @override
  ConsumerState<ChannelPaywallView> createState() => _ChannelPaywallViewState();
}

class _ChannelPaywallViewState extends ConsumerState<ChannelPaywallView> {
  bool _isPaying = false;
  final ChannelService _channelService = ChannelService.to;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final channel = widget.channel;

    return Center(
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: AppSpacing.allLarge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(
              color: AppColors.iosYellow.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 锁定图标 + 标题
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.iosYellow),
                  AppSpacing.horizontalSmall,
                  Expanded(
                    child: Text(
                      t.discovery.paidChannelLocked,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.main.purchaseUnlockHint,
                style: context.textStyle(FontSizeType.normal),
              ),
              // 价格展示
              if (channel.hasPrice) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          t.main.channelPriceLabel(
                            currency: channel.currency,
                            amount: channel.priceYuan.toStringAsFixed(2),
                          ),
                          style: context.textStyle(
                            FontSizeType.subheadline,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isPaying ? null : () => _buyAndUnlock(),
                      icon: _isPaying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_cart_checkout_outlined),
                      label: Text(
                        _isPaying
                            ? t.main.payingDots
                            : t.main.purchaseAndUnlock,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showMyOrdersSheet(),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(t.main.myOrders),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 支付编排（从详情页原样迁移）----

  Future<void> _buyAndUnlock() async {
    if (_isPaying) return;
    final channel = widget.channel;
    final channelId = channel.id.toString();

    int? balanceFen;
    if (channel.hasPrice) {
      final balance = await WalletApi().getBalance();
      if (!mounted) return;
      balanceFen = balance?.balance;
    }
    final balanceText = balanceFen == null
        ? null
        : '¥${(balanceFen / 100.0).toStringAsFixed(2)}';

    final method = await showChannelPaymentMethodSheet(
      context,
      walletBalanceText: balanceText,
    );
    if (method == null || !mounted) return;

    if (method != 'wallet') {
      await _payWithThirdParty(channelId, method);
      return;
    }

    if (channel.hasPrice && balanceFen != null && balanceFen < channel.price) {
      await _showInsufficientBalanceDialog(channel, balanceFen);
      return;
    }

    await _payWithWallet(channelId);
  }

  Future<void> _payWithThirdParty(String channelId, String method) async {
    setState(() => _isPaying = true);
    final notifier = ref.read(channelPurchaseProvider.notifier);
    try {
      final order = await notifier.purchase(channelId, paymentMethod: method);
      if (!mounted) return;

      if (order == null) {
        final result = ref.read(channelPurchaseProvider).lastLaunchResult;
        _handleThirdPartyFailure(result);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.common.purchaseSuccess)));
      await _onPurchaseSuccess(channelId);
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _payWithWallet(String channelId) async {
    setState(() => _isPaying = true);
    try {
      final order = await ref
          .read(channelPurchaseProvider.notifier)
          .purchase(channelId, paymentMethod: 'wallet');
      if (!mounted) return;

      if (order == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.common.purchaseFailed)),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.common.purchaseSuccess)));
      await _onPurchaseSuccess(channelId);
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _onPurchaseSuccess(String channelId) async {
    await ref.read(channelListProvider.notifier).loadSubscribedChannels();
    await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
    widget.onPurchased?.call();
  }

  void _handleThirdPartyFailure(PaymentLaunchResult? result) {
    switch (result) {
      case PaymentLaunchResult.notConfigured:
        AppLoading.showToast(context.t.account.payMethodComingSoon);
      case PaymentLaunchResult.cancelled:
        AppLoading.showToast(context.t.account.payCancelled);
      case PaymentLaunchResult.failed:
      case PaymentLaunchResult.success:
      case null:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.common.purchaseFailed)),
        );
    }
  }

  Future<void> _showInsufficientBalanceDialog(
    ChannelModel channel,
    int balanceFen,
  ) async {
    final t = context.t;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.common.insufficientBalanceTitle),
        content: Text(
          t.common.insufficientBalanceContent(
            balance: (balanceFen / 100.0).toStringAsFixed(2),
            price: channel.priceYuan.toStringAsFixed(2),
            currency: channel.currency,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/wallet');
            },
            child: Text(t.common.goRecharge),
          ),
        ],
      ),
    );
  }

  // ---- 订单列表 sheet ----

  Future<void> _showMyOrdersSheet() async {
    final t = context.t;
    final channelId = widget.channel.id.toString();
    final allOrders = await _channelService.getMyOrders();
    if (!mounted) return;

    final orders = allOrders
        .where((o) => o.channelId.toString() == channelId)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child: Column(
            children: [
              AppSpacing.verticalMedium,
              Text(
                t.main.myOrders,
                style: context.textStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppSpacing.verticalSmall,
              Expanded(
                child: orders.isEmpty
                    ? Center(child: Text(t.common.noOrders))
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return ListTile(
                            title: Text(order.orderNo),
                            subtitle: Text(
                              '${order.currency} ${order.amount.toStringAsFixed(2)} · '
                              '${DateTimeHelper.dateTimeFmt(order.createdAt, pattern: 'yyyy-MM-dd HH:mm', relative: false)}',
                            ),
                            trailing: Text(
                              _orderStatusLabel(order.status),
                              style: TextStyle(
                                color: _orderStatusColor(order.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _showOrderDetail(order.orderNo),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOrderDetail(String orderNo) async {
    final t = context.t;
    final order = await _channelService.getOrder(orderNo);
    if (!mounted) return;

    if (order == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.orderDetailLoadFailed)));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.main.orderDetail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.orderNoLabel(no: order.orderNo)),
            const SizedBox(height: 6),
            Text(
              t.chat.orderStatusLabel(status: _orderStatusLabel(order.status)),
            ),
            const SizedBox(height: 6),
            Text(
              t.main.orderAmountLabel(
                currency: order.currency,
                amount: order.amount.toStringAsFixed(2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.chat.orderCreatedAtLabel(
                time: DateTimeHelper.dateTimeFmt(
                  order.createdAt,
                  pattern: 'yyyy-MM-dd HH:mm:ss',
                  relative: false,
                ),
              ),
            ),
            if (order.paymentAt != null) ...[
              const SizedBox(height: 6),
              Text(
                t.chat.orderPaymentAtLabel(
                  time: DateTimeHelper.dateTimeFmt(
                    order.paymentAt!,
                    pattern: 'yyyy-MM-dd HH:mm:ss',
                    relative: false,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  String _orderStatusLabel(int status) {
    final t = context.t;
    switch (status) {
      case ChannelOrderStatus.pending:
        return t.chat.orderStatusPending;
      case ChannelOrderStatus.paid:
        return t.chat.orderStatusPaid;
      case ChannelOrderStatus.refunded:
        return t.chat.orderStatusRefunded;
      case ChannelOrderStatus.cancelled:
        return t.common.orderStatusCancelled;
      case ChannelOrderStatus.expired:
        return t.chat.orderStatusExpired;
      default:
        return t.common.orderStatusUnknown;
    }
  }

  Color _orderStatusColor(int status) {
    switch (status) {
      case ChannelOrderStatus.paid:
        return AppColors.iosGreen;
      case ChannelOrderStatus.pending:
        return AppColors.iosOrange;
      case ChannelOrderStatus.refunded:
      case ChannelOrderStatus.cancelled:
      case ChannelOrderStatus.expired:
        return AppColors.iosGray;
      default:
        return AppColors.iosGray;
    }
  }
}
