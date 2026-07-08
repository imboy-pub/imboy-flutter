import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'launch_chat_provider.dart';

/// 发起聊天页面
///
/// 体验优化（对标微信建群）：
/// - 顶部已选成员预览条（横滑头像，点击移除），所见即所选
/// - 联系人多选用 iOS 风格勾选（CupertinoIcons 圆圈）
/// - 建群成功后引导「进入群聊 / 完善群信息」
class LaunchChatPage extends ConsumerStatefulWidget {
  const LaunchChatPage({super.key});

  @override
  ConsumerState<LaunchChatPage> createState() => _LaunchChatPageState();
}

class _LaunchChatPageState extends ConsumerState<LaunchChatPage> {
  final int _itemHeight = 60;

  // 防抖状态
  bool _isCreatingGroup = false;

  @override
  void initState() {
    super.initState();
    // 延迟加载联系人列表，避免在 build 过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(launchChatProvider.notifier).loadContacts();
    });
  }

  /// 构建联系人列表项 - iOS 风格多选
  Widget _buildListItem(BuildContext context, ContactModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(launchChatProvider);

    // 检查是否已选中
    final isSelected = state.selects.any((s) => s.peerId == model.peerId);

    return Container(
      height: _itemHeight.toDouble(),
      color: isDark ? colorScheme.surface : AppColors.lightSurface,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          ref.read(launchChatProvider.notifier).toggleSelection(model);
        },
        child: Row(
          children: [
            // 选择状态图标 - iOS 风格圆圈勾选
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.regular,
                right: AppSpacing.medium,
              ),
              child: Icon(
                isSelected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: isSelected
                    ? AppColors.getIosBlue(Theme.of(context).brightness)
                    : colorScheme.outline.withValues(alpha: 0.3),
                size: 26,
              ),
            ),
            // 用户头像
            Avatar(imgUri: model.avatar, width: 40, height: 40),
            const SizedBox(width: AppSpacing.medium),
            // 用户昵称
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                height: _itemHeight.toDouble(),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 0.5,
                      color: colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Text(
                  model.title,
                  style: context.textStyle(
                    FontSizeType.body,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 已选成员预览条（横滑头像，点击移除）
  Widget _buildSelectedPreview() {
    final state = ref.watch(launchChatProvider);
    final selects = state.selects;
    if (selects.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 92,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : AppColors.lightSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selects.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.medium),
        itemBuilder: (context, index) {
          final contact = selects[index];
          return _SelectedAvatar(
            contact: contact,
            onRemove: () {
              ref.read(launchChatProvider.notifier).toggleSelection(contact);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(launchChatProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        title: t.common.selectContacts,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.small),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              t.common.buttonCancel,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.medium,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.regular),
            child: RoundedElevatedButton(
              text: '${t.common.buttonAccomplish}${state.selectsTips}',
              highlighted: state.selects.isNotEmpty && !_isCreatingGroup,
              onPressed: _isCreatingGroup
                  ? null
                  : () async {
                      // 防抖：设置创建状态
                      setState(() => _isCreatingGroup = true);
                      try {
                        AppLoading.show(status: t.common.loading);
                        int memberCount = state.selects.length;
                        GroupModel? m = await ref
                            .read(launchChatProvider.notifier)
                            .groupAdd(state.selects);
                        if (m != null) {
                          AppLoading.dismiss();
                          ref.read(launchChatProvider.notifier).resetData();
                          if (context.mounted) {
                            // 建群成功引导：进入群聊 or 完善群信息
                            _showCreatedSheet(m, memberCount + 1);
                          }
                        } else {
                          AppLoading.dismiss();
                          AppLoading.showError(t.common.tipFailed);
                        }
                      } catch (e) {
                        AppLoading.dismiss();
                        AppLoading.showError(t.common.tipFailed);
                        iPrint("groupAdd error: ${e.runtimeType}");
                      } finally {
                        if (mounted) {
                          setState(() => _isCreatingGroup = false);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部功能入口卡片
          _buildQuickEntries(isDark, colorScheme),

          // 已选成员预览条
          _buildSelectedPreview(),

          // 联系人列表
          Expanded(
            child: Container(
              color: isDark ? colorScheme.surface : AppColors.lightSurface,
              child: state.items.isEmpty
                  ? NoDataView(text: t.common.noData)
                  : AzListView(
                      data: state.items,
                      itemCount: state.items.length,
                      itemBuilder: (BuildContext context, int index) {
                        ContactModel model = state.items[index];
                        return _buildListItem(context, model);
                      },
                      physics: const AlwaysScrollableScrollPhysics(),
                      susItemBuilder: (BuildContext context, int index) {
                        ContactModel model = state.items[index];
                        if ('↑' == model.getSuspensionTag()) {
                          return Container();
                        }
                        return Container();
                      },
                      indexBarData: state.items.isNotEmpty
                          ? ['↑', ...state.currIndexBarData]
                          : [],
                      indexBarOptions: IndexBarOptions(
                        needRebuild: true,
                        ignoreDragCancel: true,
                        downTextStyle: context.textStyle(
                          FontSizeType.small,
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        downItemDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indexHintWidth: 64,
                        indexHintHeight: 64,
                        indexHintDecoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: AppRadius.borderRadiusSmall,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.darkBackground.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indexHintTextStyle: context.textStyle(
                          FontSizeType.largeTitle,
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        indexHintAlignment: Alignment.centerRight,
                        indexHintChildAlignment: const Alignment(0, 0),
                        indexHintOffset: const Offset(-20.0, 0),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部快捷入口卡片（选择群聊 / 面对面建群）
  Widget _buildQuickEntries(bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(
        top: AppSpacing.regular,
        bottom: AppSpacing.small,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : AppColors.lightSurface,
          borderRadius: AppRadius.borderRadiusMedium,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? colorScheme.shadow.withValues(alpha: 0.05)
                  : AppColors.darkBackground.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _QuickEntryTile(
              icon: CupertinoIcons.person_2_square_stack,
              iconColor: AppColors.getIosBlue(Theme.of(context).brightness),
              title: t.contact.selectAGroup,
              onTap: () => context.push('/group/select'),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
            _QuickEntryTile(
              icon: CupertinoIcons.person_3_fill,
              iconColor: AppColors.iosOrange,
              title: t.chat.createGroupF2f,
              onTap: () => context.push('/group/face_to_face'),
            ),
          ],
        ),
      ),
    );
  }

  /// 建群成功引导弹层
  void _showCreatedSheet(GroupModel m, int memberCount) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        // TODO(i18n): groupCreated/groupCreatedDesc/enterGroupChat/editGroupInfo
        title: const Text('群聊已创建'),
        message: const Text('群聊创建成功，邀请你完善群信息或直接进入群聊'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _enterChat(m, memberCount);
            },
            child: const Text('进入群聊'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(
                '/group/detail/${m.groupId}',
                extra: {
                  'title': m.title,
                  'memberCount': memberCount,
                  'options': {'memberCount': memberCount},
                },
              );
            },
            child: const Text('完善群信息'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }

  /// 进入群聊
  void _enterChat(GroupModel m, int memberCount) {
    context.push(
      '/chat/${m.groupId}',
      extra: {
        'type': 'C2G',
        'title': m.title,
        'avatar': m.avatar,
        'sign': '',
        'options': {'memberCount': memberCount},
      },
    );
  }
}

/// 已选成员头像（带移除按钮）
class _SelectedAvatar extends StatelessWidget {
  const _SelectedAvatar({required this.contact, required this.onRemove});

  final ContactModel contact;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Avatar(imgUri: contact.avatar, width: 48, height: 48),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.getIosRed(Theme.of(context).brightness),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 10,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          SizedBox(
            width: 52,
            child: Text(
              contact.title,
              style: context.textStyle(
                FontSizeType.caption2,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷入口项（带图标）
class _QuickEntryTile extends StatelessWidget {
  const _QuickEntryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      onPressed: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Text(
                title,
                style: context.textStyle(
                  FontSizeType.body,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
