import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';
import 'package:imboy/page/conversation/conversation_tap_dispatcher.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'contact_provider.dart';

/// 联系人列表页面 - iOS 17 Premium 风格
class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  void _handleContactTap(ContactModel model) {
    if (model.onPressed != null) {
      model.onPressed!();
      return;
    }
    switch (model.peerId) {
      case kPeerIdMomentFeed: context.push('/moment/feed'); return;
      case kPeerIdPeopleNearby: context.push('/contact/people_nearby'); return;
      case kPeerIdNewFriend: context.push('/contact/new_friend'); return;
      case kPeerIdGroup: context.push('/group/list'); return;
      case kPeerIdTag: context.push('/contact/tags'); return;
    }
    final useSplitView = MediaQuery.sizeOf(context).width > 800;
    if (useSplitView) {
      ref.read(webShellProvider.notifier).selectItem(ContactSelection(uid: model.peerId.toString()));
      return;
    }
    context.push('/contact/people/${model.peerId}?scene=contact_page');
  }

  void _handleContactLongPress(ContactModel model) {
    if (model.iconData == null) {
      final useSplitView = MediaQuery.sizeOf(context).width > 800;
      final action = resolveConversationTap(useSplitView: useSplitView, peerId: model.peerId.toString(), type: 'C2C', title: model.title, avatar: model.avatar, sign: model.sign);
      if (action is WebSelectChat) {
        ref.read(webShellProvider.notifier).selectItem(ChatSelection(peerId: action.peerId, chatType: action.chatType));
      } else if (action is MobilePushChat) {
        context.push('/chat/${action.peerId}?type=${action.chatType}&title=${action.title}&avatar=${action.avatar}&sign=${action.sign}');
      }
    }
  }

  Widget _buildChatItem(BuildContext context, ContactModel model, {Color? defHeaderBgColor}) {
    final isSpecial = model.iconData != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return ImBoyListTile(
      onTap: () => _handleContactTap(model),
      onLongPress: () => _handleContactLongPress(model),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isSpecial)
            Avatar(imgUri: model.avatar, width: 44, height: 44, heroTag: 'avatar_${model.peerId}')
          else
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: model.bgColor ?? defHeaderBgColor ?? AppColors.primary.withValues(alpha: 0.1),
              ),
              child: IconTheme(
                data: IconThemeData(color: isDark ? Colors.white : (model.bgColor != null ? Colors.white : AppColors.primary), size: 24),
                child: model.iconData!,
              ),
            ),
          if (!isSpecial)
            Positioned(
              bottom: -1, right: -1,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: _getOnlineStatusColor(context, model),
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? AppColors.darkSurface : Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(model.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
      subtitle: (!isSpecial && model.lastSeenAt != null)
          ? UserOnlineStatusWidget(
              isOnline: model.status == 'online',
              lastSeenTimestamp: model.lastSeenAt,
              hideOnlineStatus: false,
              textStyle: const TextStyle(fontSize: 13, color: AppColors.iosGray),
              indicatorSize: 0,
            )
          : null,
      trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.iosGray3),
    );
  }

  Color _getOnlineStatusColor(BuildContext context, ContactModel model) {
    final brightness = Theme.of(context).brightness;
    if (model.status == 'online') return AppColors.getIosGreen(brightness);
    if (model.lastSeenAt != null) {
      final diff = DateTimeHelper.millisecond() - model.lastSeenAt!;
      if (diff <= 3600000) return AppColors.iosOrange;
      if (diff <= 86400000) return AppColors.getIosBlue(brightness);
      return AppColors.iosGray;
    }
    return AppColors.iosGray.withValues(alpha: 0.5);
  }

  Widget _buildSusItem(BuildContext context, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurfaceGrouped,
      child: Text(tag, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.iosGray)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.titleContact,
      actions: [
        CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.tag, size: 22), onPressed: () => context.pushNamed('user_tag_list')),
        CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.person_add, size: 22), onPressed: () => context.push('/contact/add_friend')),
        const SizedBox(width: 8),
      ],
      slivers: [
        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(placeholder: t.common.search),
          ),
        ),

        if (state.isLoading)
          const SliverFillRemaining(child: ShimmerList())
        else if (state.contactList.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: NoDataView(text: t.common.noContacts))
        else
          SliverFillRemaining(
            child: AzListView(
              data: state.contactList,
              itemCount: state.contactList.length,
              itemBuilder: (context, index) {
                final model = state.contactList[index];
                return Column(
                  children: [
                    _buildChatItem(context, model),
                    if (index < state.contactList.length - 1 && state.contactList[index].getSuspensionTag() == state.contactList[index + 1].getSuspensionTag())
                      Padding(
                        padding: const EdgeInsets.only(left: 72),
                        child: Divider(height: 0.5, color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.5)),
                      ),
                  ],
                );
              },
              susItemBuilder: (context, index) {
                final tag = state.contactList[index].getSuspensionTag();
                if (tag == '↑') return const SizedBox.shrink();
                return _buildSusItem(context, tag);
              },
              indexBarData: ['↑', ...state.indexBarData],
              indexBarOptions: IndexBarOptions(
                needRebuild: true,
                indexHintDecoration: BoxDecoration(color: AppColors.getIosBlue(brightness).withValues(alpha: 0.9), shape: BoxShape.circle),
                indexHintTextStyle: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w600),
                downItemDecoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
          ),
      ],
    );
  }
}
