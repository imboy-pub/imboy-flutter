import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'channel_order_status_ui.dart';
import 'channel_purchase_provider.dart' show channelOrderApiProvider;

/// 付费频道「我的订单」数据源。
///
/// 复用 [channelOrderApiProvider]（与购买编排同一注入点，便于测试覆盖）。
/// 后端 `/api/v1/channel/orders/my` 返回 `{list: [...]}`，封顶 50 条、无分页。
final channelMyOrdersProvider =
    FutureProvider.autoDispose<List<ChannelOrderModel>>((ref) async {
      final api = ref.watch(channelOrderApiProvider);
      final payload = await api.myOrders();
      final raw = payload?['list'];
      if (raw is! List) return const <ChannelOrderModel>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => ChannelOrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });

/// 付费频道订单历史页。只读列表 + 下拉刷新。
class ChannelOrderListPage extends ConsumerWidget {
  const ChannelOrderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final async = ref.watch(channelMyOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.getBackgroundColor(brightness),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          t.channel.myOrders,
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
          onTop: () => ref.invalidate(channelMyOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return NoDataView(
              text: t.channel.noOrders,
              icon: Icons.receipt_long_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(channelMyOrdersProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: orders.length,
              separatorBuilder: (_, _) => AppSpacing.verticalTiny,
              itemBuilder: (context, i) => _OrderTile(order: orders[i]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final ChannelOrderModel order;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final (label, color) = channelOrderStatusStyle(order.status, t);
    final title = (order.channelName == null || order.channelName!.isEmpty)
        ? '#${order.channelId}'
        : order.channelName!;

    return GestureDetector(
      onTap: () => context.push('/channel/order/${order.orderNo}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(brightness),
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_outlined,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextColor(brightness),
                    ),
                  ),
                  AppSpacing.verticalTiny,
                  Text(
                    _subtitle(t),
                    style: context.textStyle(
                      FontSizeType.small,
                      color: AppColors.slateText,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.horizontalSmall,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${order.amount.toStringAsFixed(2)}',
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextColor(brightness),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: context.textStyle(
                      FontSizeType.caption2,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Translations t) {
    // ponytail: DateTime.toString() 取日期段即可，无需引入 intl。
    final created = order.createdAt.toString().split(' ').first;
    final end = order.subscriptionEndAt;
    if (end == null) return created;
    return '$created · ${t.channel.orderValidUntil} '
        '${end.toString().split(' ').first}';
  }
}
