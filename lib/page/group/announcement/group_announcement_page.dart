import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart'
    show FontSizeType, BuildContextThemeAccess;
import 'package:imboy/page/group/announcement/group_announcement_provider.dart';
// canManageAnnouncement re-exported from group_announcement_provider.dart

class GroupAnnouncementPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupAnnouncementPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupAnnouncementPage> createState() =>
      _GroupAnnouncementPageState();
}

class _GroupAnnouncementPageState extends ConsumerState<GroupAnnouncementPage> {
  @override
  void initState() {
    super.initState();
    // 初始化时加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.groupId.isEmpty) {
        context.pop();
        return;
      }
      ref.read(groupAnnouncementProvider(widget.groupId).notifier).onRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = groupAnnouncementProvider(widget.groupId);
    // 监听 errorMessage 变化，toast 后清错（对齐 A-2 moment_notify 模式）
    ref.listen<GroupAnnouncementState>(provider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg.isNotEmpty && prev?.errorMessage != msg) {
        AppLoading.showToast(t.common.groupAnnouncementLoadFailed);
        ref.read(provider.notifier).clearError();
      }
    });

    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.groupAnnouncement,
        rightDMActions: [
          // 仅 admin / owner / vice_owner 可发布公告
          if (canManageAnnouncement(state.currentUserRole))
            IconButton(
              tooltip: t.common.groupAnnouncementPublish,
              icon: Icon(Icons.add, color: Theme.of(context).iconTheme.color),
              onPressed: () => _showPublishDialog(context, notifier),
            ),
        ],
      ),
      body: state.announcements.isEmpty && !state.isLoading
          ? _buildEmptyView(context)
          : RefreshIndicator(
              onRefresh: () => notifier.onRefresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.regular,
                ),
                itemCount: state.announcements.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // 加载更多指示器
                  if (index == state.announcements.length) {
                    notifier.onLoadMore();
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.regular),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final announcement = state.announcements[index];
                  return _buildAnnouncementItem(
                    context,
                    announcement,
                    notifier,
                    canManage: canManageAnnouncement(state.currentUserRole),
                  );
                },
              ),
            ),
    );
  }

  // 构建公告项
  Widget _buildAnnouncementItem(
    BuildContext context,
    AnnouncementModel announcement,
    GroupAnnouncementNotifier notifier, {
    required bool canManage,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
        border: isDark
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 发布者信息
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text(
                    announcement.publisherName.isNotEmpty
                        ? announcement.publisherName[0].toUpperCase()
                        : '?',
                    style: context.textStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.publisherName,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notifier.formatTime(announcement.createdAt),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 仅管理员可见删除按钮
                if (canManage)
                  IconButton(
                    tooltip: t.common.groupAnnouncementDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.getIosRed(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      _showDeleteDialog(context, announcement, notifier);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.regular),
            // 公告内容
            Text(
              announcement.content,
              style: context
                  .textStyle(
                    FontSizeType.subheadline,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.9),
                  )
                  .copyWith(height: 1.5),
            ),
            if (announcement.expiredAt != null) ...[
              const SizedBox(height: AppSpacing.regular),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.common.groupAnnouncementExpiry(
                        time: notifier.formatTime(announcement.expiredAt!),
                      ),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 空视图
  Widget _buildEmptyView(BuildContext context) {
    return NoDataView(
      text: t.common.noGroupAnnouncement,
      icon: Icons.announcement_outlined,
    );
  }

  // 显示发布公告对话框
  void _showPublishDialog(
    BuildContext context,
    GroupAnnouncementNotifier notifier,
  ) {
    final contentController = TextEditingController();
    final expiredDateNotifier = ValueNotifier<DateTime?>(null);

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t.common.groupAnnouncementPublish),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: t.common.pleaseEnterAnnouncementContent,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.regular),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    expiredDateNotifier.value = date;
                  }
                },
                child: ValueListenableBuilder<DateTime?>(
                  valueListenable: expiredDateNotifier,
                  builder: (context, expiredDate, child) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.iosGray),
                        borderRadius: AppRadius.borderRadiusTiny,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 20),
                          const SizedBox(width: AppSpacing.small),
                          Text(
                            expiredDate != null
                                ? '${expiredDate.year}-${expiredDate.month.toString().padLeft(2, '0')}-${expiredDate.day.toString().padLeft(2, '0')}'
                                : t.common.selectExpirationDateOptional,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(t.common.buttonCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.trim().isNotEmpty) {
                  final success = await notifier.publishAnnouncement(
                    contentController.text.trim(),
                    expiredAt:
                        expiredDateNotifier.value?.millisecondsSinceEpoch,
                  );
                  if (success) {
                    AppLoading.showToast(
                      t.common.groupAnnouncementPublishSuccess,
                    );
                    if (context.mounted) context.pop();
                  } else {
                    AppLoading.showToast(
                      t.common.groupAnnouncementPublishFailed,
                    );
                  }
                }
              },
              child: Text(t.main.publish),
            ),
          ],
        ),
      ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteDialog(
    BuildContext context,
    AnnouncementModel announcement,
    GroupAnnouncementNotifier notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.confirmDelete),
        content: Text(t.common.groupAnnouncementDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(t.common.buttonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await notifier.deleteAnnouncement(
                announcement.id,
              );
              if (success) {
                AppLoading.showToast(t.common.groupAnnouncementDeleteSuccess);
                if (context.mounted) context.pop();
              } else {
                AppLoading.showToast(t.common.groupAnnouncementDeleteFailed);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getIosRed(
                Theme.of(context).brightness,
              ),
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text(t.common.groupAnnouncementDelete),
          ),
        ],
      ),
    );
  }
}
