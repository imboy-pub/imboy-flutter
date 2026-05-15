import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';

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
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isLoadingRecommended = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>([
      _loadSubscribedChannelIds(),
      _loadRecommendedChannels(),
    ]);
  }

  Future<void> _loadSubscribedChannelIds() async {
    try {
      final channels = await ChannelService.to.getSubscribedChannels(
        limit: 200,
      );
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
      final channels = await ChannelService.to.discoverChannels(limit: 50);
      if (mounted) {
        setState(() {
          _recommendedChannels = channels;
          _isLoadingRecommended = false;
        });
      }
    } catch (e) {
      iPrint('加载推荐频道失败: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _isLoadingRecommended = false;
        });
      }
    }
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
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.channel.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
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
                    ? Colors.grey[100]
                    : Colors.grey[800],
              ),
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
            ),
          ),

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
    final t = context.t;

    final success = await ref
        .read(channelListProvider.notifier)
        .subscribeChannel(channel.id.toString());

    if (success && mounted) {
      setState(() {
        _subscribedChannelIds.add(channel.id.toString());
      });
      await _loadSubscribedChannelIds();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? t.channel.subscribeSuccess : t.channel.subscribeFailed,
          ),
        ),
      );
    }

    return success;
  }

  Future<bool> _unsubscribeChannel(ChannelModel channel) async {
    final t = context.t;

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
    if (confirmed != true) return false;

    final success = await ref
        .read(channelListProvider.notifier)
        .unsubscribeChannel(channel.id.toString());

    if (success && mounted) {
      setState(() {
        _subscribedChannelIds.remove(channel.id.toString());
      });
      await _loadSubscribedChannelIds();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? t.common.tipSuccess : t.common.tipFailed),
        ),
      );
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

  String _detailRouteId(ChannelModel channel) {
    final customId = channel.customId?.trim() ?? '';
    if (customId.isNotEmpty) return customId;
    return channel.id.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return ListTile(
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
              margin: const EdgeInsets.only(left: 4),
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
          const SizedBox(height: 4),
          Text(
            widget.channel.description ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${widget.channel.subscriberCount} ${t.channel.subscribers}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (widget.channel.tags != null &&
                  widget.channel.tags!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.channel.tags!.take(2).join(' · '),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: widget.isSubscribed
          ? TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      await widget.onUnsubscribe();
                      if (mounted) {
                        setState(() => _isSubmitting = false);
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.channel.unsubscribe),
            )
          : TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      await widget.onSubscribe();
                      if (mounted) {
                        setState(() => _isSubmitting = false);
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.channel.subscribe),
            ),
      onTap: () {
        context.push('/channel/${_detailRouteId(widget.channel)}');
      },
    );
  }
}
