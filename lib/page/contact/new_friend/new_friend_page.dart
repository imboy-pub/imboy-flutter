import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'package:imboy/config/enum.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import '../confirm_new_friend/confirm_new_friend_page.dart';
import 'add_friend_page.dart';
import 'new_friend_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 新的朋友页面 - iOS 17 Premium 风格重构
class NewFriendPage extends ConsumerStatefulWidget {
  const NewFriendPage({super.key});

  @override
  ConsumerState<NewFriendPage> createState() => _NewFriendPageState();
}

class _NewFriendPageState extends ConsumerState<NewFriendPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(newFriendProvider.notifier).initData(),
    );
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newFriendProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.contact.newFriend,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.person_add, size: 22),
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute<void>(builder: (_) => const AddFriendPage()),
          ),
        ),
      ],
      slivers: [
        // 搜索栏
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.small,
            ),
            child: CupertinoSearchTextField(
              placeholder: t.account.hintLoginAccount,
              onSubmitted: (v) =>
                  ref.read(newFriendProvider.notifier).userSearch(kwd: v),
            ),
          ),
        ),

        // 申请列表
        if (state.isLoading)
          const SliverFillRemaining(child: ShimmerList())
        else if (state.items.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(context))
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.large),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final model = state.items[index] as NewFriendModel;
                return _buildFriendRequestItem(
                  context,
                  model,
                  index,
                  brightness,
                );
              }, childCount: state.items.length),
            ),
          ),
      ],
    );
  }

  Widget _buildFriendRequestItem(
    BuildContext context,
    NewFriendModel model,
    int index,
    Brightness brightness,
  ) {
    bool fromSelf = model.from.toString() == UserRepoLocal.to.currentUid;

    return Slidable(
      key: ValueKey("new_friend_${model.uid}_$index"),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => ref
                .read(newFriendProvider.notifier)
                .delete(model.from.toString(), model.to.toString()),
            backgroundColor: AppColors.getIosRed(brightness),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete_solid,
            label: t.common.buttonDelete,
          ),
        ],
      ),
      child: ImBoyListTile(
        onTap: () => context.push(
          '/people_info/${UserRepoLocal.to.currentUid == model.to.toString() ? model.from : model.to}',
          extra: {'scene': model.source},
        ),
        leading: Avatar(imgUri: model.avatar ?? '', width: 56, height: 56),
        title: Row(
          children: [
            Expanded(
              child: Text(
                model.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (fromSelf)
              _buildTag(
                t.contact.friendRequestSent,
                AppColors.getIosBlue(brightness),
              ),
          ],
        ),
        subtitle: Text(model.msg, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: _buildStatusAction(context, model, fromSelf, brightness),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(left: AppSpacing.small),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusAction(
    BuildContext context,
    NewFriendModel model,
    bool fromSelf,
    Brightness brightness,
  ) {
    if (model.status == NewFriendStatus.added.index) {
      return Text(
        t.common.added,
        style: const TextStyle(fontSize: 14, color: AppColors.iosGray),
      );
    }
    if (model.status == NewFriendStatus.expired.index) {
      return Text(
        t.main.expired,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.getIosRed(brightness).withValues(alpha: 0.5),
        ),
      );
    }
    if (fromSelf) {
      return Text(
        t.common.awaitingVerification,
        style: const TextStyle(fontSize: 14, color: AppColors.iosGray),
      );
    }

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.tiny,
      ),
      color: AppColors.getIosBlue(brightness),
      borderRadius: BorderRadius.circular(18),
      onPressed: () => Navigator.push(
        context,
        CupertinoPageRoute<void>(
          builder: (_) => ConfirmNewFriendPage(
            to: model.to.toString(),
            from: model.from.toString(),
            msg: model.msg,
            nickname: model.nickname,
            payload: model.payload,
          ),
        ),
      ),
      child: Text(
        t.common.accept,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return NoDataView(
      text: t.common.noNewFriends,
      description: t.common.noNewFriendRequests,
      icon: Icons.person_add_outlined,
    );
  }
}
