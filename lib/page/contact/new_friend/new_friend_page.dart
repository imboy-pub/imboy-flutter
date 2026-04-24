import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/config/enum.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/theme/default/app_colors.dart';

import '../confirm_new_friend/confirm_new_friend_page.dart';
import 'add_friend_page.dart';
import 'new_friend_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart' show FontSizeType;

class NewFriendPage extends ConsumerStatefulWidget {
  const NewFriendPage({super.key});

  @override
  ConsumerState<NewFriendPage> createState() => _NewFriendPageState();
}

class _NewFriendPageState extends ConsumerState<NewFriendPage> {
  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newFriendProvider.notifier).initData();
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  /// 构建搜索区域
  Widget _buildSearchArea(BuildContext context) {
    final notifier = ref.read(newFriendProvider.notifier);

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: searchBar(
          context,
          hintText: t.hintLoginAccount,
          queryTips: t.hintLoginAccount,
          searchLabel: t.hintLoginAccount,
          doSearch: ((query) async {
            return notifier.userSearch(kwd: query);
          }),
          doBuildResults: (results) =>
              _doBuildUserSearchResults(context, results),
          onTapForItem: (value) {
            iPrint("> on search value tapped");
          },
        ),
      ),
    );
  }

  /// 构建用户搜索结果
  Widget _doBuildUserSearchResults(BuildContext context, List<dynamic> items) {
    return Column(children: _buildSearchResults(context, items));
  }

  List<Widget> _buildSearchResults(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 10, left: 0, right: 0, bottom: 0),
          padding: const EdgeInsets.only(
            top: 40,
            left: 0,
            right: 0,
            bottom: 40,
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black87
              : Colors.white,
          child: Center(
            child: Text(t.userNotExist, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ];
    }

    return items.map((item) {
      PeopleModel model = item;
      bool isSelf = model.id.toString() == UserRepoLocal.to.currentUid;

      return Container(
        margin: const EdgeInsets.only(top: 10, left: 0, right: 0, bottom: 0),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black87
            : Colors.white,
        child: ListTile(
          leading: Avatar(imgUri: model.avatar, width: 56, height: 56),
          title: Text(model.title),
          subtitle: Row(
            children: [
              genderIcon(model.gender),
              const Space(width: 10),
              if (model.region.isNotEmpty) Text(model.region),
            ],
          ),
          trailing: isSelf
              ? null
              : Container(
                  width: 80,
                  alignment: Alignment.centerRight,
                  child: (model.isFriend ?? false)
                      ? Text(t.added)
                      : Text(t.buttonAdd),
                ),
          onTap: () {
            if (isSelf) {
              // EasyLoading.showInfo(t.canNotAddYourselfFriend);
              return;
            }
            context.push(
              '/people_info/${model.id}',
              extra: {'scene': 'user_search'},
            );
          },
        ),
      );
    }).toList();
  }

  /// 构建好友申请项
  Widget _buildFriendRequestItem(
    BuildContext context,
    NewFriendModel model,
    int index,
  ) {
    bool fromSelf = model.from.toString() == UserRepoLocal.to.currentUid;
    final notifier = ref.read(newFriendProvider.notifier);

    // 检查申请是否过期
    NewFriendModel updatedModel = model;
    if (model.status == NewFriendStatus.waitingForValidation.index) {
      final nowMs = DateTimeHelper.millisecond();
      final createdMs = model.createdAt;
      final diffDays = (nowMs - createdMs) ~/ (24 * 3600 * 1000);
      if (diffDays > 7) {
        // 创建一个新的模型对象，状态设为过期
        updatedModel = NewFriendModel(
          uid: model.uid,
          from: model.from,
          to: model.to,
          nickname: model.nickname,
          source: model.source,
          avatar: model.avatar,
          status: NewFriendStatus.expired.index,
          createdAt: model.createdAt,
          msg: model.msg,
          payload: model.payload,
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Slidable(
        groupTag: '1',
        closeOnScroll: true,
        endActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              key: ValueKey("delete_$index"),
              backgroundColor: AppColors.getIosRed(
                Theme.of(context).brightness,
              ),
              foregroundColor: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              onPressed: (_) async {
                await notifier.delete(model.from.toString(), model.to.toString());
              },
              icon: Icons.delete_outline,
              label: t.buttonDelete,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusRegular,
            onTap: () {
              context.push(
                '/people_info/${UserRepoLocal.to.currentUid == model.to.toString() ? model.from : model.to}',
                extra: {'scene': model.source},
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 头像
                  Avatar(imgUri: updatedModel.avatar!, width: 56, height: 56),

                  const SizedBox(width: 16),

                  // 用户信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 用户名和状态指示
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                updatedModel.nickname,
                                style: TextStyle(
                                  fontSize: FontSizeType.medium.size,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (fromSelf) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: AppRadius.borderRadiusMedium,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      t.friendRequestSent,
                                      style: TextStyle(
                                        fontSize: FontSizeType.small.size,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 6),

                        // 验证消息
                        Text(
                          updatedModel.msg,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: FontSizeType.normal.size,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 操作按钮区域
                  _buildActionButton(context, updatedModel, fromSelf),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton(
    BuildContext context,
    NewFriendModel model,
    bool fromSelf,
  ) {
    if (fromSelf &&
        model.status == NewFriendStatus.waitingForValidation.index) {
      // 发送方等待验证状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppRadius.borderRadiusLarge,
        ),
        child: Text(
          t.awaitingVerification,
          style: TextStyle(
            fontSize: FontSizeType.small.size,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else if (model.status == NewFriendStatus.waitingForValidation.index) {
      // 接收方待处理状态
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => ConfirmNewFriendPage(
                  to: model.to.toString(),
                  from: model.from.toString(),
                  msg: model.msg,
                  nickname: model.nickname,
                  payload: model.payload,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusLarge,
            ),
          ),
          child: Text(
            t.accept,
            style: TextStyle(
              fontSize: FontSizeType.normal.size,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (model.status == NewFriendStatus.added.index) {
      // 已添加状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: AppRadius.borderRadiusLarge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              t.added,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (model.status == NewFriendStatus.expired.index) {
      // 已过期状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.getIosRed(
            Theme.of(context).brightness,
          ).withValues(alpha: 0.1),
          borderRadius: AppRadius.borderRadiusLarge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: AppColors.getIosRed(Theme.of(context).brightness),
            ),
            const SizedBox(width: 4),
            Text(
              t.expired,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.getIosRed(Theme.of(context).brightness),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return NoDataView(
      text: t.noNewFriends,
      description: t.noNewFriendRequests,
      icon: Icons.person_add_outlined,
      iconBgSize: 80,
      iconSize: 40,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newFriendProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.newFriend,
        backgroundColor: Theme.of(context).colorScheme.surface,
        rightDMActions: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.borderRadiusXLarge,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const AddFriendPage(),
                    ),
                  );
                },
                child: Icon(
                  Icons.person_add_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: Column(
          children: [
            // 搜索区域
            _buildSearchArea(context),

            // 好友申请列表
            Expanded(
              child: state.isLoading
                  ? const ShimmerList()
                  : state.items.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      itemCount: state.items.length,
                      itemBuilder: (BuildContext context, int index) {
                        NewFriendModel model = state.items[index];
                        return _buildFriendRequestItem(context, model, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
