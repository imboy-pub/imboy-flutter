import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/live_room/live_room_list/live_room_list_provider.dart';
import 'package:imboy/store/api/live_room_api.dart';
import 'package:imboy/store/model/live_room_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class LiveRoomListPage extends ConsumerStatefulWidget {
  const LiveRoomListPage({super.key});

  @override
  ConsumerState<LiveRoomListPage> createState() => _LiveRoomListPageState();
}

class _LiveRoomListPageState extends ConsumerState<LiveRoomListPage> {
  StreamSubscription<dynamic>? _localeSubscription;
  final _scrollController = ScrollController();
  final _api = LiveRoomApi();

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
    // 页面首次加载时从后端拉取数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveRoomListProvider.notifier).loadFirst();
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      ref.read(liveRoomListProvider.notifier).loadMore();
    }
  }

  /// 弹出创建直播间对话框，成功后跳转到推流页
  Future<void> _showCreateRoomDialog() async {
    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.chat.liveRoomCreateTitle),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: t.main.liveRoomTitleLabel,
            hintText: t.main.liveRoomTitleHint,
          ),
          autofocus: true,
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.buttonCreate),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final title = titleController.text.trim();
    if (title.isEmpty) {
      EasyLoading.showToast(t.error.liveRoomTitleRequired);
      return;
    }

    EasyLoading.show(status: t.chat.liveRoomCreating);
    final room = await _api.create(title: title);
    EasyLoading.dismiss();

    if (!mounted) return;
    if (room == null) return; // create() 内部已显示错误

    // 跳转到推流页，携带 roomId 和 streamKey
    context.push('/live_room/publisher', extra: room);
    // 刷新列表
    ref.read(liveRoomListProvider.notifier).loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(liveRoomListProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.main.myLive,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRoomDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(liveRoomListProvider.notifier).loadFirst(),
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
            ? NoDataView(text: t.common.noData)
            : ListView.separated(
                controller: _scrollController,
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.regular),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildRoomTile(context, state.items[index]);
                },
              ),
      ),
    );
  }

  Widget _buildRoomTile(BuildContext context, LiveRoomModel room) {
    return ListTile(
      leading: room.cover.isNotEmpty
          ? ClipRRect(
              borderRadius: AppRadius.borderRadiusTiny,
              child: Image(
                image: cachedImageProvider(room.cover),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.live_tv),
              ),
            )
          : const Icon(Icons.live_tv, size: 40),
      title: Text(
        room.title.isNotEmpty ? room.title : 'Live Room',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Builder(
        builder: (context) {
          final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
          return Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: room.isLive
                    ? AppColors.getIosRed(Theme.of(context).brightness)
                    : secondaryColor,
              ),
              const SizedBox(width: 4),
              Text(room.isLive ? 'LIVE' : 'Idle'),
              const SizedBox(width: 12),
              Icon(Icons.remove_red_eye, size: 12, color: secondaryColor),
              const SizedBox(width: 2),
              Text(
                '${room.viewerCount}',
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ],
          );
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (room.isLive)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: t.chat.liveRoomWatch,
              onPressed: () =>
                  context.push('/live_room/subscriber', extra: room),
            ),
          const Icon(Icons.navigate_next),
        ],
      ),
      onTap: () {
        if (room.isLive) {
          // 直播中：跳转到订阅者（观看）页面，携带房间信息
          context.push('/live_room/subscriber', extra: room);
        } else {
          // 非直播中：跳转到推流页（继续推流）
          context.push('/live_room/publisher', extra: room);
        }
      },
    );
  }
}
