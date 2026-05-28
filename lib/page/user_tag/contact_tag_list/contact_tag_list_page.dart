import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_page.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_page.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'contact_tag_list_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 联系人标签列表页面 - 像素级对齐 iOS 17 Premium 风格
class ContactTagListPage extends ConsumerStatefulWidget {
  const ContactTagListPage({super.key});

  @override
  ConsumerState<ContactTagListPage> createState() => _ContactTagListPageState();
}

class _ContactTagListPageState extends ConsumerState<ContactTagListPage> {
  final ScrollController _controller = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactTagListProvider.notifier).loadData();
      _initScrollListener();
    });
  }

  void _initScrollListener() {
    _controller.addListener(() async {
      if (_controller.position.pixels == _controller.position.maxScrollExtent) {
        await ref.read(contactTagListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(contactTagListProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.contactTags,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add, size: 22),
          onPressed: () => _showAddTagSheet(context),
        ),
      ],
      slivers: [
        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: t.common.search,
              onChanged: (v) =>
                  ref.read(contactTagListProvider.notifier).doSearch(v),
            ),
          ),
        ),

        // 标签列表
        if (listState.items.isEmpty)
          SliverFillRemaining(child: NoDataView(text: t.common.noData))
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverReorderableList(
              itemCount: listState.items.length,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(contactTagListProvider.notifier)
                  .reorderItems(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final obj = listState.items[index];
                return _buildTagItem(context, index, obj, brightness);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTagItem(
    BuildContext context,
    int index,
    UserTagModel obj,
    Brightness brightness,
  ) {
    return Slidable(
      key: ValueKey(obj.tagId),
      endActionPane: ActionPane(
        extentRatio: 0.45,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showRenameSheet(context, obj),
            backgroundColor: AppColors.iosGray,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.pencil,
            label: t.main.name,
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, obj),
            backgroundColor: AppColors.getIosRed(brightness),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete_solid,
            label: t.common.buttonDelete,
          ),
        ],
      ),
      child: Column(
        children: [
          ImBoyListTile(
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute<dynamic>(
                builder: (context) => ContactTagDetailPage(tag: obj),
              ),
            ),
            title: Text('${obj.name} (${obj.refererTime})'),
            subtitle: Text(
              obj.subtitle.isEmpty ? t.common.noData : obj.subtitle,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.iosGray3,
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    CupertinoIcons.bars,
                    size: 18,
                    color: AppColors.iosGray3,
                  ),
                ),
              ],
            ),
          ),
          if (index < ref.read(contactTagListProvider).items.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Divider(
                height: 0.33,
                color: AppColors.getIosSeparator(
                  brightness,
                ).withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddTagSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserTagSavePage(scene: 'friend'),
    );
  }

  void _showRenameSheet(BuildContext context, UserTagModel obj) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserTagSavePage(tag: obj, scene: 'friend'),
    );
  }

  void _confirmDelete(BuildContext context, UserTagModel obj) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.confirmDelete),
        content: Text(t.common.deleteTagTips),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              if (await ref
                  .read(contactTagListProvider.notifier)
                  .deleteTag(
                    tagId: obj.tagId,
                    tagName: obj.name,
                    scene: 'friend',
                  )) {
                EasyLoading.showSuccess(t.common.tipSuccess);
              } else {
                EasyLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }
}
