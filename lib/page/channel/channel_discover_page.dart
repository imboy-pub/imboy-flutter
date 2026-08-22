import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'channel_di_provider.dart';
import 'channel_provider.dart';

/// 发现/搜索频道页面
class ChannelDiscoverPage extends ConsumerStatefulWidget {
  const ChannelDiscoverPage({super.key});

  @override
  ConsumerState<ChannelDiscoverPage> createState() =>
      _ChannelDiscoverPageState();
}

class _ChannelDiscoverPageState extends ConsumerState<ChannelDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ChannelModel> _searchResults = [];
  List<ChannelModel> _recommendedChannels = [];
  final Set<String> _subscribedChannelIds = <String>{};
  // 发现页新能力：分类过滤 + 排序（channel_discovery_handler 契约）
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  String _sort = 'popular';
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isLoadingRecommended = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>([
      _loadSubscribedChannelIds(),
      _loadRecommendedChannels(),
      _loadCategories(),
    ]);
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref
          .read(channelServiceProvider)
          .channelCategories();
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (_) {
      // 分类拉取失败不阻塞主列表
    }
  }

  Future<void> _loadSubscribedChannelIds() async {
    try {
      final channels = await ref
          .read(channelServiceProvider)
          .getSubscribedChannels(limit: 200);
      if (!mounted) return;
      setState(() {
        _subscribedChannelIds
          ..clear()
          ..addAll(channels.map((e) => e.id.toString()));
      });
    } catch (_) {
      // 忽略异常，保持当前页面可用
    }
  }

  bool _isSubscribed(ChannelModel channel) {
    return _subscribedChannelIds.contains(channel.id.toString()) ||
        channel.isSubscribed;
  }

  /// 加载推荐频道
  Future<void> _loadRecommendedChannels() async {
    setState(() {
      _isLoadingRecommended = true;
    });

    try {
      final channels = await ref
          .read(channelServiceProvider)
          .discoverChannels(
            categoryId: _selectedCategoryId,
            sort: _sort,
            size: 50,
          );
      if (mounted) {
        setState(() {
          _recommendedChannels = channels;
          _isLoadingRecommended = false;
        });
      }
    } catch (e) {
      iPrint('加载推荐频道失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecommended = false;
        });
      }
    }
  }

  /// 输入防抖：300ms 内无新输入才触发搜索，避免每次按键都发请求
  void _onSearchChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => _search(value),
    );
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await ref
          .read(channelListProvider.notifier)
          .searchChannels(keyword);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.discover,
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: const EdgeInsets.all(AppSpacing.regular),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.channel.searchHint,
                prefixIcon: const Icon(CupertinoIcons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: t.common.clear,
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusXLarge,
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.light
                    ? AppColors.lightSurfaceContainer
                    : AppColors.darkSurfaceContainer,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounceTimer?.cancel();
                _search(value);
              },
              textInputAction: TextInputAction.search,
            ),
          ),

          // 分类条 + 排序（浏览态显示；搜索态隐藏——FTS 自带相关性排序）
          if (!_hasSearched) ...[
            if (_categories.isNotEmpty) _buildCategoryBar(),
            _buildSortBar(),
          ],

          // 内容区域
          Expanded(
            child: _hasSearched
                ? _buildSearchResults()
                : _buildRecommendedChannels(),
          ),
        ],
      ),
    );
  }

  /// 分类横向过滤条：全部 + 平台分类
  Widget _buildCategoryBar() {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final items = [
      <String, dynamic>{'id': 0, 'name': t.channel.allCategories},
      ..._categories,
    ];
    final selectedId = _selectedCategoryId ?? 0;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        itemCount: items.length,
        separatorBuilder: (_, _) => AppSpacing.horizontalSmall,
        itemBuilder: (context, index) {
          final cat = items[index];
          final catId = (cat['id'] as num).toInt();
          final selected = catId == selectedId;
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() => _selectedCategoryId = catId == 0 ? null : catId);
              _loadRecommendedChannels();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.getIosBlue(brightness)
                    : (brightness == Brightness.dark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface),
                borderRadius: AppRadius.button,
                border: Border.all(
                  color: AppColors.getIosSeparator(
                    brightness,
                  ).withValues(alpha: 0.3),
                  width: 0.33,
                ),
              ),
              child: Text(
                cat['name'] as String? ?? '',
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: selected
                      ? AppColors.lightTextPrimary
                      : (brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 排序切换（热门=订阅数，最新=创建时间）
  Widget _buildSortBar() {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        0,
      ),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: _sort,
        children: {
          'popular': Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(t.channel.sortPopular),
          ),
          'newest': Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(t.channel.sortNewest),
          ),
        },
        onValueChanged: (sort) {
          if (sort == null) return;
          setState(() => _sort = sort);
          _loadRecommendedChannels();
        },
      ),
    );
  }

  /// 构建推荐频道列表
  Widget _buildRecommendedChannels() {
    final t = context.t;

    if (_isLoadingRecommended) {
      return const ShimmerList(itemCount: 6);
    }

    if (_recommendedChannels.isEmpty) {
      return NoDataView(
        icon: Icons.campaign_outlined,
        text: t.channel.noRecommendedChannels,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait<void>([
          _loadSubscribedChannelIds(),
          _loadRecommendedChannels(),
        ]);
      },
      child: ListView.builder(
        itemCount: _recommendedChannels.length,
        itemBuilder: (context, index) {
          final channel = _recommendedChannels[index];
          return _SearchResultItem(
            channel: channel,
            isSubscribed: _isSubscribed(channel),
            onSubscribe: () => _subscribeChannel(channel),
            onUnsubscribe: () => _unsubscribeChannel(channel),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    final t = context.t;

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return NoDataView(icon: Icons.search_off, text: t.channel.noResults);
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final channel = _searchResults[index];
        return _SearchResultItem(
          channel: channel,
          isSubscribed: _isSubscribed(channel),
          onSubscribe: () => _subscribeChannel(channel),
          onUnsubscribe: () => _unsubscribeChannel(channel),
        );
      },
    );
  }

  Future<bool> _subscribeChannel(ChannelModel channel) async {
    if (!mounted) return false;
    final t = context.t;
    final channelIdStr = channel.id.toString();

    // 乐观更新
    setState(() {
      _subscribedChannelIds.add(channelIdStr);
    });

    final success = await ref
        .read(channelListProvider.notifier)
        .subscribeChannel(channelIdStr);

    if (!success && mounted) {
      // 失败回滚
      setState(() {
        _subscribedChannelIds.remove(channelIdStr);
      });
      AppLoading.showError(t.channel.subscribeFailed);
    } else if (success && mounted) {
      AppLoading.showSuccess(t.channel.subscribeSuccess);
    }

    return success;
  }

  Future<bool> _unsubscribeChannel(ChannelModel channel) async {
    final t = context.t;
    final channelIdStr = channel.id.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.channel.unsubscribeConfirm),
        content: Text(t.channel.unsubscribeConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    // 乐观更新
    setState(() {
      _subscribedChannelIds.remove(channelIdStr);
    });

    final success = await ref
        .read(channelListProvider.notifier)
        .unsubscribeChannel(channelIdStr);

    if (!success && mounted) {
      // 失败回滚
      setState(() {
        _subscribedChannelIds.add(channelIdStr);
      });
      AppLoading.showError(t.common.tipFailed);
    } else if (success && mounted) {
      AppLoading.showSuccess(t.common.tipSuccess);
    }

    return success;
  }
}

/// 搜索结果项
class _SearchResultItem extends ConsumerStatefulWidget {
  final ChannelModel channel;
  final bool isSubscribed;
  final Future<bool> Function() onSubscribe;
  final Future<bool> Function() onUnsubscribe;

  const _SearchResultItem({
    required this.channel,
    required this.isSubscribed,
    required this.onSubscribe,
    required this.onUnsubscribe,
  });

  @override
  ConsumerState<_SearchResultItem> createState() => _SearchResultItemState();
}

class _SearchResultItemState extends ConsumerState<_SearchResultItem> {
  bool _isSubmitting = false;
  int _localSubscriberCountDelta = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _SearchResultItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.subscriberCount != widget.channel.subscriberCount) {
      // 权威计数已包含本地 mutation，避免刷新后重复加减。
      _localSubscriberCountDelta = 0;
    }
  }

  String _detailRouteId(ChannelModel channel) {
    final customId = channel.customId?.trim() ?? '';
    if (customId.isNotEmpty) return customId;
    return channel.id.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final int displayCount =
        (widget.channel.subscriberCount + _localSubscriberCountDelta).clamp(
          0,
          1 << 31,
        );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusMedium,
        side: BorderSide(
          color: AppColors.getIosSeparator(
            Theme.of(context).brightness,
          ).withValues(alpha: 0.45),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage:
              widget.channel.avatar != null && widget.channel.avatar!.isNotEmpty
              ? cachedImageProvider(widget.channel.avatar!, w: 96)
              : null,
          child: widget.channel.avatar == null || widget.channel.avatar!.isEmpty
              ? const Icon(Icons.campaign, size: 24)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.channel.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.channel.isVerified)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.tiny),
                child: const Icon(
                  Icons.verified,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalTiny,
            Text(
              widget.channel.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
            AppSpacing.verticalTiny,
            Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: AppColors.iosGray),
                AppSpacing.horizontalTiny,
                Text(
                  '$displayCount ${t.channel.subscribers}',
                  style: context.textStyle(
                    FontSizeType.small,
                    color: AppColors.iosGray,
                  ),
                ),
                if (widget.channel.tags != null &&
                    widget.channel.tags!.isNotEmpty) ...[
                  AppSpacing.horizontalSmall,
                  Expanded(
                    child: Text(
                      widget.channel.tags!.take(2).join(' · '),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.iosGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: widget.channel.isManaged
            ? OutlinedButton(
                onPressed: () {
                  context.push('/channel/${_detailRouteId(widget.channel)}');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(t.main.manage),
              )
            : (widget.isSubscribed
                  ? OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              final success = await widget.onUnsubscribe();
                              if (mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                  if (success) _localSubscriberCountDelta--;
                                });
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Icon(Icons.check, size: 14),
                      label: Text(t.channel.subscribed),
                    )
                  : FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              final success = await widget.onSubscribe();
                              if (mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                  if (success) _localSubscriberCountDelta++;
                                });
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : Text(t.channel.subscribe),
                    )),
        onTap: () {
          context.push('/channel/${_detailRouteId(widget.channel)}');
        },
      ),
    );
  }
}
