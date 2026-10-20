import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
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
import 'channel_list_previews.dart';

import 'package:imboy/store/model/channel_message_model.dart';

import 'widgets/channel_role_badge.dart';

import 'package:imboy/modules/organization/presentation/current_space_tile.dart';

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
  String _query = '';
  bool _searchOpen = false;

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
    ref.watch(featureRevisionProvider);
    final t = context.t;
    final state = ref.watch(channelListProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.channel.title,
      middle: CurrentSpaceTile(heading: t.channel.title),
      actions: [..._buildOverflowMenu(t), AppSpacing.horizontalSmall],
      body: Column(
        children: [
          if (_searchOpen || _query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: CupertinoSearchTextField(
                key: const Key('channel-list-search'),
                placeholder: t.channel.searchHint,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.small,
              AppSpacing.regular,
              AppSpacing.tiny,
            ),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tabController.index,
                thumbColor: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(AppSpacing.tiny),
                children: {
                  0: SizedBox(
                    height: AppSpacing.xxxLarge,
                    child: Center(
                      child: Text(
                        t.channel.subscribed,
                        style: context.textStyle(
                          FontSizeType.normal,
                          fontWeight: _tabController.index == 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _tabController.index == 0
                              ? AppColors.getIosBlue(brightness)
                              : AppColors.getTextColor(
                                  brightness,
                                  isSecondary: true,
                                ),
                        ),
                      ),
                    ),
                  ),
                  1: SizedBox(
                    height: AppSpacing.xxxLarge,
                    child: Center(
                      child: Text(
                        t.channel.managed,
                        style: context.textStyle(
                          FontSizeType.normal,
                          fontWeight: _tabController.index == 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _tabController.index == 1
                              ? AppColors.getIosBlue(brightness)
                              : AppColors.getTextColor(
                                  brightness,
                                  isSecondary: true,
                                ),
                        ),
                      ),
                    ),
                  ),
                },
                onValueChanged: (index) {
                  if (index != null && index != _tabController.index) {
                    _tabController.animateTo(index);
                  }
                },
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
  List<Widget> _buildOverflowMenu(Translations t) {
    final items = <PopupMenuItem<String>>[
      PopupMenuItem(value: 'search', child: Text(t.common.search)),
      PopupMenuItem(value: '/channel/create', child: Text(t.channel.create)),
      if (AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover))
        PopupMenuItem(
          value: '/channel/discover',
          child: Text(t.channel.discover),
        ),
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
          child: SizedBox.square(
            dimension: AppSpacing.xxxLarge,
            child: Icon(
              CupertinoIcons.add,
              color: AppColors.getIosBlue(Theme.of(context).brightness),
              semanticLabel: t.channel.create,
            ),
          ),
          onSelected: (route) {
            if (route == 'search') {
              setState(() => _searchOpen = !_searchOpen);
            } else {
              context.push(route);
            }
          },
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
    final channels = state.channels
        .where(
          (channel) =>
              channel.name.toLowerCase().contains(_query) ||
              channel.id.toString().contains(_query) ||
              (channel.customId ?? '').toLowerCase().contains(_query),
        )
        .toList(growable: false);
    final canLoadMore = isSubscribed && state.hasMore && _query.isEmpty;
    final previews = ref.watch(channelListPreviewsProvider).asData?.value;
    if (state.isLoading) {
      return const ShimmerList(itemCount: 6);
    }

    if (state.error != null) {
      // 失败态与空态统一走 NoDataView：此前手写 Text + Material ElevatedButton，
      // 与同函数下方的 NoDataView 空态视觉割裂（无图标、按钮风格不一致）。
      return NoDataView(
        icon: CupertinoIcons.exclamationmark_circle,
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
        icon: CupertinoIcons.speaker_2,
        text: isSubscribed
            ? context.t.channel.noSubscribedChannels
            : context.t.channel.noManagedChannels,
        onTop: isSubscribed ? () => context.push('/channel/discover') : null,
        retryLabel: isSubscribed ? context.t.channel.discover : null,
      );
    }

    if (channels.isEmpty) return NoDataView(text: context.t.channel.noResults);
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
          if (!canLoadMore) return false;
          if (notification.metrics.pixels <
              notification.metrics.maxScrollExtent - 200) {
            return false;
          }
          ref.read(channelListProvider.notifier).loadMoreSubscribedChannels();
          return false;
        },
        child: ListView.separated(
          itemCount: channels.length + (canLoadMore ? 1 : 0),
          separatorBuilder: (context, index) {
            if (isSubscribed && index >= channels.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(left: 80),
              child: Divider(
                height: 0.5,
                color: AppColors.getIosSeparator(Theme.of(context).brightness)
                    .withValues(alpha: 0.3),
              ),
            );
          },
          itemBuilder: (context, index) {
            if (isSubscribed && index >= channels.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CupertinoActivityIndicator(),
                  ),
                ),
              );
            }

            final channel = channels[index];
            final preview = previews?[channel.id];
            return _ChannelListItem(
              channel: channel,
              showRole: showRole,
              preview: preview,
            );
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
  final ChannelMessageModel? preview;

  const _ChannelListItem({
    required this.channel,
    this.showRole = false,
    this.preview,
  });

  String _detailRouteId(ChannelModel channel) {
    final customId = channel.customId?.trim() ?? '';
    if (customId.isNotEmpty) return customId;
    return channel.id.toString();
  }

  String _previewTime() {
    final time = preview!.createdAt.toLocal();
    final today = DateTime.now();
    if (time.year == today.year &&
        time.month == today.month &&
        time.day == today.day) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day}';
  }

  /// 频道可见性图标（公开/私有）
  IconData _getVisibilityIcon() {
    return channel.isPublic ? CupertinoIcons.globe : CupertinoIcons.lock;
  }

  /// 频道可见性颜色
  Color _getVisibilityColor() {
    return channel.isPublic ? AppColors.primary : AppColors.iosGray;
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
      child: Icon(CupertinoIcons.speaker_2, size: 24, color: AppColors.primary),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
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
            if (preview != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.small,
                ),
                child: Text(
                  _previewTime(),
                  style: context.textStyle(
                    FontSizeType.small,
                    color: AppColors.getTextColor(
                      brightness,
                      isSecondary: true,
                    ),
                  ),
                ),
              ),
            // 频道可见性图标
            if (!channel.isPublic)
              Icon(
                _getVisibilityIcon(),
                size: 14,
                color: _getVisibilityColor().withValues(alpha: 0.7),
              ),
            // 付费标签（独立于可见性）
            if (channel.hasPrice)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.iosOrange.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.money_dollar,
                      size: 10,
                      color: AppColors.iosOrange,
                    ),
                    AppSpacing.horizontalTiny,
                    Text(
                      t.channel.accessTypePaid,
                      style: context.textStyle(
                        FontSizeType.tiny,
                        fontWeight: FontWeight.w600,
                        color: AppColors.iosOrange,
                      ),
                    ),
                  ],
                ),
              ),
            // 角色标签（仅"我管理的"标签页显示）
            if (showRole && channelRoleLabel(channel.userRole).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.tiny),
                child: ChannelRoleBadge(role: channel.userRole),
              ),
            ],
            if (channel.isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        subtitle: Text(
          preview?.contentPreview ??
              (channel.description?.trim().isNotEmpty == true
                  ? channel.description!.trim()
                  : t.organization.experienceUi.noIntro),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
