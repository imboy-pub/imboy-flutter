import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';
import 'package:imboy/page/conversation/conversation_tap_dispatcher.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'contact_provider.dart';

class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  // 语言变化监听器
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();

    // 监听语言变化，切换语言时刷新页面
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    // 取消语言变化监听
    _localeSubscription?.cancel();
    super.dispose();
  }

  // 刷新联系人列表
  Future<void> _onRefresh() async {
    iPrint(">>> contact onRefresh");
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      String msg = t.tipConnectDesc;
      EasyLoading.showInfo(' $msg        ');
      return;
    }
    final notifier = ref.read(contactProvider.notifier);
    List<ContactModel> contactList = await notifier.listFriend(true);
    if (contactList.isNotEmpty) {
      notifier.handleList(contactList);
    }
  }

  // 联系人列表项点击处理
  // slice-1.6: 大屏时派发 ContactSelection → 让 Web Shell 右栏显示反馈
  // （contactBuilder 当前是 _PlaceholderPanel，但能让用户看到点击生效）；
  // 窄屏保持原 context.push 行为（零回归）
  void _handleContactTap(ContactModel model) {
    if (model.onPressed != null) {
      model.onPressed!();
      return;
    }
    // 处理功能入口点击
    switch (model.peerId) {
      case kPeerIdMomentFeed:
        context.push('/moment/feed');
        return;
      case kPeerIdPeopleNearby:
        context.push('/contact/people_nearby');
        return;
      case kPeerIdNewFriend:
        context.push('/contact/new_friend');
        return;
      case kPeerIdGroup:
        context.push('/group/list');
        return;
      case kPeerIdTag:
        context.push('/contact/tags');
        return;
    }
    final useSplitView = MediaQuery.sizeOf(context).width > 800;
    if (useSplitView) {
      ref
          .read(webShellProvider.notifier)
          .selectItem(ContactSelection(uid: model.peerId.toString()));
      return;
    }
    // 跳转到用户信息页
    context.push('/contact/people/${model.peerId}?scene=contact_page');
  }

  // 联系人列表项长按处理
  // slice-1.5: 大屏时通过 webShellProvider 内嵌渲染右栏 ChatPanel；
  // 窄屏保持原 query string 跳路由行为（零回归）。
  void _handleContactLongPress(ContactModel model) {
    if (model.iconData == null) {
      final useSplitView = MediaQuery.sizeOf(context).width > 800;
      final action = resolveConversationTap(
        useSplitView: useSplitView,
        peerId: model.peerId.toString(),
        type: 'C2C',
        title: model.title,
        avatar: model.avatar,
        sign: model.sign,
      );
      switch (action) {
        case WebSelectChat(:final peerId, :final chatType):
          ref
              .read(webShellProvider.notifier)
              .selectItem(ChatSelection(peerId: peerId, chatType: chatType));
        case MobilePushChat():
          context.push(
            '/chat/${action.peerId}?type=${action.chatType}'
            '&title=${action.title}&avatar=${action.avatar}'
            '&sign=${action.sign}',
          );
      }
    }
  }

  // 构建聊天项
  Widget _buildChatItem(
    BuildContext context,
    ContactModel model, {
    Color? defHeaderBgColor,
  }) {
    final avatar = model.avatar.isNotEmpty ? dynamicAvatar(model.avatar) : null;
    final isSpecialContact = model.iconData != null;
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return FlatListTile(
      onTap: () => _handleContactTap(model),
      onLongPress: () => _handleContactLongPress(model),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: model.iconData == null
                ? Avatar(
                    imgUri: model.avatar,
                    width: 48,
                    height: 48,
                    heroTag: 'avatar_${model.peerId}',
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: AppRadius.borderRadiusMedium,
                      color:
                          model.bgColor ??
                          defHeaderBgColor ??
                          AppColors.primaryAlpha10,
                      image: avatar,
                    ),
                    child: model.iconData,
                  ),
          ),
          // 在线状态指示器（仅对真实联系人显示）
          if (!isSpecialContact)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getOnlineStatusColor(context, model),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.getBackgroundColor(brightness),
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        model.title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextColor(brightness),
        ),
      ),
      subtitle: (!isSpecialContact && model.lastSeenAt != null)
          ? UserOnlineStatusWidget(
              isOnline: model.status == 'online',
              lastSeenTimestamp: model.lastSeenAt,
              hideOnlineStatus: false,
              textStyle: TextStyle(
                fontSize: 13,
                color: AppColors.getTextColor(brightness, isSecondary: true),
              ),
              indicatorSize: 0,
            )
          : null,
    );
  }

  // 获取在线状态颜色（DESIGN.md §5：使用 iOS 语义色，保持跨亮暗一致）
  Color _getOnlineStatusColor(BuildContext context, ContactModel model) {
    final brightness = Theme.of(context).brightness;
    if (model.status == 'online') {
      return AppColors.getIosGreen(brightness);
    } else if (model.lastSeenAt != null) {
      final nowMs = DateTimeHelper.millisecond();
      final lastSeenMs = model.lastSeenAt!;
      final diffMs = nowMs - lastSeenMs;

      if (diffMs <= 1 * 3600 * 1000) {
        return AppColors.iosOrange;
      } else if (diffMs <= 24 * 3600 * 1000) {
        return AppColors.getIosBlue(brightness);
      } else if (diffMs <= 7 * 24 * 3600 * 1000) {
        return Colors.purple;
      } else {
        return Colors.grey;
      }
    } else {
      return Colors.grey.withValues(alpha: 0.5);
    }
  }

  // 构建索引项
  Widget _buildSusItem(
    BuildContext context,
    String tag, {
    double susHeight = 32,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: susHeight,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 20.0),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: theme.colorScheme.surface),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: AppRadius.borderRadiusMedium,
        ),
        child: Text(
          tag,
          softWrap: false,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  // 构建功能入口项（附近的人、新朋友等）
  Widget _buildFeatureItem(BuildContext context, ContactModel model) {
    return _buildChatItem(
      context,
      model,
      defHeaderBgColor: AppColors.primaryAlpha10,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(contactProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.getBackgroundColor(brightness),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SizedBox.shrink(),
        title: Text(
          t.titleContact,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextColor(brightness),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.pushNamed('user_tag_list');
            },
            icon: const Icon(Icons.label_outline, size: 24),
            tooltip: t.tags,
            color: AppColors.getTextColor(brightness),
          ),
          IconButton(
            onPressed: () {
              context.push('/contact/add_friend');
            },
            icon: const Icon(Icons.person_add_alt_outlined, size: 24),
            tooltip: t.addFriend,
            color: AppColors.getTextColor(brightness),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          state.isLoading
              ? const ShimmerList(padding: EdgeInsets.only(top: 10))
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.primary,
                  backgroundColor: AppColors.getBackgroundColor(brightness),
                  strokeWidth: 2.5,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: AzListView(
                          data: state.contactList,
                          itemCount: state.contactList.length,
                          itemBuilder: (BuildContext context, int index) {
                            ContactModel model = state.contactList[index];

                            // 如果是功能入口项（有 iconData），使用特殊的构建方法
                            if (model.iconData != null) {
                              return _buildFeatureItem(context, model);
                            }

                            return _buildChatItem(
                              context,
                              model,
                              defHeaderBgColor: AppColors.primaryAlpha10,
                            );
                          },
                          physics: const AlwaysScrollableScrollPhysics(),
                          susItemBuilder: (BuildContext context, int index) {
                            ContactModel model = state.contactList[index];
                            if ('↑' == model.getSuspensionTag()) {
                              return Container();
                            }
                            return _buildSusItem(
                              context,
                              model.getSuspensionTag(),
                            );
                          },
                          indexBarData: state.contactList.isNotEmpty
                              ? ['↑', ...state.indexBarData]
                              : [],
                          indexBarOptions: IndexBarOptions(
                            needRebuild: true,
                            ignoreDragCancel: true,
                            downTextStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            downItemDecoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            indexHintWidth: 64,
                            indexHintHeight: 64,
                            indexHintDecoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              borderRadius: AppRadius.borderRadiusSmall,
                            ),
                            indexHintTextStyle: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            indexHintAlignment: Alignment.centerRight,
                            indexHintChildAlignment: const Alignment(0, 0),
                            indexHintOffset: const Offset(-20.0, 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          // 无数据提示
          if (!state.isLoading && state.contactList.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: NoDataView(text: t.noContacts),
            ),
        ],
      ),
    );
  }
}
