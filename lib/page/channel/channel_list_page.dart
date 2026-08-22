import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:imboy/component/ui/ios_settings_ui.dart';

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
    setState(() {}); // 同步重绘，支持滑动和位移
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(channelListProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.channel.title,
      actions: [
        if (AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover))
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.search, size: 22),
            onPressed: () {
              context.push('/channel/discover');
            },
          ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add, size: 22),
          onPressed: () {
            context.push('/channel/create');
          },
        ),
        ..._buildOverflowMenu(t, brightness),
        AppSpacing.horizontalSmall,
      ],
      body: Column(
        children: [
          // 行业顶级精品：悬浮胶囊卡片分段选择器 (Floating Pill TabBar)
          Container(
            width: double.infinity,
            color: AppColors.getSurfaceGrouped(
              brightness,
            ), // 使用大底座灰色背景，与 AppBar 的纯白色形成完美的立体分层
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark
                      ? AppColors
                            .darkSurfaceGroupedTertiary // 悬浮框深色：高级碳灰
                      : AppColors.lightSurface, // 悬浮框浅色：洁白卡片
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.getIosSeparator(
                      brightness,
                    ).withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brightness == Brightness.dark
                          ? AppColors.lightTextPrimary.withValues(alpha: 0.3)
                          : AppColors.lightTextPrimary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary, // 选中项采用高对比度的主色蓝，彰显尊贵品牌基因
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.onPrimary, // 选中文字纯白，保证最严苛的对比度与可读性
                  unselectedLabelColor: AppColors.getTextColor(
                    brightness,
                    isSecondary: true,
                  ),
                  labelStyle: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w500,
                  ),
                  dividerColor: AppColors.transparent,
                  splashBorderRadius: BorderRadius.circular(20),
                  tabs: [
                    Tab(height: 36, child: Text(t.channel.subscribed)),
                    Tab(height: 36, child: Text(t.channel.managed)),
                  ],
                ),
              ),
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

  /// 「订单/邀请」低频入口收进 more_vert 溢出菜单；flag 全关时不渲染。
  List<Widget> _buildOverflowMenu(Translations t, Brightness brightness) {
    final items = <PopupMenuItem<String>>[
      if (AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder))
        PopupMenuItem(
          value: '/channel/orders',
          child: ListTile(
            leading: const Icon(CupertinoIcons.doc_plaintext),
            title: Text(t.channel.myOrders),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation))
        PopupMenuItem(
          value: '/channel/invitations',
          child: ListTile(
            leading: const Icon(CupertinoIcons.envelope_badge),
            title: Text(t.common.channelInvitations),
            contentPadding: EdgeInsets.zero,
          ),
        ),
    ];
    if (items.isEmpty) return const [];
    return [
      Material(
        color: Colors.transparent,
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          iconColor: AppColors.getTextColor(brightness),
          onSelected: (route) => context.push(route),
          itemBuilder: (context) => items,
        ),
      ),
    ];
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
      // 失败态与空态统一走 NoDataView：此前手写 Text + Material ElevatedButton，
      // 与同函数下方的 NoDataView 空态视觉割裂（无图标、按钮风格不一致）。
      return NoDataView(
        icon: Icons.error_outline,
        text: state.error!,
        onTop: () {
          final notifier = ref.read(channelListProvider.notifier);
          if (isSubscribed) {
            notifier.loadSubscribedChannels();
          } else {
            notifier.loadManagedChannels();
          }
        },
      );
    }

    if (state.channels.isEmpty) {
      // 已订阅空态提供"发现频道"跳转入口（引导语可点击）
      return NoDataView(
        icon: Icons.campaign_outlined,
        text: isSubscribed
            ? context.t.channel.noSubscribedChannels
            : context.t.channel.noManagedChannels,
        onTop: isSubscribed ? () => context.push('/channel/discover') : null,
        retryLabel: isSubscribed ? context.t.channel.discover : null,
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
        child: ListView.separated(
          itemCount:
              state.channels.length + (isSubscribed && state.hasMore ? 1 : 0),
          separatorBuilder: (context, index) {
            if (isSubscribed && index >= state.channels.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(left: 80),
              child: Divider(
                height: 0.5,
                color: AppColors.getIosSeparator(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.3),
              ),
            );
          },
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

  /// 频道头像。
  ///
  /// 原实现用 `CircleAvatar.backgroundImage`，只在「没有 URL」时才渲染兜底
  /// 图标；有 URL 但加载失败（授权过期 / 对象不存在 / 断网）时 CircleAvatar
  /// 只剩背景色，表现为一个完全空白的圆。改用 Image + errorBuilder，
  /// 让「加载失败」和「没有 URL」走同一个兜底图标。
  Widget _buildAvatar() {
    const double size = 48;
    const Widget fallback = Center(
      child: Icon(Icons.campaign, size: 24, color: AppColors.primary),
    );
    final String url = channel.avatar ?? '';
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.primaryAlpha10,
        child: url.isEmpty
            ? fallback
            : Image(
                // 必须走 cachedImageProvider（内部已重新授权），
                // 禁止直接 Image.network。
                image: cachedImageProvider(url, w: 96),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final itemBgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return ColoredBox(
      color: itemBgColor,
      child: FlatListTile(
        onTap: () {
          context.push('/channel/${_detailRouteId(channel)}');
        },
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _buildAvatar(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                channel.name,
                style: context.textStyle(
                  FontSizeType.medium,
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
                  style: context.textStyle(
                    FontSizeType.tiny,
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
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.getTextColor(brightness, isSecondary: true),
              ),
            ),
            if (channel.tags != null && channel.tags!.isNotEmpty) ...[
              AppSpacing.horizontalSmall,
              Expanded(
                child: Text(
                  channel.tags!.take(2).join(' · '),
                  style: context.textStyle(
                    FontSizeType.small,
                    color: AppColors.getTextColor(
                      brightness,
                      isSecondary: true,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          size: 16,
          color: AppColors.iosGray,
        ),
      ),
    );
  }
}
