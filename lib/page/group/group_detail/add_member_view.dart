import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/app_text_size.dart' show AppTextSize;
import 'package:imboy/page/group/launch_chat/launch_chat_logic.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_state.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';


import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/i18n/strings.g.dart';

class AddMemberPage extends StatefulWidget {
  final String groupId;

  const AddMemberPage({super.key, required this.groupId});

  @override
  AddMemberPageState createState() => AddMemberPageState();
}

class AddMemberPageState extends State<AddMemberPage> {
  final LaunchChatLogic logic = Get.put(LaunchChatLogic());
  final LaunchChatState state = Get.find<LaunchChatLogic>().state;

  RxList memberUserIds = [].obs;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    List<GroupMemberModel> list = await (GroupMemberRepo()).page(
        limit: 2000,
        where: "${GroupMemberRepo.groupId} = ?",
        whereArgs: [widget.groupId]);
    memberUserIds = [].obs;
    for (GroupMemberModel obj in list) {
      memberUserIds.add(obj.userId);
    }
    logic.listFriend();
  }

  Widget _buildListItem(BuildContext context, ContactModel model) {
    bool isMember = memberUserIds.contains(model.peerId);
    bool isSelected = model.selected.isTrue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMember
              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
              : isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Obx(() => InkWell(
        onTap: isMember ? null : () {
          debugPrint(" item_onTap ${model.selected}");
          model.selected.value = !model.selected.value;
          if (model.selected.isTrue) {
            state.selects.insert(0, model);
          } else {
            state.selects.remove(model);
          }
          if (state.selects.value.isNotEmpty) {
            state.selectsTips.value = '(${state.selects.value.length})';
          } else {
            state.selectsTips.value = '';
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 选择图标
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMember
                      ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
                      : isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
                child: Icon(
                  isMember
                      ? CupertinoIcons.check_mark_circled_solid
                      : isSelected
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.check_mark_circled,
                  size: 16,
                  color: isMember
                      ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.6)
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // 头像
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMember
                        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                        : isSelected
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Avatar(
                  imgUri: model.avatar,
                  width: 44,
                  height: 44,
                ),
              ),
              const SizedBox(width: 12),
              // 姓名和状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      model.title,
                      style: TextStyle(
                        fontSize: AppTextSize.subTitle,
                        color: isMember
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isMember) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.alreadyMember,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 选中状态指示器
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t.selected,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: t.selectContacts,
        rightDMActions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: logic.state.selects.isNotEmpty ? () async {
                    var nav = Navigator.of(context);
                    EasyLoading.show(status: t.loading);
                    int memberCount = logic.state.selects.length;
                    iPrint("logic.state.selects $memberCount ${logic.state.selects.toJson()}");
                    bool res = await logic.joinGroup(
                      widget.groupId,
                      logic.state.selects.value,
                    );
                    EasyLoading.dismiss();
                    if (res) {
                      logic.resetData();
                      nav.pop();
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: logic.state.selects.isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    foregroundColor: logic.state.selects.isNotEmpty
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.outline,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: logic.state.selects.isNotEmpty ? 2 : 0,
                  ),
                  child: Text(
                    '${t.buttonAccomplish}${logic.state.selectsTips.value}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏区域
          /* TODO leeyi 2024-04-12 00:05:34
          Container(
            margin: const EdgeInsets.all(16),
            child: searchBar(
              context,
              searchLabel: t.search,
              hintText: t.search,
              queryTips: '',
              doSearch: ((query) async {
                debugPrint("launch_chat_view doSearch ${query.toString()}");
                List<ContactModel> li = await ContactRepo().search(kwd: query);
                return li;
              }),
              onTapForItem: (value) {
                debugPrint("launch_chat_view value ${value is ContactModel}, ${value.toString()}");
                if (value is ContactModel) {
                  // Get.to for navigation
                }
              },
            ),
          ),
          */

          // 选择提示区域
          Obx(() => logic.state.selects.isNotEmpty
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.selectedCount.replaceAll('{count}', '${logic.state.selects.length}'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          // 联系人列表区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: SlidableAutoCloseBehavior(
                child: Obx(() {
                  return logic.state.items.isEmpty
                      ? NoDataView(text: t.noData)
                      : AzListView(
                          data: logic.state.items,
                          itemCount: logic.state.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            ContactModel model = logic.state.items[index];
                            return _buildListItem(context, model);
                          },
                          // 解决联系人数据量少的情况下无法刷新的问题
                          physics: const AlwaysScrollableScrollPhysics(),
                          susItemBuilder: (BuildContext context, int index) {
                            ContactModel model = logic.state.items[index];
                            if ('↑' == model.getSuspensionTag()) {
                              return Container();
                            }
                            return Get.find<ContactLogic>().getSusItem(
                              context,
                              model.getSuspensionTag(),
                            );
                          },
                          indexBarData: logic.state.items.isNotEmpty
                              ? ['↑', ...logic.state.currIndexBarData]
                              : [],
                          indexBarOptions: IndexBarOptions(
                            needRebuild: true,
                            ignoreDragCancel: true,
                            downTextStyle: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            downItemDecoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            indexHintWidth: 64,
                            indexHintHeight: 64,
                            indexHintDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            indexHintAlignment: Alignment.centerRight,
                            indexHintChildAlignment: const Alignment(-0.25, 0.0),
                            indexHintOffset: const Offset(-20, 0),
                          ),
                        );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
