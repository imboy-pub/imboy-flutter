import 'package:azlistview/azlistview.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:lpinyin/lpinyin.dart';

import 'contact_tag_detail_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 选择好友页面（联系人标签使用）
class SelectFriendPage extends ConsumerStatefulWidget {
  final UserTagModel tag;
  final List<ContactModel> tagContactList;

  const SelectFriendPage({
    super.key,
    required this.tag,
    required this.tagContactList,
  });

  /// 行选中判定：以本次会话选中集合为权威。
  ///
  /// selectedContact 初始化自标签成员（_loadData L51），onTap 勾选 insert /
  /// 取消 removeWhere，始终是当前会话完整选中态。BUG#132：此前仅按进页
  /// tagContactList 判定，勾选/取消后 setState 重建把 model.selected 重置回
  /// 进页态，行图标与 Semantics.selected 永不随交互更新（真机像素实证：
  /// 勾选 automation-buddy 后行图标仍灰色空心圆圈）。
  @visibleForTesting
  static bool isRowSelected(
    ContactModel model,
    List<ContactModel> selectedContact,
  ) => selectedContact.any((e) => e.peerId == model.peerId);

  @override
  ConsumerState<SelectFriendPage> createState() => _SelectFriendPageState();
}

class _SelectFriendPageState extends ConsumerState<SelectFriendPage> {
  final int _itemHeight = 60;
  List<ContactModel> contactList = [];
  List<ContactModel> selectedContact = [];
  Set<String> currIndexBarData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    selectedContact = List<ContactModel>.from(widget.tagContactList);
    // 使用 ContactRepo 直接获取好友列表
    contactList = await ContactRepo().findFriend();
    _handleList(contactList);
    setState(() {});
  }

  void _handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.isEmpty ? '#' : pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = "#";
      }
    }
    currIndexBarData.add('#');
    SuspensionUtil.sortListBySuspensionTag(contactList);
    SuspensionUtil.setShowSuspensionStatus(contactList);
  }

  Widget _buildListItem(ContactModel model) {
    model.selected = SelectFriendPage.isRowSelected(model, selectedContact);

    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          // 多选页必须声明 selected：读屏用户听到名字但不知道自己选没选。
          // 名字由 Text 自带语义提供，不重复设 label。
          child: Semantics(
            button: true,
            selected: model.selected,
            child: GestureDetector(
              // 不用 InkWell：DESIGN.md §13.2 禁止 Cupertino 列表行用 Ripple
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  model.selected = !model.selected;
                  if (model.selected) {
                    selectedContact.insert(0, model);
                  } else {
                    selectedContact.removeWhere(
                      (e) => e.peerId == model.peerId,
                    );
                  }
                });
              },
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      model.selected
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.check_mark_circled,
                      color: model.selected
                          ? AppColors.iosGreen
                          : AppColors.iosGray,
                    ),
                  ),
                  Avatar(imgUri: model.avatar, width: 49, height: 49),
                  const Space(),
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(right: 30),
                      height: _itemHeight.toDouble(),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(width: 0.2)),
                      ),
                      child: Text(
                        model.title,
                        style: context.textStyle(FontSizeType.normal),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建悬浮标签项（A-Z 分组标题）
  Widget _buildSusItem(BuildContext context, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // width 必须按约束决定，不能写死 double.infinity——AzListView 把吸顶头
    // 同时用作内联项（宽度有界）和悬浮头（Stack positioned child，某些布局
    // 路径下宽度无界），后者会触发 "BoxConstraints forces an infinite width"
    // 把整页布局打崩。contact_page 已经栽过同一个坑（commit 894ab390）。
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 32,
        width: constraints.hasBoundedWidth ? double.infinity : null,
        padding: const EdgeInsets.only(left: AppSpacing.regular),
        alignment: Alignment.centerLeft,
        color: isDark ? AppColors.iosGray6 : AppColors.iosGray5,
        child: Text(
          tag,
          style: context.textStyle(
            FontSizeType.normal,
            color: AppColors.getTextColor(
              isDark ? Brightness.dark : Brightness.light,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        rightDMActions: <Widget>[
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () async {
              Navigator.of(context).pop();
              const String scene = 'friend';
              bool res = await ref
                  .read(contactTagDetailProvider.notifier)
                  .setObject(
                    scene: scene,
                    tagId: widget.tag.tagId,
                    tagName: widget.tag.name,
                    selectedContact: selectedContact,
                    tagContactList: widget.tagContactList,
                  );
              if (res) {
                UserTagModel updatedTag = UserTagModel(
                  userId: widget.tag.userId,
                  tagId: widget.tag.tagId,
                  scene: widget.tag.scene,
                  name: widget.tag.name,
                  subtitle: widget.tag.subtitle,
                  refererTime: selectedContact.length,
                  updatedAt: widget.tag.updatedAt,
                  createdAt: widget.tag.createdAt,
                );
                ref.read(contactTagListProvider.notifier).updateTag(updatedTag);
                AppLoading.showSuccess(t.common.tipSuccess);
              } else {
                AppLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(
              t.common.buttonAdd +
                  (selectedContact.isEmpty
                      ? ""
                      : " (${selectedContact.length})"),
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: selectedContact.isNotEmpty
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: selectedContact.isNotEmpty
                    ? AppColors.getIosBlue(Theme.of(context).brightness)
                    : AppColors.iosGray,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // 使用 ContactRepo 直接获取好友列表
              List<ContactModel> contact = await ContactRepo().findFriend();
              if (contact.isNotEmpty) {
                contactList = contact;
                _handleList(contactList);
                setState(() {});
              }
            },
            child: AzListView(
              data: contactList,
              itemCount: contactList.length,
              itemBuilder: (context, i) => _buildListItem(contactList[i]),
              physics: const AlwaysScrollableScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }
                return _buildSusItem(context, model.getSuspensionTag());
              },
              indexBarData: contactList.isNotEmpty
                  ? ['↑', ...currIndexBarData]
                  : [],
              indexBarOptions: IndexBarOptions(
                needRebuild: true,
                ignoreDragCancel: true,
                downTextStyle: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.onPrimary,
                ),
                downItemDecoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.iosGreen,
                ),
                indexHintWidth: 128 / 2,
                indexHintHeight: 128 / 2,
                indexHintDecoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      AssetsService.getImgPath('index_bar_bubble_gray'),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintChildAlignment: const Alignment(-0.25, 0.0),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
