import 'dart:math' as math;

import 'package:azlistview/azlistview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lpinyin/lpinyin.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 选择好友页面（iOS 分组列表风格，对齐 contact_page 设计语言）
/// 使用 Riverpod 进行状态管理
class SelectFriendPage extends ConsumerStatefulWidget {
  final Map<String, String> peer;
  final bool peerIsReceiver;

  const SelectFriendPage({
    super.key,
    required this.peer,
    this.peerIsReceiver = false,
  });

  @override
  ConsumerState<SelectFriendPage> createState() => _SelectFriendPageState();
}

class _SelectFriendPageState extends ConsumerState<SelectFriendPage> {
  /// 行高 = 44 头像 + 上下 10 内边距，≥ 44pt 触控标准
  static const double _itemHeight = 64;

  /// 分隔线左缩进 = 16 页边距 + 44 头像 + 12 图文间距（DESIGN.md 8.3）
  static const double _dividerIndent = 72;

  List<ContactModel> _contactList = [];
  bool _loading = true;

  /// 搜索关键词（trim + 小写）；空串 = 未过滤
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() => _searchQuery = q);
  }

  @override
  void initState() {
    super.initState();
    // 延迟加载数据，确保 ref 已准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  /// 标题/拼音本地过滤。query 空返回原列表（同一批对象，保持排序与吸顶标记）。
  List<ContactModel> _filterList(String query) {
    if (query.isEmpty) return _contactList;
    return _contactList
        .where((m) {
          if (m.title.toLowerCase().contains(query)) return true;
          final pinyin = (m.namePinyin ?? '').toLowerCase();
          return pinyin.contains(query);
        })
        .toList(growable: false);
  }

  /// 由过滤结果派生索引栏标签：A-Z 升序、# 沉底、'↑'（回顶部）最前。
  /// 避免"索引栏有字母但列表无对应项"。
  List<String> _indexBarDataFor(List<ContactModel> list) {
    if (list.isEmpty) return [];
    final tags = <String>{};
    var hasUp = false;
    for (final m in list) {
      final tg = m.getSuspensionTag();
      if (tg == '↑') {
        hasUp = true;
      } else if (tg.isNotEmpty) {
        tags.add(tg);
      }
    }
    final letters = tags.where((t) => t != '#').toList()..sort();
    return [if (hasUp) '↑', ...letters, if (tags.contains('#')) '#'];
  }

  void loadData() async {
    // 加载联系人列表
    final contactList = await ContactRepo().findFriend();
    if (!mounted) return;

    setState(() {
      _contactList = contactList;
    });

    _handleList(_contactList);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.isEmpty ? '#' : pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
      } else {
        list[i].nameIndex = "#";
      }
    }

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(_contactList);
  }

  void sendToDialog(ContactModel model) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final peer = widget.peer;
    final peerIsReceiver = widget.peerIsReceiver;

    // 根据主题选择按钮文字颜色：暗色用 iOS 绿、亮色用 iOS 蓝（语义色）
    final brightness = Theme.of(context).brightness;
    final Color buttonTextColor = isDarkMode
        ? AppColors.getIosGreen(brightness)
        : AppColors.getIosBlue(brightness);

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.chat.sendTo),
        content: SizedBox(
          height: 164,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              peerIsReceiver
                  ? Row(
                      children: [
                        Avatar(imgUri: model.avatar),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              model.title,
                              style: context.textStyle(
                                FontSizeType.medium,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Avatar(imgUri: peer['avatar']!),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              peer['title']!,
                              style: context.textStyle(
                                FontSizeType.medium,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: CupertinoColors.separator.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Text(
                  // visitCard
                  peerIsReceiver
                      ? "[${t.common.personalCard}]${peer['nickname']}"
                      : "[${t.common.personalCard}]${model.nickname}",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              t.common.buttonCancel,
              textAlign: TextAlign.center,
              style: TextStyle(color: buttonTextColor),
            ),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              var nav = Navigator.of(context);
              nav.pop();
              nav.pop(model);
            },
            child: Text(
              t.common.buttonSend,
              textAlign: TextAlign.center,
              style: TextStyle(color: buttonTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    ContactModel model, {
    required bool showDivider,
  }) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Semantics(
          button: true,
          child: GestureDetector(
            // 不用 InkWell：DESIGN.md §13.2 禁止 Cupertino 列表行用 Ripple
            behavior: HitTestBehavior.opaque,
            onTap: () {
              sendToDialog(model);
            },
            child: Container(
              height: _itemHeight,
              // 行背景用 surface，与页面 grouped 背景形成 iOS 分组层次
              color: brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
              ),
              child: Row(
                children: [
                  Avatar(imgUri: model.avatar, width: 44, height: 44),
                  AppSpacing.horizontalMedium,
                  Expanded(
                    child: Text(
                      model.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context
                          .textStyle(
                            FontSizeType.body,
                            fontWeight: FontWeight.w500,
                          )
                          .copyWith(letterSpacing: -0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 仅同分组相邻项之间画分隔线；左缩进对齐文字（72 = 16+44+12）
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: _dividerIndent),
            child: Divider(
              height: 0.5,
              color: AppColors.getIosSeparator(brightness)
                  .withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  /// 构建吸顶分组头（A-Z），样式对齐 contact_page
  Widget _buildSusItem(BuildContext context, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // width 必须按约束决定，不能写死 double.infinity。
    // AzListView 把吸顶头同时用在两处：列表内联项（宽度有界）和悬浮头
    // （Stack 的 positioned child，某些布局路径下不给横向锚点 → 宽度无界）。
    // 无界时 double.infinity 会直接触发
    // "BoxConstraints forces an infinite width" 断言，整页布局崩掉。
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

  Widget _buildListView(List<ContactModel> visibleList) {
    final brightness = Theme.of(context).brightness;
    final barData = _indexBarDataFor(visibleList);

    // IndexBar 是固定高度的 Column（27 项 × itemHeight），列表区高度不足时
    // 右侧字母栏会 RenderFlex overflow；按可用高度压缩每项高度即可。
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemHeight = constraints.maxHeight.isFinite
            ? math.min(
                kIndexBarItemHeight,
                constraints.maxHeight / math.max(barData.length, 1),
              )
            : kIndexBarItemHeight;
        return AzListView(
          data: visibleList,
          itemCount: visibleList.length,
          indexBarItemHeight: itemHeight,
          itemBuilder: (context, i) {
            final showDivider =
                i < visibleList.length - 1 &&
                visibleList[i].getSuspensionTag() ==
                    visibleList[i + 1].getSuspensionTag();
            return _buildListItem(
              context,
              visibleList[i],
              showDivider: showDivider,
            );
          },
          // 解决联系人数据量少的情况下无法刷新的问题
          // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
          physics: const AlwaysScrollableScrollPhysics(),
          susItemBuilder: (BuildContext context, int index) {
            ContactModel model = visibleList[index];
            if ('↑' == model.getSuspensionTag()) {
              return const SizedBox.shrink();
            }
            return _buildSusItem(context, model.getSuspensionTag());
          },
          indexBarData: barData,
          indexBarOptions: IndexBarOptions(
            needRebuild: true,
            ignoreDragCancel: true,
            downTextStyle: context.textStyle(
              FontSizeType.small,
              color: AppColors.onPrimary,
            ),
            downItemDecoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            indexHintDecoration: BoxDecoration(
              color: AppColors.getIosBlue(brightness).withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            indexHintTextStyle: context.textStyle(
              FontSizeType.largeTitle,
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
            indexHintOffset: const Offset(-20, 0),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // 搜索过滤后重建吸顶标记，保证分组头只出现在"可见项"的组首
    final visibleList = _filterList(_searchQuery);
    SuspensionUtil.setShowSuspensionStatus(visibleList);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      appBar: GlassAppBar(
        title: t.contact.selectFriends,
        leading: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Icon(
            CupertinoIcons.xmark,
            color: Theme.of(context).colorScheme.onSurface,
            semanticLabel: t.common.buttonClose,
          ),
        ),
      ),
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
              key: const Key('select_friend_search_input'),
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              placeholder: t.common.search,
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerList(itemHeight: _itemHeight)
                : _contactList.isEmpty
                ? RefreshIndicator(
                    onRefresh: _onPullRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [NoDataView(text: t.common.noContacts)],
                    ),
                  )
                : visibleList.isEmpty
                ? NoDataView(text: t.common.searchNoResults)
                : RefreshIndicator(
                    onRefresh: _onPullRefresh,
                    child: _buildListView(visibleList),
                  ),
          ),
        ],
      ),
    );
  }

  /// 下拉刷新：仅离线时提示，成功后重建列表与索引
  Future<void> _onPullRefresh() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      String msg = t.common.tipConnectDesc;
      AppLoading.showInfo(' $msg');
      return;
    }
    List<ContactModel> contact = await ContactRepo().findFriend();
    if (contact.isNotEmpty && mounted) {
      setState(() {
        _contactList = contact;
      });
      _handleList(_contactList);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
