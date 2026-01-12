import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

import 'group_list_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

class GroupListPage extends StatelessWidget {
  GroupListPage({super.key});

  final logic = Get.put(GroupListLogic());
  final state = Get.find<GroupListLogic>().state;

  /// Load group data
  void initData() async {
    if (state.page == 1) {
      List<GroupModel> list = await logic.page(
        page: state.page,
        size: state.size,
      );
      List<GroupModel> list2 = [];
      for (GroupModel m in list) {
        if (strEmpty(m.title)) {
          m.computeTitle = await logic.computeTitle(m.groupId);
        }
        list2.add(m);
      }
      state.groupList.value = list2;
      state.page += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    initData();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        titleWidget: Obx(() => Text(
          "${t.groupChat}(${state.groupList.length})",
        )),
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // 搜索框区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: searchBar(
                context,
                searchLabel: t.search,
                hintText: t.search,
                queryTips: t.groupSearchTips,
                doSearch: ((query) => GroupRepo().search(kwd: query)),
                onTapForItem: (model) {
                  if (model is GroupModel) {
                    Get.to(
                      () => ChatPage(
                        peerId: model.groupId,
                        peerTitle: model.title,
                        peerAvatar: model.avatar,
                        peerSign: '',
                        type: 'C2G',
                        options: {'memberCount': model.memberCount},
                      ),
                      transition: Transition.rightToLeft,
                      popGesture: true,
                    );
                  }
                },
              ),
            ),
          ),
          
          // 群组列表
          Expanded(
            child: SlidableAutoCloseBehavior(
              child: Obx(() {
                if (state.groupList.isEmpty) {
                  return NoDataView(text: t.noData);
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: state.groupList.length,
                  itemBuilder: (BuildContext context, int index) {
                    GroupModel model = state.groupList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? colorScheme.shadow.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: SmartGroupAvatar(
                          avatar: model.avatar,
                          groupId: model.groupId,
                          avatarLoader: logic.computeAvatar,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          strEmpty(model.title)
                              ? model.computeTitle
                              : model.title,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          Get.to(
                            () => ChatPage(
                              peerId: model.groupId,
                              peerTitle: model.title,
                              peerAvatar: model.avatar,
                              peerSign: '',
                              type: 'C2G',
                              options: {'memberCount': model.memberCount},
                            ),
                            transition: Transition.rightToLeft,
                            popGesture: true,
                          );
                        },
                      ),
                    );
                  },
                  physics: const AlwaysScrollableScrollPhysics(),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}