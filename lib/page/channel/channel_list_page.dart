import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'channel_provider.dart';

/// 频道列表页面
///
/// 显示用户订阅的频道和管理中的频道
class ChannelListPage extends ConsumerStatefulWidget {
  const ChannelListPage({super.key});

  @override
  ConsumerState<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends ConsumerState<ChannelListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 加载数据
    Future.microtask(() {
      ref.read(channelListProvider.notifier).loadSubscribedChannels();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    final notifier = ref.read(channelListProvider.notifier);
    if (_tabController.index == 0) {
      notifier.loadSubscribedChannels();
    } else {
      notifier.loadManagedChannels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(channelListProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.getBackgroundColor(brightness),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          t.channel.title,
          style: TextStyle(
            fontSize: FontSizeType.extraLarge.size,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextColor(brightness),
          ),
        ),
        actions: [
          if (AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder))
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {
                context.push('/channel/orders');
              },
              tooltip: t.channel.myOrders,
              color: AppColors.getTextColor(brightness),
            ),
          if (AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation))
            IconButton(
              icon: const Icon(Icons.mark_email_unread_outlined),
              onPressed: () {
                context.push('/channel/invitations');
              },
              tooltip: t.common.channelInvitations,
              color: AppColors.getTextColor(brightness),
            ),
          if (AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover))
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                context.push('/channel/discover');
              },
              tooltip: t.channel.search,
              color: AppColors.getTextColor(brightness),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/channel/create');
            },
            tooltip: t.channel.create,
            color: AppColors.getTextColor(brightness),
          ),
          AppSpacing.horizontalSmall,
        ],
      ),
      body: Column(
        children: [
          // TabBar 极简风格
          Container(
            color: AppColors.getBackgroundColor(brightness),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: t.channel.subscribed),
                Tab(text: t.channel.managed),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.getTextColor(
                brightness,
                isSecondary: true,
              ),
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
            ),
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChannelList(state, isSubscribed: true, showRole: false),
                _buildChannelList(state, isSubscribed: false, showRole: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(
    ChannelListState state, {
    required bool isSubscribed,
    bool showRole = false,
  }) {
    if (state.isLoading) {
      return const ShimmerList(itemCount: 6);
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error!),
            AppSpacing.verticalRegular,
            ElevatedButton(
              onPressed: () {
                final notifier = ref.read(channelListProvider.notifier);
                if (isSubscribed) {
                  notifier.loadSubscribedChannels();
                } else {
                  notifier.loadManagedChannels();
                }
              },
              child: Text(context.t.common.buttonRetry),
            ),
          ],
        ),
      );
    }

    if (state.channels.isEmpty) {
      return NoDataView(
        icon: Icons.campaign_outlined,
        text: isSubscribed
            ? context.t.channel.noSubscribedChannels
            : context.t.channel.noManagedChannels,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final notifier = ref.read(channelListProvider.notifier);
        if (isSubscribed) {
          await notifier.loadSubscribedChannels();
        } else {
          await notifier.loadManagedChannels();
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!isSubscribed) return false;
          if (notification.metrics.pixels <
              notification.metrics.maxScrollExtent - 200) {
            return false;
          }
          ref.read(channelListProvider.notifier).loadMoreSubscribedChannels();
          return false;
        },
        child: ListView.builder(
          itemCount:
              state.channels.length + (isSubscribed && state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (isSubscribed && index >= state.channels.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final channel = state.channels[index];
            return _ChannelListItem(channel: channel, showRole: showRole);
          },
        ),
      ),
    );
  }
}

/// 频道列表项
class _ChannelListItem extends StatelessWidget {
  final ChannelModel channel;
  final bool showRole;

  const _ChannelListItem({required this.channel, this.showRole = false});

  String _detailRouteId(ChannelModel channel) {
    final customId = channel.customId?.trim() ?? '';
    if (customId.isNotEmpty) return customId;
    return channel.id.toString();
  }

  /// 获取角色颜色
  Color _getRoleColor(ChannelUserRole role) {
    switch (role) {
      case ChannelUserRole.creator:
        return AppColors.primary;
      case ChannelUserRole.admin:
        return AppColors.iosOrange;
      case ChannelUserRole.editor:
        return AppColors.iosBlue;
      case ChannelUserRole.subscriber:
      case ChannelUserRole.none:
        return AppColors.iosGray;
    }
  }

  /// 获取角色标签文本
  String _getRoleLabel(ChannelUserRole role, dynamic t) {
    switch (role) {
      case ChannelUserRole.creator:
        return t.channel.roleCreator as String;
      case ChannelUserRole.admin:
        return t.channel.roleAdmin as String;
      case ChannelUserRole.editor:
        return t.channel.roleEditor as String;
      case ChannelUserRole.subscriber:
      case ChannelUserRole.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;

    return FlatListTile(
      onTap: () {
        context.push('/channel/${_detailRouteId(channel)}');
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryAlpha10,
        backgroundImage: channel.avatar != null && channel.avatar!.isNotEmpty
            ? cachedImageProvider(channel.avatar!, w: 96)
            : null,
        child: channel.avatar == null || channel.avatar!.isEmpty
            ? const Icon(Icons.campaign, size: 24, color: AppColors.primary)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              channel.name,
              style: TextStyle(
                fontSize: FontSizeType.medium.size,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextColor(brightness),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 角色标签（仅"我管理的"标签页显示）
          if (showRole && channel.userRole != ChannelUserRole.none) ...[
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(channel.userRole).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusTiny,
              ),
              child: Text(
                _getRoleLabel(channel.userRole, t),
                style: TextStyle(
                  fontSize: FontSizeType.tiny.size,
                  fontWeight: FontWeight.w600,
                  color: _getRoleColor(channel.userRole),
                ),
              ),
            ),
          ],
          if (channel.isVerified)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified, size: 16, color: AppColors.primary),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            Icons.people_outline,
            size: 14,
            color: AppColors.getTextColor(brightness, isSecondary: true),
          ),
          AppSpacing.horizontalTiny,
          Text(
            '${channel.subscriberCount} ${t.channel.subscribers}',
            style: TextStyle(
              color: AppColors.getTextColor(brightness, isSecondary: true),
              fontSize: FontSizeType.small.size,
            ),
          ),
          if (channel.tags != null && channel.tags!.isNotEmpty) ...[
            AppSpacing.horizontalSmall,
            Expanded(
              child: Text(
                channel.tags!.take(2).join(' · '),
                style: TextStyle(
                  color: AppColors.getTextColor(brightness, isSecondary: true),
                  fontSize: FontSizeType.small.size,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 16,
        color: AppColors.iosGray,
      ),
    );
  }
}
