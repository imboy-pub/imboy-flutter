import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/conversation/conversation_tap_dispatcher.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'contact_menu_decoration.dart';
import 'contact_provider.dart';

/// 过滤联系人（标题包含 query，大小写不敏感）。query 空返回全量。纯函数，便于单测。
List<ContactModel> filteredContacts(List<ContactModel> all, String query) {
  if (query.isEmpty) return all;
  final q = query.toLowerCase();
  return all.where((m) => m.title.toLowerCase().contains(q)).toList();
}

/// 由过滤结果派生索引栏标签，避免"索引栏有字母但列表无对应项"。
/// query 空时沿用 ['↑', ...原始 indexBarData]；非空时只保留过滤结果中出现的标签。
List<String> filteredIndexBar(
  List<ContactModel> filtered,
  Set<String> stateIndexBarData,
  String query,
) {
  if (query.isEmpty) return ['↑', ...stateIndexBarData];
  final tags = <String>{};
  var hasUp = false;
  for (final m in filtered) {
    final tg = m.getSuspensionTag();
    if (tg == '↑') {
      hasUp = true;
    } else if (tg.isNotEmpty) {
      tags.add(tg);
    }
  }
  return [if (hasUp) '↑', ...tags.toList()..sort()];
}

/// 联系人点击是否应派发到 Web Shell 右栏：仅当当前页面挂载于 `/web_shell`
/// 路由下时，[webShellProvider] 才有消费者（[WebShellPage] 三栏布局会
/// `ref.watch` 它）。挂载于 `/bottom_navigation` 等其它宿主时该 provider
/// 无人消费，派发 selection 会导致点击后"什么都不发生"，必须走 Mobile
/// push 兜底。
bool _isWebShellHosted(BuildContext context) {
  try {
    return GoRouterState.of(context).matchedLocation.startsWith('/web_shell');
  } on GoError {
    return false;
  }
}

