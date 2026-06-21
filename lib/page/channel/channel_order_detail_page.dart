import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'channel_order_list_page.dart' show channelMyOrdersProvider;
import 'channel_order_status_ui.dart';
import 'channel_purchase_provider.dart' show channelOrderApiProvider;

/// 订单详情数据源（按订单号查询，复用 [channelOrderApiProvider]）。
final channelOrderDetailProvider = FutureProvider.autoDispose
    .family<ChannelOrderModel?, String>((ref, orderNo) async {
      final api = ref.watch(channelOrderApiProvider);
      return api.getOrder(orderNo);
    });

/// 退款编排。`state` 即 isRefunding 标志，进行中重复调用直接返回 false。
class ChannelRefundNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 申请退款；仅已支付订单后端会受理。返回是否受理成功。
  Future<bool> refund(String orderNo, {String? reason}) async {
    if (state) return false;
    state = true;
    try {
      return await ref
          .read(channelOrderApiProvider)
          .refundOrder(orderNo, reason: reason);
    } finally {
      state = false;
    }
  }
}

final channelRefundProvider = NotifierProvider<ChannelRefundNotifier, bool>(
  ChannelRefundNotifier.new,
);

/// 付费频道订单详情页。展示订单全字段；已支付订单提供退款入口。
class ChannelOrderDetailPage extends ConsumerWidget {
  const ChannelOrderDetailPage({super.key, required this.orderNo});

  final String orderNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final async = ref.watch(channelOrderDetailProvider(orderNo));

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.getBackgroundColor(brightness),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          t.channel.orderDetail,
          style: context.textStyle(
            FontSizeType.extraLarge,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextColor(brightness),
          ),
        ),
      ),
      body: async.when(
        loading: () => const ShimmerList(),
        error: (_, _) => NoDataView(
          text: t.channel.noOrders,
          icon: Icons.receipt_long_outlined,
          onTop: () => ref.invalidate(channelOrderDetailProvider(orderNo)),
        ),
        data: (order) {
          if (order == null) {
            return NoDataView(
              text: t.channel.noOrders,
              icon: Icons.receipt_long_outlined,
            );
          }
          return _OrderDetailBody(order: order);
        },
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order});

  final ChannelOrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final (statusLabel, statusColor) = channelOrderStatusStyle(order.status, t);
    final isRefunding = ref.watch(channelRefundProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(brightness),
            borderRadius: AppRadius.card,
          ),
          child: Column(
            children: [
              _row(context, t.channel.orderNo, order.orderNo),
              _row(context, t.channel.orderChannel, _channelName()),
              _row(
                context,
                t.channel.orderAmount,
                '¥${order.amount.toStringAsFixed(2)}',
              ),
              _statusRow(context, t, statusLabel, statusColor),
              _row(
                context,
                t.channel.orderPaymentMethod,
                _payLabel(order.paymentMethod, t),
              ),
              _row(context, t.channel.orderCreatedAt, _date(order.createdAt)),
              if (order.paymentAt != null)
                _row(context, t.channel.orderPaidAt, _date(order.paymentAt)),
              if (order.subscriptionStartAt != null &&
                  order.subscriptionEndAt != null)
                _row(
                  context,
                  t.channel.orderSubscriptionPeriod,
                  '${_date(order.subscriptionStartAt)} ~ '
                  '${_date(order.subscriptionEndAt)}',
                ),
            ],
          ),
        ),
        if (order.status == ChannelOrderStatus.paid) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.iosRed,
                side: const BorderSide(color: AppColors.iosRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: isRefunding ? null : () => _onRefund(context, ref),
              child: Text(t.channel.refundApply),
            ),
          ),
        ],
      ],
    );
  }

  String _channelName() =>
      (order.channelName == null || order.channelName!.isEmpty)
      ? '#${order.channelId}'
      : order.channelName!;

  // ponytail: DateTime.toString() 取日期段即可，无需引入 intl。
  String _date(DateTime? d) => d == null ? '-' : d.toString().split(' ').first;

  String _payLabel(String method, Translations t) => switch (method) {
    'wallet' => t.channel.payWallet,
    'alipay' => t.channel.payAlipay,
    'wechat' => t.channel.payWechat,
    _ => method,
  };

  Future<void> _onRefund(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.channel.refundConfirmTitle),
        content: Text(t.channel.refundConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(channelRefundProvider.notifier)
        .refund(order.orderNo);
    if (!context.mounted) return;
    if (ok) {
      EasyLoading.showSuccess(t.channel.refundSuccess);
      ref.invalidate(channelOrderDetailProvider(order.orderNo));
      ref.invalidate(channelMyOrdersProvider);
    }
    // 失败提示已由 ChannelOrderApi.refundOrder 统一弹出。
  }

  Widget _row(BuildContext context, String label, String value) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.slateText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.getTextColor(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    BuildContext context,
    Translations t,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              t.channel.orderStatusLabel,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.slateText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: context.textStyle(
                FontSizeType.small,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
