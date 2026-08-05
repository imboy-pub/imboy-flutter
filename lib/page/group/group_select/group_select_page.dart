import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/group/group_select/group_select_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

class GroupSelectPage extends ConsumerStatefulWidget {
  const GroupSelectPage({super.key});

  @override
  ConsumerState<GroupSelectPage> createState() => _GroupSelectPageState();
}

class _GroupSelectPageState extends ConsumerState<GroupSelectPage> {
  @override
  void initState() {
    super.initState();
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  /// 加载数据
  Future<void> loadData() async {
    final notifier = ref.read(groupSelectProvider.notifier);
    await notifier.loadData();
  }

  /// 计算群组头像
  Future<List<String>> computeAvatar(String gid) async {
    final service = ref.read(groupSelectServiceProvider);
    return await service.computeAvatar(gid);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(groupSelectProvider);

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        title: t.group.selectGroup,
        automaticallyImplyLeading: true,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
          ? NoDataView(text: t.common.noData)
          : ListView.builder(
              shrinkWrap: true,
              itemCount: state.items.length,
              itemBuilder: (BuildContext context, int index) {
                ConversationModel model = state.items[index];
                return Column(
                  children: [
                    ImBoyListTile(
                      leading: SmartGroupAvatar(
                        avatar: model.avatar,
                        groupId: model.peerId.toString(),
                        avatarLoader: computeAvatar,
                        size: 48,
                      ),
                      // 用 displayTitle（缺名兜「未命名」），不要自己写
                      // title/computeTitle 三元表达式 —— 那是 ConversationModel
                      // 文档里明令禁止的写法，且两者同时为空时会渲染出一个
                      // 只有头像和箭头的**空白条目**，用户完全不知道是哪个群。
                      title: Text(model.displayTitle),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.iosGray3,
                      ),
                      onTap: () {
                        context.push(
                          '/chat/${model.peerId}',
                          extra: {
                            'peerId': model.peerId,
                            // 传下游用 resolvedTitle（刻意不兜底）：聊天页拿到
                            // 空串才会继续查群详情/成员名，传「未命名」会堵死
                            // 那条查找链（见 ConversationModel.resolvedTitle）。
                            'peerTitle': model.resolvedTitle,
                            'peerAvatar': model.avatar,
                            'peerSign': '',
                            'type': 'C2G',
                            'options': const {'popTime': 2, 'memberCount': 0},
                          },
                        );
                      },
                    ),
                    if (index < state.items.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 76),
                        child: Divider(
                          height: 0.33,
                          color: AppColors.getIosSeparator(
                            Theme.of(context).brightness,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                );
              },
              physics: const AlwaysScrollableScrollPhysics(),
            ),
    );
  }
}
