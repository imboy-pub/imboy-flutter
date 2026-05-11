import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/ui/common_bar.dart';
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

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.title,
        automaticallyImplyLeading: true,

        rightDMActions: [
          // 朋友圈已升级为独立"广场"Tab，此处快捷入口移除
          if (AppFeatureRegistry.isEnabled('channel_invitation'))
            IconButton(
              icon: const Icon(Icons.mark_email_unread_outlined),
              onPressed: () {
                context.push('/channel/invitations');
              },
              tooltip: t.channelInvitations,
            ),
          if (AppFeatureRegistry.isEnabled('channel_discover'))
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                context.push('/channel/discover');
              },
              tooltip: t.channel.search,
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/channel/create');
            },
            tooltip: t.channel.create,
          ),
        ],
      ),
      body: Column(
        children: [
          // TabBar 嵌入到 body 中
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: t.channel.subscribed),
                Tab(text: t.channel.managed),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final notifier = ref.read(channelListProvider.notifier);
                if (isSubscribed) {
                  notifier.loadSubscribedChannels();
                } else {
                  notifier.loadManagedChannels();
                }
              },
              child: Text(context.t.buttonRetry),
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
        return Colors.orange;
      case ChannelUserRole.editor:
        return Colors.blue;
      case ChannelUserRole.subscriber:
      case ChannelUserRole.none:
        return Colors.grey;
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

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        backgroundImage: channel.avatar != null && channel.avatar!.isNotEmpty
            ? cachedImageProvider(channel.avatar!, w: 96)
            : null,
        child: channel.avatar == null || channel.avatar!.isEmpty
            ? const Icon(Icons.campaign, size: 24)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              channel.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
                border: Border.all(
                  color: _getRoleColor(channel.userRole).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                _getRoleLabel(channel.userRole, t),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getRoleColor(channel.userRole),
                ),
              ),
            ),
          ],
          if (channel.isVerified)
            Container(
              margin: const EdgeInsets.only(left: 4),
              child: const Icon(
                Icons.verified,
                size: 16,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${channel.subscriberCount} ${t.channel.subscribers}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          if (channel.tags != null && channel.tags!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                channel.tags!.take(2).join(' · '),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.push('/channel/${_detailRouteId(channel)}');
      },
    );
  }
}
