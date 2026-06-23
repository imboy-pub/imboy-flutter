import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/contact/contact/contact_menu_decoration.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_page.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'contact_tag_detail_provider.dart';
import 'select_tag_friend_page.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 联系人标签详情页面
class ContactTagDetailPage extends ConsumerStatefulWidget {
  final UserTagModel tag;

  const ContactTagDetailPage({super.key, required this.tag});

  @override
  ConsumerState<ContactTagDetailPage> createState() =>
      _ContactTagDetailPageState();
}

class _ContactTagDetailPageState extends ConsumerState<ContactTagDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  String _kwd = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(contactTagDetailProvider.notifier)
          .loadTagData(
            tagName: widget.tag.name,
            refererTime: widget.tag.refererTime,
            tagId: widget.tag.tagId,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 构建聊天列表项
  Widget _buildChatListItem(
    BuildContext context,
    ContactModel model, {
    Color? defHeaderBgColor,
  }) {
    final menuDecoration = model.isMenuEntry
        ? contactMenuDecorationOf(model.peerId)
        : null;
    return InkWell(
      onTap: model.onPressed,
      onLongPress: model.onLongPressed,
      child: Container(
        color: menuDecoration?.bgColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        child: Row(
          children: [
            // 头像或图标
            if (model.isMenuEntry)
              SizedBox(width: 49, height: 49, child: menuDecoration?.iconData)
            else
              Avatar(imgUri: model.avatar, width: 49, height: 49),
            const Space(),
            // 名称和签名
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.title,
                    style: context.textStyle(FontSizeType.medium),
                  ),
                  if (model.sign.isNotEmpty)
                    Text(
                      model.sign,
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.iosGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建悬浮标签项（A-Z 分组标题）
  Widget _buildSusItem(BuildContext context, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 32,
      width: double.infinity,
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
    );
  }

  /// 添加联系人
  Future<void> addContact(BuildContext ctx) async {
    final detailState = ref.watch(contactTagDetailProvider);
    await Navigator.push(
      ctx,
      CupertinoPageRoute<dynamic>(
        builder: (_) => SelectFriendPage(
          tag: widget.tag,
          tagContactList: detailState.contactList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(contactTagDetailProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Text(
          '${detailState.tagName} (${detailState.refererTime})',
        ),
        rightDMActions: [
          InkWell(
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: isDark
                    ? AppColors.darkSurfaceGroupedTertiary
                    : AppColors.lightSurfaceGrouped,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.large),
                    topRight: Radius.circular(AppRadius.large),
                  ),
                ),
                builder: (context) => SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 172,
                  child: Column(
                    children: [
                      Center(
                        child: TextButton(
                          child: Text(
                            t.main.changeParam(param: t.contact.tags),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            showModalBottomSheet<void>(
                              context: context,
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceGroupedTertiary
                                  : AppColors.lightSurfaceGrouped,
                              builder: (context) => UserTagSavePage(
                                tag: widget.tag,
                                scene: 'friend',
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            // 显示删除确认
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                contentPadding: const EdgeInsets.fromLTRB(
                                  AppSpacing.large,
                                  AppSpacing.large,
                                  AppSpacing.large,
                                  0,
                                ),
                                content: Text(t.common.deleteTagTips),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(t.common.buttonCancel),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      const String scene = 'friend';
                                      bool res = await ref
                                          .read(contactTagListProvider.notifier)
                                          .deleteTag(
                                            tagId: widget.tag.tagId,
                                            tagName: widget.tag.name,
                                            scene: scene,
                                          );
                                      if (res) {
                                        await ref
                                            .read(
                                              contactTagListProvider.notifier,
                                            )
                                            .replaceObjectTag(
                                              scene: scene,
                                              oldName: widget.tag.name,
                                              newName: '',
                                            );
                                        if (context.mounted) {
                                          Navigator.pop(context, true);
                                        }
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                        EasyLoading.showSuccess(
                                          t.common.tipSuccess,
                                        );
                                      } else {
                                        if (context.mounted) {
                                          Navigator.pop(context, false);
                                        }
                                        EasyLoading.showError(
                                          t.common.tipFailed,
                                        );
                                      }
                                    },
                                    child: Text(t.common.buttonConfirm),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            t.common.buttonDelete,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.iosRed,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const HorizontalLine(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            t.common.buttonCancel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.small,
                  2,
                  AppSpacing.small,
                  2,
                ),
                child: searchBar(
                  context,
                  leading: InkWell(
                    onTap: () {
                      ref
                          .read(contactTagDetailProvider.notifier)
                          .doSearch(
                            onRefresh: false,
                            query: _kwd,
                            tagId: widget.tag.tagId,
                          );
                    },
                    child: const Icon(Icons.search),
                  ),
                  trailing: _kwd.isEmpty
                      ? [
                          InkWell(
                            onTap: () {
                              addContact(context);
                            },
                            child: const Icon(Icons.add_box_outlined),
                          ),
                        ]
                      : [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _kwd = '';
                                _searchController.text = '';
                              });
                              ref
                                  .read(contactTagDetailProvider.notifier)
                                  .doSearch(
                                    onRefresh: false,
                                    query: _kwd,
                                    tagId: widget.tag.tagId,
                                  );
                            },
                            child: const Icon(Icons.close),
                          ),
                        ],
                  controller: _searchController,
                  searchLabel: t.common.search,
                  hintText: t.common.search,
                  onChanged: (query) {
                    setState(() {
                      _kwd = query;
                    });
                    ref
                        .read(contactTagDetailProvider.notifier)
                        .doSearch(
                          onRefresh: false,
                          query: _kwd,
                          tagId: widget.tag.tagId,
                        );
                  },
                  doSearch: (query) {
                    return ref
                        .read(contactTagDetailProvider.notifier)
                        .doSearch(
                          onRefresh: false,
                          query: _kwd,
                          tagId: widget.tag.tagId,
                        );
                  },
                ),
              ),
              detailState.contactList.isEmpty
                  ? const SizedBox.shrink()
                  : Expanded(
                      child: AzListView(
                        data: detailState.contactList,
                        itemCount: detailState.contactList.length,
                        itemBuilder: (BuildContext context, int index) {
                          ContactModel model = detailState.contactList[index];
                          return Slidable(
                            key: ValueKey(model.peerId),
                            groupTag: '0',
                            closeOnScroll: true,
                            endActionPane: ActionPane(
                              extentRatio: 0.25,
                              motion: const StretchMotion(),
                              children: [
                                SlidableAction(
                                  key: ValueKey("delete_$index"),
                                  flex: 1,
                                  backgroundColor: AppColors.iosRed,
                                  onPressed: (_) async {
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (context) => SizedBox(
                                        width: MediaQuery.of(
                                          context,
                                        ).size.width,
                                        height: 102,
                                        child: Column(
                                          children: [
                                            Center(
                                              child: TextButton(
                                                onPressed: () async {
                                                  const String scene = 'friend';
                                                  bool res = await ref
                                                      .read(
                                                        contactTagDetailProvider
                                                            .notifier,
                                                      )
                                                      .removeRelation(
                                                        tagId: widget.tag.tagId,
                                                        tagName:
                                                            widget.tag.name,
                                                        objectId: model.peerId
                                                            .toString(),
                                                        scene: scene,
                                                      );
                                                  if (res) {
                                                    await ref
                                                        .read(
                                                          contactTagListProvider
                                                              .notifier,
                                                        )
                                                        .replaceTagSubtitle(
                                                          tag: widget.tag,
                                                          oldName: model.title,
                                                          newName: '',
                                                        );

                                                    final newContactList =
                                                        List<ContactModel>.from(
                                                          detailState
                                                              .contactList,
                                                        );
                                                    final index1 =
                                                        newContactList
                                                            .indexWhere(
                                                              (e) =>
                                                                  e.peerId ==
                                                                  model.peerId,
                                                            );
                                                    if (index1 > -1) {
                                                      newContactList.removeAt(
                                                        index1,
                                                      );
                                                    }
                                                    ref
                                                        .read(
                                                          contactTagDetailProvider
                                                              .notifier,
                                                        )
                                                        .handleList(
                                                          newContactList,
                                                        );

                                                    // DONE(2026-04-04): 更新 refererTime
                                                    ref
                                                        .read(
                                                          contactTagDetailProvider
                                                              .notifier,
                                                        )
                                                        .decrementRefererTime();
                                                    final currentRefererTime = ref
                                                        .read(
                                                          contactTagDetailProvider,
                                                        )
                                                        .refererTime;

                                                    // 更新标签列表中的标签
                                                    UserTagModel
                                                    updatedTag = UserTagModel(
                                                      userId: widget.tag.userId,
                                                      tagId: widget.tag.tagId,
                                                      scene: widget.tag.scene,
                                                      name: widget.tag.name,
                                                      subtitle:
                                                          '${widget.tag.subtitle.replaceFirst('${model.title},', '')},',
                                                      refererTime:
                                                          currentRefererTime,
                                                      updatedAt:
                                                          widget.tag.updatedAt,
                                                      createdAt:
                                                          widget.tag.createdAt,
                                                    );
                                                    ref
                                                        .read(
                                                          contactTagListProvider
                                                              .notifier,
                                                        )
                                                        .updateTag(updatedTag);

                                                    if (context.mounted) {
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      );
                                                    }
                                                    EasyLoading.showSuccess(
                                                      t.common.tipSuccess,
                                                    );
                                                  } else {
                                                    if (context.mounted) {
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      );
                                                    }
                                                    EasyLoading.showError(
                                                      t.common.tipFailed,
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  t.common.removeContactFromTag,
                                                  textAlign: TextAlign.center,
                                                  style: context.textStyle(
                                                    FontSizeType.medium,
                                                    color: AppColors.iosRed,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const HorizontalLine(height: 6),
                                            Center(
                                              child: TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  t.common.buttonCancel,
                                                  textAlign: TextAlign.center,
                                                  style: context.textStyle(
                                                    FontSizeType.medium,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  label: t.common.buttonDelete,
                                  spacing: 1,
                                ),
                              ],
                            ),
                            child: _buildChatListItem(
                              context,
                              model,
                              defHeaderBgColor: AppColors.lightBorder,
                            ),
                          );
                        },
                        physics: const AlwaysScrollableScrollPhysics(),
                        susItemBuilder: (BuildContext context, int index) {
                          ContactModel model = detailState.contactList[index];
                          if ('↑' == model.getSuspensionTag()) {
                            return Container();
                          }
                          return _buildSusItem(
                            context,
                            model.getSuspensionTag(),
                          );
                        },
                        indexBarData: detailState.contactList.isNotEmpty
                            ? ['↑', ...detailState.currIndexBarData]
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
                                AssetsService.getImgPath(
                                  'index_bar_bubble_gray',
                                ),
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
          if (detailState.contactList.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.tag.refererTime == 0)
                    NoDataView(text: t.common.noMembersInCurrentTag),
                  ElevatedButton(
                    onPressed: () async {
                      addContact(context);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        Theme.of(context).colorScheme.surface,
                      ),
                      minimumSize: WidgetStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        t.common.buttonAdd,
                        style: context.textStyle(
                          FontSizeType.medium,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
