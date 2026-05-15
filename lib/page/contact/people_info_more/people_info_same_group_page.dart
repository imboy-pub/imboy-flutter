import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 共同群组列表页面
class PeopleInfoSameGroupPage extends ConsumerStatefulWidget {
  final List<GroupModel> groupList;

  const PeopleInfoSameGroupPage({super.key, required this.groupList});

  @override
  ConsumerState<PeopleInfoSameGroupPage> createState() =>
      _PeopleInfoSameGroupPageState();
}

class _PeopleInfoSameGroupPageState
    extends ConsumerState<PeopleInfoSameGroupPage> {
  final GroupListService _groupListService = GroupListService();
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  /// 跳转到群组聊天页面
  void _navigateToChat(GroupModel model) {
    final router = GoRouter.of(context);
    router.push(
      '/chat/${model.groupId}',
      extra: {
        'type': 'C2G',
        'title': model.title,
        'avatar': model.avatar,
        'options': {'memberCount': model.memberCount},
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.group.mutualGroupsWithHer,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SlidableAutoCloseBehavior(
                  child: widget.groupList.isEmpty
                      ? NoDataView(text: t.common.noData)
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.groupList.length,
                          itemBuilder: (BuildContext context, int index) {
                            GroupModel model = widget.groupList[index];
                            return Column(
                              children: [
                                ListTile(
                                  leading: SmartGroupAvatar(
                                    avatar: model.avatar,
                                    groupId: model.groupId.toString(),
                                    avatarLoader: (groupId) async {
                                      final avatarUrl = await _groupListService
                                          .computeAvatar(groupId);
                                      return avatarUrl.isNotEmpty
                                          ? avatarUrl
                                          : [];
                                    },
                                  ),
                                  contentPadding: const EdgeInsets.only(
                                    left: 10,
                                    right: 10,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          strEmpty(model.title)
                                              ? model.computeTitle
                                              : model.title,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _navigateToChat(model),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 20,
                                    bottom: 10,
                                  ),
                                  child: HorizontalLine(
                                    height: isDark ? 0.5 : 1.0,
                                  ),
                                ),
                              ],
                            );
                          },
                          // 解决联系人数据量少的情况下无法刷新的问题
                          // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                          physics: const AlwaysScrollableScrollPhysics(),
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(t.main.numUnit(param: '${widget.groupList.length}')),
          ),
        ],
      ),
    );
  }
}