/// 联系人列表页面 - iOS 17 Premium 风格
class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  /// 联系人搜索控制器与当前 query（已 trim + 小写）。空串表示未过滤。
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() => _searchQuery = q);
  }

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactProvider.notifier).loadData();
      ref.read(newFriendRemindProvider.notifier).countReminders();
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleContactTap(ContactModel model) {
    if (model.onPressed != null) {
      model.onPressed!();
      return;
    }
    switch (model.peerId) {
      case kPeerIdMomentFeed:
        context.push('/moment/feed');
        return;
      case kPeerIdPeopleNearby:
        debugPrint('[PeopleNearbyPerf] 0a.点击入口，开始 push 路由');
        context.push('/contact/people_nearby');
        return;
      case kPeerIdAssistantPlaza:
        context.push('/contact/assistant_plaza');
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
    final useSplitView =
        _isWebShellHosted(context) &&
        AppBreakpoints.isWide(MediaQuery.sizeOf(context).width);
    if (useSplitView) {
      ref
          .read(webShellProvider.notifier)
          .selectItem(ContactSelection(uid: model.peerId.toString()));
      return;
    }
    context.push('/contact/people/${model.peerId}?scene=contact_page');
  }

  void _handleContactLongPress(ContactModel model) {
    if (!model.isMenuEntry) {
      final useSplitView =
          _isWebShellHosted(context) &&
          AppBreakpoints.isWide(MediaQuery.sizeOf(context).width);
      final action = resolveConversationTap(
        useSplitView: useSplitView,
        peerId: model.peerId.toString(),
        type: 'C2C',
        title: model.title,
        avatar: model.avatar,
        sign: model.sign,
      );
      if (action is WebSelectChat) {
        ref
            .read(webShellProvider.notifier)
            .selectItem(
              ChatSelection(peerId: action.peerId, chatType: action.chatType),
            );
      } else if (action is MobilePushChat) {
        context.push(
          '/chat/${action.peerId}?type=${action.chatType}&title=${action.title}&avatar=${action.avatar}&sign=${action.sign}',
        );
      }
    }
  }

  Widget _buildChatItem(
    BuildContext context,
    ContactModel model, {
    Color? defHeaderBgColor,
    int newFriendUnreadCount = 0,
  }) {
    final isSpecial = model.isMenuEntry;
    final menuDecoration = isSpecial
        ? contactMenuDecorationOf(model.peerId)
        : null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final showNewFriendDot =
        model.peerId == kPeerIdNewFriend && newFriendUnreadCount > 0;

    return ImBoyListTile(
      onTap: () => _handleContactTap(model),
      onLongPress: () => _handleContactLongPress(model),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isSpecial)
            Avatar(
              imgUri: model.avatar,
              width: 44,
              height: 44,
              heroTag: 'avatar_${model.peerId}',
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.cell),
                color:
                    menuDecoration?.bgColor ??
                    defHeaderBgColor ??
                    AppColors.primary.withValues(alpha: 0.1),
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isDark
                      ? AppColors.onPrimary
                      : (menuDecoration?.bgColor != null
                            ? AppColors.onPrimary
                            : AppColors.primary),
                  size: 24,
                ),
                child: menuDecoration?.iconData ?? const SizedBox.shrink(),
              ),
            ),
          if (!isSpecial)
            Positioned(
              bottom: -1,
              right: -1,
              // 这个点是纯颜色编码（在线/1小时内/1天内/更久），本身读不出来。
              // 有 lastSeenAt 时 subtitle 的 UserOnlineStatusWidget 已经把同样
              // 的信息写成文字了，点只是重复；没有 lastSeenAt 时它是灰点表示
              // "状态未知"，念出来也是噪音。两种情况都不该进语义树。
              child: ExcludeSemantics(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getOnlineStatusColor(context, model),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          if (showNewFriendDot)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.iosRed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              model.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 昵称先 ellipsis，徽章不压缩（透明 AI 披露）
          if (model.accountType > 0) ...[
            AppSpacing.horizontalTiny,
            BotBadge(accountType: model.accountType),
          ],
        ],
      ),
      subtitle: (!isSpecial && model.lastSeenAt != null)
          ? UserOnlineStatusWidget(
              isOnline: model.status == 'online',
              lastSeenTimestamp: model.lastSeenAt,
              hideOnlineStatus: false,
              textStyle: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
              indicatorSize: 0,
            )
          : null,
      // 同会话列表：整行可点，不画 disclosure chevron。
      // iOS 通讯录 / 微信通讯录都没有。
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
    // width 必须按约束决定，不能写死 double.infinity。
    //
    // AzListView 把吸顶头同时用在两处：列表内联项（宽度有界）和悬浮头
    // （Stack 的 positioned child，某些布局路径下不给横向锚点 → 宽度无界）。
    // 无界时 double.infinity 会直接触发
    // "BoxConstraints forces an infinite width" 断言，整页布局崩掉。
    // 有界时仍撑满，视觉不变。
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 32,
        width: constraints.hasBoundedWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        alignment: Alignment.centerLeft,
        color: isDark
            ? AppColors.darkSurfaceGrouped
            : AppColors.lightSurfaceGrouped,
        child: Text(
          tag,
          style: context.textStyle(
            FontSizeType.footnote,
            fontWeight: FontWeight.w600,
            color: AppColors.iosGray,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactProvider);
    final brightness = Theme.of(context).brightness;
    final newFriendUnreadCount = ref.watch(newFriendRemindProvider).length;

    // 本地过滤已加载联系人（标题）；不触网。indexBarData 随过滤结果同步派生，
    // 避免索引栏出现"有字母但列表无对应项"的不一致。
    final all = state.contactList;
    final filtered = filteredContacts(all, _searchQuery);
    final barData = filteredIndexBar(
      filtered,
      state.indexBarData,
      _searchQuery,
    );

    return IosPageTemplate(
      title: t.common.titleContact,
      actions: [
        Semantics(
          label: t.contact.tags,
          button: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.tag, size: 22),
            onPressed: () => context.pushNamed('user_tag_list'),
          ),
        ),
        Semantics(
          label: t.common.addFriend,
          button: true,
          child: CupertinoButton(
            key: const Key('add_friend_button'),
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.person_add, size: 22),
            onPressed: () => context.push('/contact/add_friend'),
          ),
        ),
        AppSpacing.horizontalSmall,
      ],
      // AzListView 自带滚动 + IndexBar，塞进 CustomScrollView 的 SliverFillRemaining
      // 会同轴嵌套两层滚动体：hasScrollBody:true 时吸顶头挂到未完成布局的 relayout
      // 边界上抛 "Cannot hit test a render box with no size"；改 false 又给了子节点
      // 无界高度，AzListView 内部 Stack 布局失败 → sliver geometry 为 null 崩在
      // layoutChildSequence。这里改成搜索框固定 + AzListView 独占剩余高度，不再嵌套。
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.small,
            ),
            child: CupertinoSearchTextField(
              key: const Key('contact_search_input'),
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              placeholder: t.common.search,
            ),
          ),
          if (state.isLoading)
            const Expanded(child: ShimmerList())
          else if (all.isEmpty)
            Expanded(child: NoDataView(text: t.common.noContacts))
          else if (filtered.isEmpty)
            Expanded(child: NoDataView(text: t.common.searchNoResults))
          else
            Expanded(
              child: AzListView(
                data: filtered,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final model = filtered[index];
                  return Column(
                    children: [
                      _buildChatItem(
                        context,
                        model,
                        newFriendUnreadCount: newFriendUnreadCount,
                      ),
                      if (index < filtered.length - 1 &&
                          filtered[index].getSuspensionTag() ==
                              filtered[index + 1].getSuspensionTag())
                        Padding(
                          padding: const EdgeInsets.only(left: 72),
                          child: Divider(
                            height: 0.5,
                            color: AppColors.getIosSeparator(
                              brightness,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  );
                },
                susItemBuilder: (context, index) {
                  final tag = filtered[index].getSuspensionTag();
                  if (tag == '↑') return const SizedBox.shrink();
                  return _buildSusItem(context, tag);
                },
                indexBarData: barData,
                indexBarOptions: IndexBarOptions(
                  needRebuild: true,
                  indexHintDecoration: BoxDecoration(
                    color: AppColors.getIosBlue(
                      brightness,
                    ).withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  indexHintTextStyle: context.textStyle(
                    FontSizeType.largeTitle,
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  downItemDecoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  indexHintOffset: const Offset(-20, 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
